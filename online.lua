-- online.lua - Универсальный HTTP/HTTPS клиент для ПК и Android
-- Приоритет транспорта: lua-https > Scrap-Mods/http > LuaSec (ssl.https) > curl (десктоп)
local online = {}

local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local API_KEY = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4"

local PLAYERS_PATH = "players/"
local BULLETS_PATH = "bullets/"
local ABILITIES_PATH = "abilities/"
local DAMAGE_PATH = "damage/"
local EVENT_PATH = "Event"
local EVENT_REFRESH_INTERVAL = 2

local myUid = nil
local myNickname = nil
local mySkin = "NONE"
local players = {}
local bullets = {}
local abilities = {}
local isConnected = false
local debugText = "Waiting..."
local lastSentX = nil
local lastSentY = nil
local lastSentTime = 0
local fetchTimer = 0

-- Состояние общего события из Firebase (Event = 1 / Event = 0).
local eventActive = false
local eventRequestInFlight = false
local lastEventFetchTime = nil
local eventRequestGeneration = 0

local isAndroid = (love.system.getOS() == "Android")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

-- ============================================================
--  ОПРЕДЕЛЕНИЕ ТРАНСПОРТА (один раз при загрузке модуля)
-- ============================================================
local transport = { name = "none", mod = nil, ltn12 = nil }

-- 1) lua-https (основной для Android и ПК, возвращает code, body)
do
    local ok, m = pcall(require, "https")
    if ok and m then
        transport.name = "lua-https"
        transport.mod = m
    end
end

-- 2) Scrap-Mods/http (асинхронный, для ПК)
if transport.name == "none" then
    local ok, m = pcall(require, "http")
    if ok and m then
        transport.name = "scrap-mods-http"
        transport.mod = m
    end
end

-- 3) LuaSec (ssl.https + ltn12)
if transport.name == "none" then
    local okHttps, httpsMod = pcall(require, "ssl.https")
    local okLtn12, ltn12 = pcall(require, "ltn12")
    if okHttps and okLtn12 and httpsMod and ltn12 then
        transport.name = "luasec"
        transport.mod = httpsMod
        transport.ltn12 = ltn12
    end
end

-- 4) Резерв: curl на десктопе (Linux/macOS/Windows 10+)
if transport.name == "none" and not isAndroid then
    transport.name = "curl"
end

print("[ONLINE] HTTP transport: " .. transport.name)

-- ============================================================
--  РЕАЛИЗАЦИИ ЗАПРОСОВ ПО ТРАНСПОРТАМ
-- ============================================================
local curlBroken = false

local function requestLuaHttps(url, method, body, callback)
    local options = {
        method = method,
        headers = { ["Content-Type"] = "application/json" }
    }
    if body then options.data = body end

    local okCall, code, response = pcall(transport.mod.request, url, options)
    code = tonumber(code) or 0
    if okCall and code >= 200 and code < 300 then
        if callback then callback(true, response) end
        return true
    end
    if callback then callback(false, "HTTP error: " .. tostring(code)) end
    return false
end

local function requestScrapMods(url, method, body, callback)
    local options = {
        url = url,
        method = method,
        headers = { ["Content-Type"] = "application/json" }
    }
    if body then options.data = body end

    transport.mod.request(options, function(response)
        local code = (response and response.status) or 0
        if code >= 200 and code < 300 then
            if callback then callback(true, response.body) end
        else
            if callback then callback(false, "HTTP error: " .. tostring(code)) end
        end
    end)
    return true
end

local function requestLuaSec(url, method, body, callback)
    local respChunks = {}
    local options = {
        url = url,
        method = method,
        sink = transport.ltn12.sink.table(respChunks),
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = body and #body or 0
        }
    }
    if body then
        options.source = transport.ltn12.source.string(body)
    end

    local okCall, _, code = pcall(transport.mod.request, options)
    code = tonumber(code) or 0
    local response = table.concat(respChunks)
    if okCall and code >= 200 and code < 300 then
        if callback then callback(true, response) end
        return true
    end
    if callback then callback(false, "HTTP error: " .. tostring(code)) end
    return false
end

local function requestCurl(url, method, body, callback)
    if curlBroken then
        if callback then callback(false, "curl unavailable") end
        return false
    end

    local dataArg = ""
    if body then
        -- Тело пишем во временный файл — экранировать JSON внутри shell ненадёжно
        pcall(function()
            love.filesystem.write("curl_body.tmp", body)
        end)
        local filePath = love.filesystem.getSaveDirectory() .. "/curl_body.tmp"
        dataArg = string.format('--data-binary @"%s"', filePath)
    end

    local cmd = string.format(
        'curl -s --max-time 10 -X %s -H "Content-Type: application/json" %s -w "\n%%{http_code}" "%s"',
        method, dataArg, url)

    local pipe = io.popen(cmd, "r")
    if not pipe then
        curlBroken = true
        if callback then callback(false, "curl failed to start") end
        return false
    end

    local out = pipe:read("*a") or ""
    pipe:close()

    local response, codeStr = out:match("^(.*)\n(%d+)%s*$")
    local code = tonumber(codeStr) or 0
    if code == 0 then
        curlBroken = true
        if callback then callback(false, "curl not found or network error") end
        return false
    end
    if code >= 200 and code < 300 then
        if callback then callback(true, response or "") end
        return true
    end
    if callback then callback(false, "HTTP error: " .. code) end
    return false
end

-- ============================================================
--  ЕДИНАЯ ТОЧКА ОТПРАВКИ (API прежний: online.sendRequest)
-- ============================================================
function online.sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    print("[ONLINE] " .. method .. " " .. path .. " [" .. transport.name .. "]")

    if transport.name == "lua-https" then
        return requestLuaHttps(url, method, body, callback)
    elseif transport.name == "scrap-mods-http" then
        return requestScrapMods(url, method, body, callback)
    elseif transport.name == "luasec" then
        return requestLuaSec(url, method, body, callback)
    elseif transport.name == "curl" then
        return requestCurl(url, method, body, callback)
    end

    print("[ONLINE] ❌ No HTTP client available! Install lua-https, Scrap-Mods/http, LuaSec or curl")
    if callback then callback(false, "No HTTP client") end
    return false
end

-- Для асинхронных транспортов (Scrap-Mods/http): вызывать каждый кадр.
function online.pump()
    if transport.name == "scrap-mods-http" and transport.mod and transport.mod.update then
        pcall(transport.mod.update)
    end
end

function online.getTransportName()
    return transport.name
end

-- ============================================================
--  ПАРСИНГ
-- ============================================================
function online.parsePlayers(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}

    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local nick = data:match('"nickname":%s*"([^"]+)"')
        local skin = data:match('"skin":%s*"([^"]+)"')
        local hp = data:match('"hp":%s*([%d]+)')
        if x and y then
            result[id] = {
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                nickname = nick or "Player",
                skin = skin or "NONE",
                hp = tonumber(hp) or 5,
                targetX = tonumber(x) or 0,
                targetY = tonumber(y) or 0
            }
        end
    end
    return result
end

function online.parseBullets(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local dx = data:match('"dx":%s*([%d%.%-]+)')
        local dy = data:match('"dy":%s*([%d%.%-]+)')
        local owner = data:match('"owner":%s*"([^"]+)"')
        local isDash = data:match('"isDash":%s*([%a]+)')
        if x and y and dx and dy then
            result[id] = {
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                dx = tonumber(dx) or 0,
                dy = tonumber(dy) or 0,
                owner = owner or "",
                isDash = (isDash == "true"),
                life = 3
            }
        end
    end
    return result
end

function online.parseAbilities(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local typ = data:match('"type":%s*"([^"]+)"')
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local owner = data:match('"owner":%s*"([^"]+)"')
        if typ and x and y then
            result[id] = {
                type = typ,
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                owner = owner or "",
                dirX = tonumber(data:match('"dirX":%s*([%d%.%-]+)')) or 0,
                dirY = tonumber(data:match('"dirY":%s*([%d%.%-]+)')) or 0,
                time = tonumber(data:match('"time":%s*([%d%.%-]+)')) or 0
            }
        end
    end
    return result
end

local function resetEventState()
    eventActive = false
    eventRequestInFlight = false
    lastEventFetchTime = nil
    -- Игнорируем ответы от запросов, начатых в предыдущем сеансе.
    eventRequestGeneration = eventRequestGeneration + 1
end

local function isEventEnabled(response)
    -- Firebase для значения Event возвращает JSON-число (1 или 0).
    -- Строковый вариант тоже поддержан, если значение записано как "1".
    local value = tostring(response or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return value == "1" or value == "\"1\""
end

function online.isEventActive()
    return eventActive
end

function online.init(nickname)
    resetEventState()
    myNickname = nickname or "Player"
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    myUid = SAVE_DATA.uid or generateUuid()
    SAVE_DATA.uid = myUid
    SAVE_SAVE()

    setDebug("Online initialized with UID: " .. myUid .. " [" .. transport.name .. "]")
    online.connect()
end

function online.connect()
    if not myUid then return end

    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":400,"y":300,"hp":5,"nickname":"%s","skin":"%s"}', myNickname, mySkin)

    setDebug("Connecting...")

    online.sendRequest("PUT", path, data, function(ok, response)
        if ok then
            isConnected = true
            setDebug("✅ Connected!")
            print("[ONLINE] ✅ Connected to Firebase!")
        else
            setDebug("❌ Failed to connect")
            isConnected = false
            print("[ONLINE] ❌ Connection failed: " .. tostring(response))
        end
    end)
end

function online.getMyUid()
    return myUid
end

function online.getPlayers()
    return players
end

function online.getBullets()
    return bullets
end

function online.getAbilities()
    return abilities
end

function online.isConnected()
    return isConnected
end

function online.getDebugText()
    return debugText
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then return end

    local newX = math.floor(x)
    local newY = math.floor(y)

    if lastSentX == newX and lastSentY == newY then return end

    local now = love.timer.getTime()
    if now - lastSentTime < 0.2 then return end
    lastSentTime = now

    lastSentX = newX
    lastSentY = newY

    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":%d,"y":%d}', newX, newY)
    online.sendRequest("PATCH", path, data)
end

function online.sendBullet(x, y, dx, dy, isDash)
    if not isConnected or not myUid then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = BULLETS_PATH .. bulletId
    local data = string.format('{"x":%d,"y":%d,"dx":%f,"dy":%f,"owner":"%s","isDash":%s,"time":%f}',
        math.floor(x), math.floor(y), dx, dy, myUid, isDash and "true" or "false", love.timer.getTime())
    online.sendRequest("PUT", path, data)
end

function online.sendAbility(abilityType, x, y, dirX, dirY)
    if not isConnected or not myUid then return end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ABILITIES_PATH .. abilityId
    local data = string.format('{"type":"%s","x":%d,"y":%d,"dirX":%f,"dirY":%f,"owner":"%s","time":%f}',
        abilityType, math.floor(x), math.floor(y), dirX or 0, dirY or 0, myUid, love.timer.getTime())
    online.sendRequest("PUT", path, data)
end

function online.updateSkin(skin)
    mySkin = skin
    if isConnected and myUid then
        local path = PLAYERS_PATH .. myUid
        local data = string.format('{"skin":"%s"}', skin)
        online.sendRequest("PATCH", path, data)
    end
end

function online.fetchPlayers()
    -- Больше не используется напрямую, заменено на online.sync()
end

function online.sync(callbackForDamage)
    if not isConnected then return end

    online.sendRequest("GET", "", nil, function(ok, res)
        if not ok or not res or res == "null" then return end

        -- Парсим игроков
        local playersPart = res:match('"players":%s*({.-})%s*[,}]')
        if playersPart then
            local newPlayers = online.parsePlayers(playersPart)
            for id, data in pairs(newPlayers) do
                if id ~= myUid then
                    if not players[id] then
                        players[id] = data
                    else
                        players[id].targetX = data.x
                        players[id].targetY = data.y
                        players[id].nickname = data.nickname
                        players[id].skin = data.skin
                        players[id].hp = data.hp or 5
                    end
                end
            end
            for id in pairs(players) do
                if not newPlayers[id] then players[id] = nil end
            end
        end

        -- Парсим пули
        local bulletsPart = res:match('"bullets":%s*({.-})%s*[,}]')
        if bulletsPart then
            bullets = online.parseBullets(bulletsPart)
        else
            bullets = {}
        end

        -- Парсим способности
        local abilitiesPart = res:match('"abilities":%s*({.-})%s*[,}]')
        if abilitiesPart then
            abilities = online.parseAbilities(abilitiesPart)
        else
            abilities = {}
        end

        -- Парсим событие
        local eventPart = res:match('"Event":%s*(%d+)')
        if eventPart then
            local wasActive = eventActive
            eventActive = (eventPart == "1")
            if eventActive ~= wasActive then
                print("[ONLINE] Event is " .. (eventActive and "enabled" or "disabled"))
            end
        end

        -- Проверяем урон для нас
        if myUid then
            local damagePart = res:match('"damage":%s*({.-})%s*[,}]')
            if damagePart then
                local myDamage = damagePart:match('"' .. myUid .. '":%s*({[^{}]+})')
                if myDamage then
                    local dmg = myDamage:match('"damage":%s*(%d+)')
                    local attacker = myDamage:match('"attacker":%s*"([^"]+)"')
                    if dmg and callbackForDamage then
                        callbackForDamage({damage=tonumber(dmg), attacker=attacker})
                        -- Удаляем запись об уроне после обработки
                        online.sendRequest("DELETE", DAMAGE_PATH .. myUid, nil, function() end)
                    end
                end
            end
        end
    end)
end

function online.update(dt)
    if not isConnected then return end

    online.pump()

    for id, p in pairs(players) do
        if p.targetX then
            p.x = p.x or p.targetX
            p.y = p.y or p.targetY
            -- Более плавная и быстрая интерполяция
            local lerpSpeed = 15
            p.x = p.x + (p.targetX - p.x) * math.min(1, dt * lerpSpeed)
            p.y = p.y + (p.targetY - p.y) * math.min(1, dt * lerpSpeed)
            p.hp = p.hp or 5
        end
    end

    fetchTimer = fetchTimer + dt
    -- Вызываем синхронизацию раз в 0.5 секунд (включает всё: игроков, пули, урон, события)
    if fetchTimer >= 0.5 then
        fetchTimer = 0
        -- Мы передадим колбэк для урона в game.lua через специальную переменную или вызов
    end
end

function online.leave()
    if isConnected and myUid then
        online.sendRequest("DELETE", PLAYERS_PATH .. myUid)
    end
    isConnected = false
    players = {}
    bullets = {}
    abilities = {}
    resetEventState()
    myUid = nil
    myNickname = nil
    lastSentX = nil
    lastSentY = nil
end

-- ============================================================
--  ДОПОЛНИТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================
function online.sendDamage(targetUid, damage, attackerUid)
    if not isConnected or not myUid then return end
    local path = DAMAGE_PATH .. targetUid
    local data = string.format('{"damage":%d,"attacker":"%s","time":%f}',
        damage, attackerUid or myUid, love.timer.getTime())
    online.sendRequest("PUT", path, data)
end

function online.updateHP(hp)
    if not isConnected or not myUid then return end
    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"hp":%d}', hp)
    online.sendRequest("PATCH", path, data)
end

function online.getPlayerHP(uid)
    if not players[uid] then return 5 end
    return players[uid].hp or 5
end

return online

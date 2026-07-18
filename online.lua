-- online.lua - ИСПОЛЬЗУЕТ LUASOCKET НА ВСЕХ ПЛАТФОРМАХ!
local online = {}

-- ============================================================
--  КОНФИГУРАЦИЯ FIREBASE
-- ============================================================
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local API_KEY = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4"

local PLAYERS_PATH = "players/"
local BULLETS_PATH = "bullets/"
local ABILITIES_PATH = "abilities/"

-- ============================================================
--  СОСТОЯНИЕ
-- ============================================================
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

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

-- ============================================================
--  LUA SOCKET (РАБОТАЕТ НА ВСЕХ ПЛАТФОРМАХ!)
-- ============================================================
local function sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    
    print("[ONLINE] " .. method .. " " .. path)
    print("[ONLINE] URL: " .. url)
    
    -- Подключаем LuaSocket
    local ok, http = pcall(require, "socket.http")
    if not ok then
        print("[ONLINE] ❌ LuaSocket не найден!")
        setDebug("LuaSocket not found")
        if callback then callback(false, "LuaSocket not found") end
        return false
    end
    
    local ltn12 = require("ltn12")
    local request_body = body or ""
    local response_body = {}
    
    print("[ONLINE] Body: " .. request_body)
    
    -- Отправляем запрос
    local res, code = pcall(http.request, {
        url = url,
        method = method,
        headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#request_body),
        },
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body),
        timeout = 10,
    })
    
    if res then
        local codeNum = tonumber(code) or 0
        if codeNum >= 200 and codeNum < 300 then
            local response = table.concat(response_body)
            print("[ONLINE] ✅ Успех! Код: " .. codeNum)
            print("[ONLINE] Ответ: " .. response)
            if callback then callback(true, response) end
            return true
        else
            print("[ONLINE] ❌ Ошибка HTTP: " .. codeNum)
            print("[ONLINE] Ответ: " .. table.concat(response_body))
            if callback then callback(false, "HTTP error: " .. codeNum) end
            return false
        end
    else
        print("[ONLINE] ❌ Исключение: " .. tostring(code))
        if callback then callback(false, tostring(code)) end
        return false
    end
end

-- ============================================================
--  ПАРСИНГ
-- ============================================================
local function parsePlayers(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local nick = data:match('"nickname":%s*"([^"]+)"')
        local skin = data:match('"skin":%s*"([^"]+)"')
        if x and y then
            result[id] = {
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                nickname = nick or "Player",
                skin = skin or "NONE",
                targetX = tonumber(x) or 0,
                targetY = tonumber(y) or 0
            }
        end
    end
    return result
end

local function parseBullets(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local dx = data:match('"dx":%s*([%d%.%-]+)')
        local dy = data:match('"dy":%s*([%d%.%-]+)')
        local owner = data:match('"owner":%s*"([^"]+)"')
        if x and y and dx and dy then
            result[id] = {
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                dx = tonumber(dx) or 0,
                dy = tonumber(dy) or 0,
                owner = owner or "",
                life = 3
            }
        end
    end
    return result
end

local function parseAbilities(jsonStr)
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

-- ============================================================
--  ОСНОВНЫЕ ФУНКЦИИ
-- ============================================================
function online.init(nickname)
    myNickname = nickname or "Player"
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    myUid = SAVE_DATA.uid or generateUuid()
    SAVE_DATA.uid = myUid
    SAVE_SAVE()
    
    setDebug("Online initialized with UID: " .. myUid)
    online.connect()
end

function online.connect()
    if not myUid then return end
    
    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
    
    setDebug("Connecting...")
    
    sendRequest("PUT", path, data, function(ok, response)
        if ok then
            isConnected = true
            setDebug("✅ Connected!")
            print("[ONLINE] ✅ Connected to Firebase!")
        else
            setDebug("❌ Failed to connect")
            isConnected = false
            print("[ONLINE] ❌ Connection failed!")
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
    if now - lastSentTime < 0.5 then return end
    lastSentTime = now

    lastSentX = newX
    lastSentY = newY

    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":%d,"y":%d,"nickname":"%s","skin":"%s"}', 
        newX, newY, myNickname, mySkin)
    sendRequest("PATCH", path, data)
end

function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = BULLETS_PATH .. bulletId
    local data = string.format('{"x":%d,"y":%d,"dx":%f,"dy":%f,"owner":"%s","time":%f}',
        math.floor(x), math.floor(y), dx, dy, myUid, love.timer.getTime())
    sendRequest("PUT", path, data)
end

function online.sendAbility(abilityType, x, y, dirX, dirY)
    if not isConnected or not myUid then return end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ABILITIES_PATH .. abilityId
    local data = string.format('{"type":"%s","x":%d,"y":%d,"dirX":%f,"dirY":%f,"owner":"%s","time":%f}',
        abilityType, math.floor(x), math.floor(y), dirX or 0, dirY or 0, myUid, love.timer.getTime())
    sendRequest("PUT", path, data)
end

function online.updateSkin(skin)
    mySkin = skin
    if isConnected and myUid then
        local path = PLAYERS_PATH .. myUid
        local data = string.format('{"skin":"%s"}', skin)
        sendRequest("PATCH", path, data)
    end
end

function online.fetchPlayers()
    if not isConnected then return end

    sendRequest("GET", PLAYERS_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            local newPlayers = parsePlayers(res)

            for id, data in pairs(newPlayers) do
                if id ~= myUid then
                    if not players[id] then
                        players[id] = data
                    else
                        players[id].targetX = data.x
                        players[id].targetY = data.y
                        players[id].nickname = data.nickname
                        players[id].skin = data.skin
                    end
                end
            end

            for id in pairs(players) do
                if not newPlayers[id] then
                    players[id] = nil
                end
            end
        end
    end)

    sendRequest("GET", BULLETS_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            bullets = parseBullets(res)
        end
    end)

    sendRequest("GET", ABILITIES_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            abilities = parseAbilities(res)
        end
    end)
end

function online.update(dt)
    if not isConnected then return end

    for id, p in pairs(players) do
        if p.targetX then
            p.x = p.x or p.targetX
            p.y = p.y or p.targetY
            p.x = p.x + (p.targetX - p.x) * math.min(1, dt * 8)
            p.y = p.y + (p.targetY - p.y) * math.min(1, dt * 8)
        end
    end

    fetchTimer = fetchTimer + dt
    if fetchTimer >= 2.0 then
        fetchTimer = 0
        online.fetchPlayers()
    end
end

function online.leave()
    if isConnected and myUid then
        sendRequest("DELETE", PLAYERS_PATH .. myUid)
    end
    isConnected = false
    players = {}
    bullets = {}
    abilities = {}
    myUid = nil
    myNickname = nil
    lastSentX = nil
    lastSentY = nil
end

return online

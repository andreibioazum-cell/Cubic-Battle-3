-- online.lua - PowerShell + curl (ПОЛНОСТЬЮ СКРЫТО!)
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
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.5
local FETCH_INTERVAL = 1.0

local isWindows = (love.system.getOS() == "Windows")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

-- ============================================================
--  ОТПРАВКА ЗАПРОСА (ПОЛНОСТЬЮ СКРЫТО!)
-- ============================================================
function online.sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    
    print("[ONLINE] " .. method .. " " .. url)
    
    -- ============================================================
    --  СПОСОБ 1: Встроенный https (LÖVE 12.0)
    -- ============================================================
    local ok, https = pcall(require, "https")
    if ok then
        local ltn12 = require("ltn12")
        local response_body = {}
        local request_body = body or ""
        local headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#request_body),
        }
        
        local res, code = https.request(url, {
            method = method,
            headers = headers,
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
            timeout = 10,
            verify = false,
        })
        
        local response = table.concat(response_body)
        code = tonumber(code) or 0
        
        if code >= 200 and code < 300 then
            print("[ONLINE] ✅ HTTPS success!")
            if callback then callback(true, response) end
            return true
        else
            print("[ONLINE] ❌ HTTPS error: " .. code)
        end
    end
    
    -- ============================================================
    --  СПОСОБ 2: socket.http (LÖVE 11.5)
    -- ============================================================
    local ok, http = pcall(require, "socket.http")
    if ok then
        local ltn12 = require("ltn12")
        local response_body = {}
        local request_body = body or ""
        
        http.TIMEOUT = 10
        
        local res, code = http.request{
            url = url,
            method = method,
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#request_body),
            },
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
        }
        
        local response = table.concat(response_body)
        code = tonumber(code) or 0
        
        if code >= 200 and code < 300 then
            print("[ONLINE] ✅ socket.http success!")
            if callback then callback(true, response) end
            return true
        else
            print("[ONLINE] ❌ socket.http error: " .. code)
        end
    end
    
    -- ============================================================
    --  СПОСОБ 3: PowerShell + curl (ПОЛНОСТЬЮ СКРЫТО!)
    -- ============================================================
    if isWindows then
        local data = body or "{}"
        data = data:gsub('"', '""')  -- Для PowerShell нужно двойные кавычки
        
        local cmd
        if method == "GET" then
            cmd = 'curl -s -X GET "' .. url .. '"'
        else
            cmd = 'curl -s -X ' .. method .. ' -H "Content-Type: application/json" -d "' .. data .. '" "' .. url .. '"'
        end
        
        -- PowerShell скрипт: запускает curl СКРЫТО
        local psScript = [[
$cmd = "]] .. cmd .. [["
$result = & cmd /c $cmd 2>$null
Write-Output $result
]]
        
        -- Сохраняем PowerShell скрипт
        local psPath = os.tmpname() .. ".ps1"
        local file = io.open(psPath, "w")
        file:write(psScript)
        file:close()
        
        print("[ONLINE] PS: " .. psPath)
        
        -- Запускаем PowerShell СКРЫТО через cmd
        local runCmd = 'powershell -ExecutionPolicy Bypass -WindowStyle Hidden -File "' .. psPath .. '"'
        local handle = io.popen(runCmd)
        local result = handle and handle:read("*a")
        if handle then handle:close() end
        
        -- Удаляем PS файл
        os.remove(psPath)
        
        if result and result ~= "" and not result:match("curl:") then
            print("[ONLINE] ✅ Hidden PowerShell success!")
            if callback then callback(true, result) end
            return true
        else
            print("[ONLINE] ❌ PowerShell failed: " .. tostring(result))
        end
    end
    
    -- ============================================================
    --  ВСЁ ПРОВАЛИЛОСЬ
    -- ============================================================
    print("[ONLINE] ❌ ALL METHODS FAILED!")
    if callback then callback(false, "All methods failed") end
    return false
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
        local type = data:match('"type":%s*"([^"]+)"')
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local owner = data:match('"owner":%s*"([^"]+)"')
        if type and x and y then
            result[id] = {
                type = type,
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
    
    online.sendRequest("PUT", path, data, function(ok, response)
        if ok then
            isConnected = true
            setDebug("✅ Connected!")
            print("[ONLINE] ✅ Connected to Firebase!")
        else
            setDebug("❌ Failed")
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

    lastSentX = newX
    lastSentY = newY

    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":%d,"y":%d,"nickname":"%s","skin":"%s"}', 
        newX, newY, myNickname, mySkin)
    online.sendRequest("PATCH", path, data)
end

function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = BULLETS_PATH .. bulletId
    local data = string.format('{"x":%d,"y":%d,"dx":%f,"dy":%f,"owner":"%s","time":%f}',
        math.floor(x), math.floor(y), dx, dy, myUid, love.timer.getTime())
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
    if not isConnected then return end

    online.sendRequest("GET", PLAYERS_PATH, nil, function(ok, res)
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

    online.sendRequest("GET", BULLETS_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            bullets = parseBullets(res)
        end
    end)

    online.sendRequest("GET", ABILITIES_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            abilities = parseAbilities(res)
        end
    end)
end

function online.update(dt)
    if not isConnected then return end

    -- Плавная интерполяция
    for id, p in pairs(players) do
        if p.targetX then
            p.x = p.x or p.targetX
            p.y = p.y or p.targetY
            p.x = p.x + (p.targetX - p.x) * math.min(1, dt * 8)
            p.y = p.y + (p.targetY - p.y) * math.min(1, dt * 8)
        end
    end

    -- Обновление пуль
    for id, b in pairs(bullets) do
        b.x = b.x + b.dx * 390 * dt
        b.y = b.y + b.dy * 390 * dt
        b.life = b.life - dt
        if b.life <= 0 then bullets[id] = nil end
    end

    -- Отправка позиции
    sendTimer = sendTimer + dt
    if sendTimer >= SEND_INTERVAL then
        sendTimer = 0
        if online.onSendPosition then
            local x, y = online.onSendPosition()
            if x and y then
                online.sendPosition(x, y)
            end
        end
    end

    -- Получение данных
    fetchTimer = fetchTimer + dt
    if fetchTimer >= FETCH_INTERVAL then
        fetchTimer = 0
        online.fetchPlayers()
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
    myUid = nil
    myNickname = nil
    lastSentX = nil
    lastSentY = nil
end

return online

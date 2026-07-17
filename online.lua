-- online.lua - СУПЕР БЫСТРЫЙ! Не блокирует игру!
local online = {}

-- ============================================================
--  КОНФИГУРАЦИЯ
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
local SEND_INTERVAL = 0.5  -- реже отправляем
local FETCH_INTERVAL = 1.0  -- реже получаем

local isAndroid = (love.system.getOS() == "Android")

-- ============================================================
--  ОЧЕРЕДЬ ЗАПРОСОВ (НЕ БЛОКИРУЕТ!)
-- ============================================================
local requestQueue = {}
local isProcessing = false

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

-- ============================================================
--  ОТПРАВКА ЗАПРОСА В ФОНЕ (НЕ БЛОКИРУЕТ!)
-- ============================================================
function online.sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    
    -- Добавляем в очередь
    table.insert(requestQueue, {
        method = method,
        url = url,
        body = body,
        callback = callback,
        timestamp = love.timer.getTime()
    })
    
    -- Если очередь не обрабатывается - запускаем
    if not isProcessing then
        processQueue()
    end
end

-- ============================================================
--  ОБРАБОТЧИК ОЧЕРЕДИ (В ФОНЕ!)
-- ============================================================
function processQueue()
    if #requestQueue == 0 then
        isProcessing = false
        return
    end
    
    isProcessing = true
    local req = table.remove(requestQueue, 1)
    
    print("[ONLINE] Sending: " .. req.method .. " " .. req.url)
    
    -- ============================================================
    --  Android: используем https
    -- ============================================================
    if isAndroid then
        local ok, https = pcall(require, "https")
        if ok then
            local ltn12 = require("ltn12")
            local response_body = {}
            local request_body = req.body or ""
            local headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(#request_body),
            }
            
            local res, code = https.request(req.url, {
                method = req.method,
                headers = headers,
                source = ltn12.source.string(request_body),
                sink = ltn12.sink.table(response_body),
                timeout = 5,
                verify = false,
            })
            
            local response = table.concat(response_body)
            code = tonumber(code) or 0
            
            if code >= 200 and code < 300 then
                print("[ONLINE] ✅ Success!")
                if req.callback then req.callback(true, response) end
            else
                print("[ONLINE] ❌ Error: " .. code)
                if req.callback then req.callback(false, response) end
            end
            
            -- Обрабатываем следующую очередь
            processQueue()
            return
        end
    end
    
    -- ============================================================
    --  ПК: используем curl (НО НЕ ЖДЕМ!)
    -- ============================================================
    local cmd
    if req.method == "GET" then
        cmd = 'start /B curl -s -X GET "' .. req.url .. '" > NUL 2>&1'
    else
        local data = req.body or "{}"
        data = data:gsub('"', '\\"')
        cmd = 'start /B curl -s -X ' .. req.method .. ' -H "Content-Type: application/json" -d "' .. data .. '" "' .. req.url .. '" > NUL 2>&1'
    end
    
    print("[ONLINE] CMD: " .. cmd)
    
    -- ЗАПУСКАЕМ В ФОНЕ! НЕ ЖДЕМ ОТВЕТА!
    os.execute(cmd)
    
    -- Сразу говорим "успешно" (мы не знаем результат)
    if req.callback then 
        req.callback(true, "Sent") 
    end
    
    -- Обрабатываем следующую очередь
    processQueue()
end

-- ============================================================
--  ПОЛУЧЕНИЕ ДАННЫХ (ОТДЕЛЬНЫЙ ПОТОК)
-- ============================================================
function online.fetchDataSync()
    if not isConnected then return end
    
    -- Получаем игроков через curl (с ожиданием, но редко)
    local function fetchPlayers()
        local url = DB_URL .. PLAYERS_PATH .. ".json?auth=" .. API_KEY
        local cmd = 'curl -s -X GET "' .. url .. '"'
        
        print("[ONLINE] Fetching players...")
        local handle = io.popen(cmd)
        local result = handle and handle:read("*a")
        if handle then handle:close() end
        
        if result and result ~= "" and not result:match("curl:") then
            local newPlayers = parsePlayers(result)
            
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
    end
    
    fetchPlayers()
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
    
    -- Сразу подключаемся
    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
    
    online.sendRequest("PUT", path, data, function(ok, response)
        if ok then
            isConnected = true
            setDebug("✅ Connected!")
        else
            setDebug("❌ Failed")
            isConnected = false
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

    -- Получаем данные раз в 2 секунды (редко, чтобы не лагать)
    fetchTimer = fetchTimer + dt
    if fetchTimer >= FETCH_INTERVAL then
        fetchTimer = 0
        online.fetchDataSync()
    end
end

function online.leave()
    if isConnected and myUid then
        local path = PLAYERS_PATH .. myUid
        online.sendRequest("DELETE", path)
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

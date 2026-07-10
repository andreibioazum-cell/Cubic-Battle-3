-- online.lua – работа с Firebase Realtime Database
local online = {}

local PATH = "players/"
local ROOMS_PATH = "rooms/"
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"

local myUid = nil
local myNickname = nil
local myRoomCode = nil
local mySkin = "NONE"
local players = {}
local bullets = {}
local abilities = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.5
local FETCH_INTERVAL = 0.6
local isConnected = false
local debugText = "Waiting..."
local lastSentX = nil
local lastSentY = nil

local isAndroid = (love.system.getOS() == "Android")

local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

local function generateUuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = math.random(0, 15)
        if c == "x" then return string.format("%x", v)
        else return string.format("%x", math.random(8, 11))
        end
    end)
end

function online.generateRoomCode()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local code = ""
    for i = 1, 5 do
        local idx = math.random(1, #chars)
        code = code .. chars:sub(idx, idx)
    end
    return code
end

function online.init()
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    if isAndroid then
        setDebug("Online ready: Android (HTTPS)")
    else
        setDebug("Online ready: PC (curl)")
    end
end

-- ============================================================
--  ОТПРАВКА ЗАПРОСОВ (ПК: curl, Android: https)
-- ============================================================
function sendRequest(method, path, body, callback)
    if isAndroid then
        local https = require("https")
        local url = DB_URL .. path .. ".json"
        local options = {
            method = method,
            headers = { ["Content-Type"] = "application/json" },
            data = body or "",
            timeout = 5,
            verify = false,
        }
        local success, code, response = pcall(https.request, url, options)
        if success and code and code >= 200 and code < 300 then
            if callback then callback(true, response) end
        else
            local err = "{\"error\":\"HTTPS " .. tostring(code) .. "\"}"
            if callback then callback(false, err) end
        end
    else
        local url = DB_URL .. path .. ".json"
        local curlCmd = 'curl -s -X ' .. method .. ' "' .. url .. '"'
        if body and body ~= "" then
            local escapedBody = body:gsub('"', '\\"')
            curlCmd = curlCmd .. ' -H "Content-Type: application/json" -d "' .. escapedBody .. '"'
        end
        curlCmd = curlCmd .. ' 2>&1'
        
        local handle = io.popen(curlCmd)
        local result = handle:read("*a")
        handle:close()
        
        if result and result ~= "" and not result:match("error") and not result:match("curl") then
            if callback then callback(true, result) end
        else
            local err = "{\"error\":\"curl " .. (result or "failed") .. "\"}"
            if callback then callback(false, err) end
        end
    end
end

-- ============================================================
--  ЗАПИСЬ ИГРОКА В КОМНАТУ
-- ============================================================
local function writePlayerToRoom(roomCode, uid, nickname, skin, callback)
    local path = ROOMS_PATH .. roomCode .. "/players/" .. uid
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. skin .. '"}'
    setDebug("Writing player to: " .. path)
    setDebug("Data: " .. data)
    sendRequest("PUT", path, data, function(success, response)
        if success then
            setDebug("Player written successfully")
            setDebug("Response: " .. tostring(response))
        else
            setDebug("Failed to write player: " .. tostring(response))
        end
        if callback then callback(success, response) end
    end)
end

-- ============================================================
--  ПРОВЕРКА ИГРОКОВ В КОМНАТЕ
-- ============================================================
local function checkRoomPlayers(roomCode, callback)
    local path = ROOMS_PATH .. roomCode .. "/players"
    setDebug("Checking players in: " .. path)
    sendRequest("GET", path, nil, function(success, response)
        if success and response and response ~= "null" then
            setDebug("Room players response: " .. tostring(response))
            if callback then callback(true, response) end
        else
            setDebug("No players in room: " .. tostring(response))
            if callback then callback(false, response) end
        end
    end)
end

-- ============================================================
--  ПАРСИНГ JSON
-- ============================================================
local function parsePlayersFromJSON(jsonStr)
    local result = {}
    if not jsonStr or jsonStr == "" or jsonStr == "null" then
        return result
    end
    
    -- Пробуем распарсить через love.data.decode
    local ok, data = pcall(love.data.decode, "string", "json", jsonStr)
    if ok and data then
        for uid, info in pairs(data) do
            if type(info) == "table" then
                result[uid] = {
                    x = info.x or 0,
                    y = info.y or 0,
                    nickname = info.nickname or "???",
                    skin = info.skin or "NONE",
                    targetX = info.x or 0,
                    targetY = info.y or 0,
                    lerpTimer = 0
                }
            end
        end
        return result
    end
    
    -- Если love.data.decode не сработал, парсим вручную
    local pattern = '"([%w_%-]+)"%s*:%s*({[^}]*})'
    for uid, data in string.gmatch(jsonStr, pattern) do
        local x = data:match('"x"%s*:%s*([%d%.%-]+)')
        local y = data:match('"y"%s*:%s*([%d%.%-]+)')
        local nickname = data:match('"nickname"%s*:%s*"([^"]*)"')
        local skin = data:match('"skin"%s*:%s*"([^"]*)"')
        
        if x and y then
            result[uid] = {
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                nickname = nickname or "???",
                skin = skin or "NONE",
                targetX = tonumber(x) or 0,
                targetY = tonumber(y) or 0,
                lerpTimer = 0
            }
        end
    end
    return result
end

-- ============================================================
--  СОЗДАНИЕ КОМНАТЫ
-- ============================================================
function online.createRoom(roomCode, nickname, callback)
    if not nickname or nickname == "" then
        setDebug("Nickname required")
        if callback then callback(false, "Nickname required") end
        return
    end
    if not roomCode or roomCode == "" then
        roomCode = online.generateRoomCode()
    end

    myRoomCode = roomCode
    myUid = generateUuid()
    myNickname = nickname
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    -- Создаём комнату
    local roomPath = ROOMS_PATH .. roomCode .. "/info"
    local roomData = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'
    sendRequest("PUT", roomPath, roomData, function(success, response)
        if not success then
            setDebug("Failed to create room: " .. tostring(response))
            if callback then callback(false, response) end
            return
        end
        
        -- Записываем игрока
        writePlayerToRoom(roomCode, myUid, nickname, mySkin, function(success2)
            if success2 then
                isConnected = true
                setDebug("Room created: " .. roomCode)
                -- Проверяем игроков
                checkRoomPlayers(roomCode, function(ok, data)
                    if ok and data then
                        local parsed = parsePlayersFromJSON(data)
                        local count = 0
                        for uid, _ in pairs(parsed) do
                            if uid ~= myUid then count = count + 1 end
                        end
                        setDebug("Players in room: " .. count)
                    end
                end)
                if callback then callback(true) end
            else
                setDebug("Failed to write player")
                if callback then callback(false) end
            end
        end)
    end)
end

-- ============================================================
--  ВХОД В КОМНАТУ
-- ============================================================
function online.joinRoom(roomCode, nickname, callback)
    if not nickname or nickname == "" then
        setDebug("Nickname required")
        if callback then callback(false, "Nickname required") end
        return
    end
    if not roomCode or roomCode == "" then
        setDebug("Room code required")
        if callback then callback(false, "Room code required") end
        return
    end

    myRoomCode = roomCode
    myUid = generateUuid()
    myNickname = nickname
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    -- Проверяем, существует ли комната
    local checkPath = ROOMS_PATH .. roomCode .. "/info"
    sendRequest("GET", checkPath, nil, function(success, response)
        if not success or response == "null" then
            setDebug("Room does not exist")
            if callback then callback(false, "Room not found") end
            return
        end
        
        -- Записываем игрока
        writePlayerToRoom(roomCode, myUid, nickname, mySkin, function(success2)
            if success2 then
                isConnected = true
                setDebug("Joined room: " .. roomCode)
                -- Проверяем игроков
                checkRoomPlayers(roomCode, function(ok, data)
                    if ok and data then
                        local parsed = parsePlayersFromJSON(data)
                        local count = 0
                        for uid, _ in pairs(parsed) do
                            if uid ~= myUid then count = count + 1 end
                        end
                        setDebug("Players in room: " .. count)
                    end
                end)
                if callback then callback(true) end
            else
                setDebug("Failed to write player")
                if callback then callback(false) end
            end
        end)
    end)
end

-- ============================================================
--  ОТПРАВКА ПОЗИЦИИ
-- ============================================================
function online.sendPosition(x, y)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    
    local newX = math.floor(x)
    local newY = math.floor(y)
    if lastSentX == newX and lastSentY == newY then
        return
    end
    
    lastSentX = newX
    lastSentY = newY
    
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    local data = '{"x":' .. newX .. ',"y":' .. newY .. ',"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ОТПРАВКА ПУЛИ
-- ============================================================
function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/bullets/" .. bulletId
    local data = '{"x":' .. x .. ',"y":' .. y .. ',"dx":' .. dx .. ',"dy":' .. dy .. ',"owner":"' .. myUid .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ОТПРАВКА СПОСОБНОСТИ
-- ============================================================
function online.sendAbility(abilityType, x, y, dirX, dirY, targetUid)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/abilities/" .. abilityId
    local data = '{"type":"' .. abilityType .. '","x":' .. x .. ',"y":' .. y .. ',"dirX":' .. (dirX or 0) .. ',"dirY":' .. (dirY or 0) .. ',"owner":"' .. myUid .. '","target":"' .. (targetUid or "") .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ПОЛУЧЕНИЕ ИГРОКОВ
-- ============================================================
function online.fetchPlayers()
    if not isConnected or not myRoomCode then
        setDebug("Cannot fetch: not connected or no room")
        return
    end
    
    local path = ROOMS_PATH .. myRoomCode .. "/players"
    setDebug("Fetching players from: " .. path)
    
    sendRequest("GET", path, nil, function(success, response)
        if success and response and response ~= "null" then
            -- Выводим сырой ответ для отладки
            print("RAW RESPONSE: " .. tostring(response))
            
            local newPlayers = parsePlayersFromJSON(response)
            local count = 0
            
            -- Считаем игроков (исключая себя)
            for uid, _ in pairs(newPlayers) do
                if uid ~= myUid then
                    count = count + 1
                end
            end
            
            -- Удаляем себя из списка
            if newPlayers[myUid] then
                newPlayers[myUid] = nil
            end
            
            players = newPlayers
            
            -- Выводим всех игроков для отладки
            for uid, info in pairs(players) do
                print("Player: " .. uid .. " -> x=" .. info.x .. ", y=" .. info.y .. ", nick=" .. info.nickname)
            end
            
            setDebug("Players in room: " .. count)
        else
            setDebug("Failed to fetch players: " .. tostring(response))
        end
    end)
end

-- ============================================================
--  ПОЛУЧЕНИЕ ВСЕХ ДАННЫХ
-- ============================================================
function online.fetchData()
    if not isConnected or not myRoomCode then
        return
    end
    
    online.fetchPlayers()
    
    local path = ROOMS_PATH .. myRoomCode
    
    -- Получаем пули
    sendRequest("GET", path .. "/bullets", nil, function(success, response)
        if success and response and response ~= "null" then
            local ok, data = pcall(love.data.decode, "string", "json", response)
            if ok and data then
                bullets = {}
                for bid, info in pairs(data) do
                    if info.owner ~= myUid then
                        bullets[bid] = {
                            x = info.x or 0,
                            y = info.y or 0,
                            dx = info.dx or 0,
                            dy = info.dy or 0,
                            owner = info.owner or "",
                            time = info.time or 0,
                        }
                    end
                end
            end
        end
    end)
    
    -- Получаем способности
    sendRequest("GET", path .. "/abilities", nil, function(success, response)
        if success and response and response ~= "null" then
            local ok, data = pcall(love.data.decode, "string", "json", response)
            if ok and data then
                abilities = {}
                for aid, info in pairs(data) do
                    if info.owner ~= myUid then
                        abilities[aid] = {
                            type = info.type or "",
                            x = info.x or 0,
                            y = info.y or 0,
                            dirX = info.dirX or 0,
                            dirY = info.dirY or 0,
                            owner = info.owner or "",
                            target = info.target or "",
                            time = info.time or 0,
                        }
                    end
                end
            end
        end
    end)
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

function online.updateSkin(skin)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    mySkin = skin
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid .. "/skin"
    local data = '"' .. skin .. '"'
    sendRequest("PUT", path, data)
end

function online.getMySkin()
    return mySkin
end

function online.leave()
    if not isConnected or not myUid or not myRoomCode then return end
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    sendRequest("DELETE", path, nil)
    isConnected = false
    players = {}
    bullets = {}
    abilities = {}
    myUid = nil
    myNickname = nil
    myRoomCode = nil
    lastSentX = nil
    lastSentY = nil
end

function online.update(dt)
    if not isConnected then
        return
    end

    -- Плавное движение игроков
    for uid, p in pairs(players) do
        if p.targetX and p.targetY then
            p.lerpTimer = math.min(1, (p.lerpTimer or 0) + dt * 4.5)
            local t = p.lerpTimer
            local smooth = t * t * (3 - 2 * t)
            p.x = p.x + (p.targetX - p.x) * smooth
            p.y = p.y + (p.targetY - p.y) * smooth
        end
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
        online.fetchData()
    end
end

function online.getDebugText()
    return debugText
end

function online.isConnected()
    return isConnected
end

return online

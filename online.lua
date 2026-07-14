-- online.lua – работа с Firebase (ПК и Android)
local online = {}

local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local ROOMS_PATH = "rooms/"

local myUid = nil
local myNickname = nil
local myRoomCode = nil
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
local SEND_INTERVAL = 0.3
local FETCH_INTERVAL = 0.3

local isAndroid = (love.system.getOS() == "Android")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

-- Функция для отправки сообщений в отладку игры
local function sendToGameDebug(text, color)
    if _G.addDebugMessage then
        _G.addDebugMessage(text, color)
    end
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

function online.generateRoomCode()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code = ""
    for i = 1, 5 do
        local idx = math.random(1, #chars)
        code = code .. chars:sub(idx, idx)
    end
    return code
end

function online.init()
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    setDebug("Online initialized")
    sendToGameDebug("Online initialized", {0.5, 0.5, 0.8, 1})
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

-- ============================================================
--  ОТПРАВКА ЗАПРОСОВ (РАБОТАЕТ НА ПК И ANDROID)
-- ============================================================
local function sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json"
    
    -- Для Android используем HTTP (Firebase поддерживает)
    if isAndroid then
        url = url:gsub("https://", "http://")
    end
    
    sendToGameDebug("Request: " .. method .. " " .. path, {0.5, 0.5, 0.8, 1})
    
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local response_body = {}
    local request_body = body or ""
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#request_body),
    }
    
    local res, code = http.request{
        url = url,
        method = method,
        headers = headers,
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body),
        timeout = 10,
    }
    
    local response = table.concat(response_body)
    code = tonumber(code) or 0
    
    if code >= 200 and code < 300 then
        sendToGameDebug("Success: " .. method .. " " .. path, {0.2, 0.8, 0.2, 1})
        if callback then callback(true, response) end
    else
        sendToGameDebug("Error: " .. method .. " " .. path .. " - " .. tostring(code), {0.9, 0.2, 0.2, 1})
        if callback then callback(false, "HTTP Error: " .. tostring(code)) end
    end
end

-- ============================================================
--  ПАРСИНГ ИГРОКОВ
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
--  СОЗДАНИЕ КОМНАТЫ
-- ============================================================
function online.createRoom(roomCode, nickname, callback)
    if not nickname or nickname == "" then
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

    sendToGameDebug("Creating room: " .. roomCode, {0.3, 0.8, 0.8, 1})
    setDebug("Creating room: " .. roomCode)

    local infoPath = ROOMS_PATH .. roomCode .. "/info"
    local infoData = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'

    sendRequest("PUT", infoPath, infoData, function(ok)
        if not ok then
            sendToGameDebug("Failed to create room", {0.9, 0.2, 0.2, 1})
            setDebug("Failed to create room")
            if callback then callback(false, "Failed to create room") end
            return
        end

        setDebug("Room info created")
        sendToGameDebug("Room info created", {0.2, 0.8, 0.2, 1})

        local playerPath = ROOMS_PATH .. roomCode .. "/players/" .. myUid
        local playerData = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)

        sendRequest("PUT", playerPath, playerData, function(ok2)
            if ok2 then
                isConnected = true
                setDebug("Room created: " .. roomCode)
                sendToGameDebug("Room created: " .. roomCode, {0.2, 0.8, 0.2, 1})
                if callback then callback(true, roomCode) end
            else
                setDebug("Failed to write player")
                sendToGameDebug("Failed to write player", {0.9, 0.2, 0.2, 1})
                if callback then callback(false, "Failed to write player") end
            end
        end)
    end)
end

-- ============================================================
--  ВХОД В КОМНАТУ
-- ============================================================
function online.joinRoom(roomCode, nickname, callback)
    if not nickname or nickname == "" then
        if callback then callback(false, "Nickname required") end
        return
    end
    if not roomCode or roomCode == "" then
        if callback then callback(false, "Room code required") end
        return
    end

    myRoomCode = roomCode
    myUid = generateUuid()
    myNickname = nickname
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    sendToGameDebug("Joining room: " .. roomCode, {0.3, 0.8, 0.8, 1})
    setDebug("Joining room: " .. roomCode)

    sendRequest("GET", ROOMS_PATH .. roomCode .. "/info", nil, function(ok, res)
        if not ok or res == "null" then
            setDebug("Room not found")
            sendToGameDebug("Room not found: " .. roomCode, {0.9, 0.2, 0.2, 1})
            if callback then callback(false, "Room not found") end
            return
        end

        setDebug("Room exists, joining...")
        sendToGameDebug("Room exists, joining...", {0.2, 0.8, 0.2, 1})

        local playerPath = ROOMS_PATH .. roomCode .. "/players/" .. myUid
        local playerData = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)

        sendRequest("PUT", playerPath, playerData, function(ok2)
            if ok2 then
                isConnected = true
                setDebug("Joined room: " .. roomCode)
                sendToGameDebug("Joined room: " .. roomCode, {0.2, 0.8, 0.2, 1})
                if callback then callback(true, roomCode) end
            else
                setDebug("Failed to write player")
                sendToGameDebug("Failed to write player", {0.9, 0.2, 0.2, 1})
                if callback then callback(false, "Failed to write player") end
            end
        end)
    end)
end

-- ============================================================
--  ОТПРАВКА ПОЗИЦИИ
-- ============================================================
function online.sendPosition(x, y)
    if not isConnected or not myUid or not myRoomCode then return end

    local newX = math.floor(x)
    local newY = math.floor(y)
    if lastSentX == newX and lastSentY == newY then return end

    lastSentX = newX
    lastSentY = newY

    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    local data = string.format('{"x":%d,"y":%d,"nickname":"%s","skin":"%s"}', newX, newY, myNickname, mySkin)
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ОТПРАВКА ПУЛИ
-- ============================================================
function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid or not myRoomCode then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/bullets/" .. bulletId
    local data = string.format('{"x":%d,"y":%d,"dx":%f,"dy":%f,"owner":"%s","time":%f}',
        math.floor(x), math.floor(y), dx, dy, myUid, love.timer.getTime())
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ОТПРАВКА СПОСОБНОСТИ
-- ============================================================
function online.sendAbility(abilityType, x, y, dirX, dirY)
    if not isConnected or not myUid or not myRoomCode then return end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/abilities/" .. abilityId
    local data = string.format('{"type":"%s","x":%d,"y":%d,"dirX":%f,"dirY":%f,"owner":"%s","time":%f}',
        abilityType, math.floor(x), math.floor(y), dirX or 0, dirY or 0, myUid, love.timer.getTime())
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ПОСТОЯННАЯ ПРОВЕРКА ИГРОКОВ
-- ============================================================
function online.fetchPlayers()
    if not isConnected or not myRoomCode then
        sendToGameDebug("Cannot fetch: not connected", {0.9, 0.8, 0.2, 1})
        return
    end

    local path = ROOMS_PATH .. myRoomCode .. "/players"
    sendToGameDebug("Fetching players...", {0.5, 0.5, 0.8, 1})

    sendRequest("GET", path, nil, function(ok, res)
        if ok and res and res ~= "null" then
            local newPlayers = parsePlayers(res)

            for id, data in pairs(newPlayers) do
                if id ~= myUid then
                    if not players[id] then
                        players[id] = data
                        sendToGameDebug("New player: " .. data.nickname, {0.2, 0.8, 0.2, 1})
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
                    sendToGameDebug("Player left: " .. players[id].nickname, {0.9, 0.6, 0.2, 1})
                    players[id] = nil
                end
            end

            local count = 0
            local names = {}
            for id, info in pairs(players) do
                count = count + 1
                table.insert(names, info.nickname)
            end
            if count > 0 then
                sendToGameDebug("Players in room: " .. count .. " - " .. table.concat(names, ", "), {0.2, 0.8, 0.2, 1})
            end
        else
            sendToGameDebug("No players in room", {0.9, 0.6, 0.2, 1})
        end
    end)
end

-- ============================================================
--  ПОЛУЧЕНИЕ ВСЕХ ДАННЫХ
-- ============================================================
function online.fetchData()
    if not isConnected or not myRoomCode then return end

    online.fetchPlayers()

    local path = ROOMS_PATH .. myRoomCode

    sendRequest("GET", path .. "/bullets", nil, function(ok, res)
        if ok and res and res ~= "null" then
            local ok2, data = pcall(love.data.decode, "string", "json", res)
            if ok2 and data then
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

    sendRequest("GET", path .. "/abilities", nil, function(ok, res)
        if ok and res and res ~= "null" then
            local ok2, data = pcall(love.data.decode, "string", "json", res)
            if ok2 and data then
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

-- ============================================================
--  ОБНОВЛЕНИЕ
-- ============================================================
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

    for id, b in pairs(bullets) do
        b.x = b.x + b.dx * 390 * dt
        b.y = b.y + b.dy * 390 * dt
        b.life = b.life - dt
        if b.life <= 0 then bullets[id] = nil end
    end

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

    fetchTimer = fetchTimer + dt
    if fetchTimer >= FETCH_INTERVAL then
        fetchTimer = 0
        online.fetchData()
    end
end

-- ============================================================
--  ВЫХОД
-- ============================================================
function online.leave()
    if isConnected and myUid and myRoomCode then
        sendRequest("DELETE", ROOMS_PATH .. myRoomCode .. "/players/" .. myUid)
    end
    isConnected = false
    players = {}
    bullets = {}
    abilities = {}
    myUid = nil
    myNickname = nil
    myRoomCode = nil
    lastSentX = nil
    lastSentY = nil
    sendToGameDebug("Left room", {0.5, 0.5, 0.8, 1})
end

function online.updateSkin(skin)
    mySkin = skin
end

return online

-- online.lua – работа с Firebase Realtime Database
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
local FETCH_INTERVAL = 0.4

local isAndroid = (love.system.getOS() == "Android")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

function online.generateRoomCode()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local code = ""
    for i = 1, 5 do
        code = code .. chars:sub(math.random(1, #chars), math.random(1, #chars))
    end
    return code
end

function online.init()
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    setDebug("Online initialized")
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
--  ОТПРАВКА ЗАПРОСОВ
-- ============================================================
local function sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json"
    
    local cmd = 'curl -s -X ' .. method .. ' "' .. url .. '"'
    if body and body ~= "" then
        local escaped = body:gsub('"', '\\"')
        cmd = cmd .. ' -H "Content-Type: application/json" -d "' .. escaped .. '"'
    end
    cmd = cmd .. ' 2>&1'
    
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    if callback then
        if result and result ~= "" and not result:match("error") and not result:match("curl") then
            callback(true, result)
        else
            callback(false, result or "Error")
        end
    end
end

-- ============================================================
--  ПАРСИНГ JSON
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
    
    setDebug("Creating room: " .. roomCode)
    
    local infoPath = ROOMS_PATH .. roomCode .. "/info"
    local infoData = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'
    
    sendRequest("PUT", infoPath, infoData, function(ok)
        if not ok then
            setDebug("Failed to create room")
            if callback then callback(false, "Failed to create room") end
            return
        end
        
        local playerPath = ROOMS_PATH .. roomCode .. "/players/" .. myUid
        local playerData = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
        
        sendRequest("PUT", playerPath, playerData, function(ok2)
            if ok2 then
                isConnected = true
                setDebug("Room created: " .. roomCode)
                if callback then callback(true, roomCode) end
            else
                setDebug("Failed to write player")
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
    
    setDebug("Joining room: " .. roomCode)
    
    sendRequest("GET", ROOMS_PATH .. roomCode .. "/info", nil, function(ok, res)
        if not ok or res == "null" then
            setDebug("Room not found")
            if callback then callback(false, "Room not found") end
            return
        end
        
        local playerPath = ROOMS_PATH .. roomCode .. "/players/" .. myUid
        local playerData = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
        
        sendRequest("PUT", playerPath, playerData, function(ok2)
            if ok2 then
                isConnected = true
                setDebug("Joined room: " .. roomCode)
                if callback then callback(true, roomCode) end
            else
                setDebug("Failed to write player")
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
--  ПОЛУЧЕНИЕ ДАННЫХ
-- ============================================================
function online.fetchData()
    if not isConnected or not myRoomCode then return end
    
    sendRequest("GET", ROOMS_PATH .. myRoomCode .. "/players", nil, function(ok, res)
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
                if not newPlayers[id] then players[id] = nil end
            end
        end
    end)
    
    sendRequest("GET", ROOMS_PATH .. myRoomCode .. "/bullets", nil, function(ok, res)
        if ok and res and res ~= "null" then
            bullets = parseBullets(res)
            for id, b in pairs(bullets) do
                if b.life <= 0 then bullets[id] = nil end
            end
        end
    end)
    
    sendRequest("GET", ROOMS_PATH .. myRoomCode .. "/abilities", nil, function(ok, res)
        if ok and res and res ~= "null" then
            abilities = parseAbilities(res)
            local currentTime = love.timer.getTime()
            for id, ab in pairs(abilities) do
                if ab.time and currentTime - ab.time > 2 then
                    abilities[id] = nil
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
end

function online.updateSkin(skin)
    mySkin = skin
end

return online

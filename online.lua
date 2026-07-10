-- online.lua – упрощенная работа с Firebase
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
local sendTimer = 0
local fetchTimer = 0
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
    return "p" .. os.time() .. math.random(1000, 9999)
end

function online.generateRoomCode()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
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

-- ============================================================
--  ОТПРАВКА ЗАПРОСОВ
-- ============================================================
function sendRequest(method, path, body, callback)
    if isAndroid then
        -- Для Android
        local url = DB_URL .. path .. ".json"
        local cmd = 'curl -s -X ' .. method .. ' "' .. url .. '"'
        if body and body ~= "" then
            cmd = cmd .. ' -H "Content-Type: application/json" -d \'' .. body .. '\''
        end
        cmd = cmd .. ' 2>&1'
        
        local handle = io.popen(cmd)
        local result = handle:read("*a")
        handle:close()
        
        if result and result ~= "" then
            if callback then callback(true, result) end
        else
            if callback then callback(false, "Error") end
        end
    else
        -- Для PC
        local url = DB_URL .. path .. ".json"
        local cmd = 'curl -s -X ' .. method .. ' "' .. url .. '"'
        if body and body ~= "" then
            cmd = cmd .. ' -H "Content-Type: application/json" -d \'' .. body .. '\''
        end
        cmd = cmd .. ' 2>&1'
        
        local handle = io.popen(cmd)
        local result = handle:read("*a")
        handle:close()
        
        if result and result ~= "" and not result:match("error") then
            if callback then callback(true, result) end
        else
            if callback then callback(false, result or "Error") end
        end
    end
end

-- ============================================================
--  ЗАПИСЬ ИГРОКА
-- ============================================================
function online.writePlayer(callback)
    if not myRoomCode or not myUid then
        if callback then callback(false) end
        return
    end
    
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    local data = '{"x":400,"y":300,"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
    setDebug("Writing player: " .. path)
    
    sendRequest("PUT", path, data, function(success, response)
        if success then
            setDebug("Player written: " .. myUid)
            isConnected = true
        else
            setDebug("Failed to write: " .. tostring(response))
        end
        if callback then callback(success) end
    end)
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
    
    setDebug("Creating room: " .. roomCode .. " with UID: " .. myUid)
    
    -- Создаем комнату
    local path = ROOMS_PATH .. roomCode .. "/info"
    local data = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'
    
    sendRequest("PUT", path, data, function(success, response)
        if not success then
            setDebug("Failed to create room")
            if callback then callback(false, "Failed to create room") end
            return
        end
        
        -- Записываем игрока
        online.writePlayer(function(success2)
            if success2 then
                setDebug("Room created successfully: " .. roomCode)
                if callback then callback(true, roomCode) end
            else
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
    
    setDebug("Joining room: " .. roomCode .. " with UID: " .. myUid)
    
    -- Проверяем существование комнаты
    local path = ROOMS_PATH .. roomCode .. "/info"
    sendRequest("GET", path, nil, function(success, response)
        if not success or response == "null" then
            setDebug("Room does not exist")
            if callback then callback(false, "Room not found") end
            return
        end
        
        -- Записываем игрока
        online.writePlayer(function(success2)
            if success2 then
                setDebug("Joined room successfully: " .. roomCode)
                if callback then callback(true, roomCode) end
            else
                if callback then callback(false, "Failed to write player") end
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
--  ПОЛУЧЕНИЕ ИГРОКОВ
-- ============================================================
function online.fetchPlayers()
    if not isConnected or not myRoomCode then
        return
    end
    
    local path = ROOMS_PATH .. myRoomCode .. "/players"
    
    sendRequest("GET", path, nil, function(success, response)
        if success and response and response ~= "null" then
            -- Парсим JSON
            local ok, data = pcall(love.data.decode, "string", "json", response)
            if ok and data then
                players = {}
                local count = 0
                local names = {}
                
                for uid, info in pairs(data) do
                    if type(info) == "table" then
                        players[uid] = {
                            x = info.x or 0,
                            y = info.y or 0,
                            nickname = info.nickname or "???",
                            skin = info.skin or "NONE",
                            targetX = info.x or 0,
                            targetY = info.y or 0,
                            lerpTimer = 0
                        }
                        count = count + 1
                        if uid == myUid then
                            table.insert(names, info.nickname .. " (me)")
                        else
                            table.insert(names, info.nickname)
                        end
                    end
                end
                
                setDebug("Players (" .. count .. "): " .. table.concat(names, ", "))
            end
        else
            setDebug("No players in room")
        end
    end)
end

-- ============================================================
--  ОСТАЛЬНЫЕ ФУНКЦИИ
-- ============================================================
function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid or not myRoomCode then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/bullets/" .. bulletId
    local data = '{"x":' .. x .. ',"y":' .. y .. ',"dx":' .. dx .. ',"dy":' .. dy .. ',"owner":"' .. myUid .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data)
end

function online.sendAbility(abilityType, x, y, dirX, dirY, targetUid)
    if not isConnected or not myUid or not myRoomCode then return end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/abilities/" .. abilityId
    local data = '{"type":"' .. abilityType .. '","x":' .. x .. ',"y":' .. y .. ',"dirX":' .. (dirX or 0) .. ',"dirY":' .. (dirY or 0) .. ',"owner":"' .. myUid .. '","target":"' .. (targetUid or "") .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data)
end

function online.fetchData()
    if not isConnected or not myRoomCode then return end
    online.fetchPlayers()
    
    local path = ROOMS_PATH .. myRoomCode
    
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
    if not isConnected or not myUid or not myRoomCode then return end
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

    -- Плавное движение
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
    if sendTimer >= 0.5 then
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
    if fetchTimer >= 0.5 then
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

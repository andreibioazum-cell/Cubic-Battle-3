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
local sendTimer = 0
local fetchTimer = 0
local isConnected = false
local debugText = "Waiting..."
local lastSentX = nil
local lastSentY = nil
local positionSendTimer = 0
local POSITION_INTERVAL = 0.3
local FETCH_INTERVAL = 0.5

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
--  ПРАВИЛЬНАЯ ОТПРАВКА ЗАПРОСОВ
-- ============================================================
function sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json"
    
    -- Экранируем кавычки для JSON
    local escapedBody = ""
    if body and body ~= "" then
        -- Заменяем " на \" для curl
        escapedBody = body:gsub('"', '\\"')
    end
    
    local cmd
    if isAndroid then
        cmd = 'curl -s -X ' .. method .. ' "' .. url .. '"'
        if escapedBody ~= "" then
            cmd = cmd .. ' -H "Content-Type: application/json" -d "' .. escapedBody .. '"'
        end
    else
        cmd = 'curl -s -X ' .. method .. ' "' .. url .. '"'
        if escapedBody ~= "" then
            cmd = cmd .. ' -H "Content-Type: application/json" -d "' .. escapedBody .. '"'
        end
    end
    cmd = cmd .. ' 2>&1'
    
    print("[CURL] " .. cmd)
    
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    print("[RESPONSE] " .. tostring(result))
    
    if result and result ~= "" and not result:match("error") and not result:match("curl") then
        if callback then callback(true, result) end
    else
        if callback then callback(false, result or "Error") end
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
    -- ПРАВИЛЬНЫЙ JSON без лишних кавычек
    local data = '{"x":400,"y":300,"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
    setDebug("Writing player to: " .. path)
    
    sendRequest("PUT", path, data, function(success, response)
        if success then
            setDebug("Player written successfully")
            isConnected = true
        else
            setDebug("Failed to write player: " .. tostring(response))
        end
        if callback then callback(success) end
    end)
end

-- ============================================================
--  СОЗДАНИЕ КОМНАТЫ
-- ============================================================
function online.createRoom(roomCode, nickname, callback)
    setDebug("=== CREATE ROOM ===")
    
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
    
    setDebug("Room: " .. roomCode .. ", UID: " .. myUid)
    
    -- Создаем info
    local path = ROOMS_PATH .. roomCode .. "/info"
    local data = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'
    
    sendRequest("PUT", path, data, function(success, response)
        if not success then
            setDebug("FAILED to create room: " .. tostring(response))
            if callback then callback(false, "Failed to create room: " .. tostring(response)) end
            return
        end
        
        setDebug("Room info created: " .. roomCode)
        
        -- Записываем игрока
        online.writePlayer(function(success2)
            if success2 then
                setDebug("=== ROOM CREATED SUCCESSFULLY ===")
                if callback then callback(true, roomCode) end
            else
                setDebug("FAILED to write player")
                if callback then callback(false, "Failed to write player") end
            end
        end)
    end)
end

-- ============================================================
--  ВХОД В КОМНАТУ
-- ============================================================
function online.joinRoom(roomCode, nickname, callback)
    setDebug("=== JOIN ROOM ===")
    
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
    
    setDebug("Room: " .. roomCode .. ", UID: " .. myUid)
    
    -- Проверяем существование комнаты
    local path = ROOMS_PATH .. roomCode .. "/info"
    sendRequest("GET", path, nil, function(success, response)
        if not success or response == "null" or response == "" then
            setDebug("Room does not exist")
            if callback then callback(false, "Room not found") end
            return
        end
        
        setDebug("Room exists, joining...")
        
        online.writePlayer(function(success2)
            if success2 then
                setDebug("=== JOINED ROOM SUCCESSFULLY ===")
                if callback then callback(true, roomCode) end
            else
                setDebug("FAILED to write player")
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
    
    sendRequest("PUT", path, data, function() end)
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
        if success and response and response ~= "null" and response ~= "" then
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
                
                if count > 0 then
                    setDebug("Players (" .. count .. "): " .. table.concat(names, ", "))
                end
            end
        end
    end)
end

function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid or not myRoomCode then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/bullets/" .. bulletId
    local data = '{"x":' .. x .. ',"y":' .. y .. ',"dx":' .. dx .. ',"dy":' .. dy .. ',"owner":"' .. myUid .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data, function() end)
end

function online.sendAbility(abilityType, x, y, dirX, dirY, targetUid)
    if not isConnected or not myUid or not myRoomCode then return end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/abilities/" .. abilityId
    local data = '{"type":"' .. abilityType .. '","x":' .. x .. ',"y":' .. y .. ',"dirX":' .. (dirX or 0) .. ',"dirY":' .. (dirY or 0) .. ',"owner":"' .. myUid .. '","target":"' .. (targetUid or "") .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data, function() end)
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
    sendRequest("PUT", path, data, function() end)
end

function online.getMySkin()
    return mySkin
end

function online.leave()
    if not isConnected or not myUid or not myRoomCode then return end
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    sendRequest("DELETE", path, nil, function() end)
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

    for uid, p in pairs(players) do
        if p.targetX and p.targetY then
            p.lerpTimer = math.min(1, (p.lerpTimer or 0) + dt * 4.5)
            local t = p.lerpTimer
            local smooth = t * t * (3 - 2 * t)
            p.x = p.x + (p.targetX - p.x) * smooth
            p.y = p.y + (p.targetY - p.y) * smooth
        end
    end

    positionSendTimer = positionSendTimer + dt
    if positionSendTimer >= POSITION_INTERVAL then
        positionSendTimer = 0
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

function online.getDebugText()
    return debugText
end

function online.isConnected()
    return isConnected
end

return online

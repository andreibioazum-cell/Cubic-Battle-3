-- online.lua – с оптимизацией и пулями
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
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2          -- отправка позиции раз в 0.2 сек
local FETCH_INTERVAL = 0.3          -- получение игроков раз в 0.3 сек
local isConnected = false
local debugText = "Waiting..."
local lastSentX = nil
local lastSentY = nil

local https = require("https")

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
    setDebug("Online ready")
end

-- ============================================================
--  КОМНАТЫ
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
    local roomUrl = DB_URL .. ROOMS_PATH .. roomCode .. "/info.json"
    local roomData = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'
    local roomOptions = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = roomData,
        timeout = 3,
        verify = false,
    }
    local success, code, body = pcall(https.request, roomUrl, roomOptions)
    if not (success and code and code >= 200 and code < 300) then
        setDebug("Failed to create room: " .. tostring(code))
        if callback then callback(false, tostring(code)) end
        return
    end

    -- Добавляем игрока
    local playerUrl = DB_URL .. ROOMS_PATH .. roomCode .. "/players/" .. myUid .. ".json"
    local playerData = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    local playerOptions = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = playerData,
        timeout = 3,
        verify = false,
    }
    local success2, code2, body2 = pcall(https.request, playerUrl, playerOptions)
    if success2 and code2 and code2 >= 200 and code2 < 300 then
        isConnected = true
        setDebug("Room created: " .. roomCode)
        if callback then callback(true) end
    else
        setDebug("Failed to add player: " .. tostring(code2))
        if callback then callback(false, tostring(code2)) end
    end
end

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

    -- Проверяем комнату
    local checkUrl = DB_URL .. ROOMS_PATH .. roomCode .. "/info.json"
    local checkOptions = {
        method = "GET",
        timeout = 3,
        verify = false,
    }
    local success, code, body = pcall(https.request, checkUrl, checkOptions)
    if not (success and code and code == 200) then
        setDebug("Room does not exist")
        if callback then callback(false, "Room not found") end
        return
    end

    -- Добавляем игрока
    local playerUrl = DB_URL .. ROOMS_PATH .. roomCode .. "/players/" .. myUid .. ".json"
    local playerData = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    local playerOptions = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = playerData,
        timeout = 3,
        verify = false,
    }
    local success2, code2, body2 = pcall(https.request, playerUrl, playerOptions)
    if success2 and code2 and code2 >= 200 and code2 < 300 then
        isConnected = true
        setDebug("Joined room: " .. roomCode)
        if callback then callback(true) end
    else
        setDebug("Failed to join: " .. tostring(code2))
        if callback then callback(false, tostring(code2)) end
    end
end

-- ============================================================
--  ОТПРАВКА ПОЗИЦИИ (только если изменилась)
-- ============================================================
function online.sendPosition(x, y)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    
    -- Отправляем только если позиция изменилась (экономия трафика)
    local newX = math.floor(x)
    local newY = math.floor(y)
    if lastSentX == newX and lastSentY == newY then
        return
    end
    
    lastSentX = newX
    lastSentY = newY
    
    local url = DB_URL .. ROOMS_PATH .. myRoomCode .. "/players/" .. myUid .. ".json"
    local data = '{"x":' .. newX .. ',"y":' .. newY .. ',"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
    local options = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = data,
        timeout = 3,
        verify = false,
    }
    pcall(https.request, url, options)
end

-- ============================================================
--  ОТПРАВКА ПУЛИ
-- ============================================================
function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local url = DB_URL .. ROOMS_PATH .. myRoomCode .. "/bullets/" .. bulletId .. ".json"
    local data = '{"x":' .. x .. ',"y":' .. y .. ',"dx":' .. dx .. ',"dy":' .. dy .. ',"owner":"' .. myUid .. '","time":' .. love.timer.getTime() .. '}'
    local options = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = data,
        timeout = 2,
        verify = false,
    }
    pcall(https.request, url, options)
end

-- ============================================================
--  ПОЛУЧЕНИЕ ИГРОКОВ И ПУЛЬ
-- ============================================================
function online.fetchData()
    if not isConnected or not myRoomCode then
        return
    end
    
    -- Получаем игроков
    local url = DB_URL .. ROOMS_PATH .. myRoomCode .. "/players.json"
    local options = {
        method = "GET",
        timeout = 3,
        verify = false,
    }
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        local ok, data = pcall(love.data.decode, "string", "json", body)
        if ok and data then
            local newPlayers = {}
            for uid, info in pairs(data) do
                if uid ~= myUid and info.x and info.y then
                    newPlayers[uid] = {
                        x = info.x,
                        y = info.y,
                        nickname = info.nickname or "???",
                        skin = info.skin or "NONE",
                        targetX = info.x,
                        targetY = info.y,
                        lerpTimer = 0
                    }
                end
            end
            players = newPlayers
        end
    end
    
    -- Получаем пули
    local bulletUrl = DB_URL .. ROOMS_PATH .. myRoomCode .. "/bullets.json"
    local bulletOptions = {
        method = "GET",
        timeout = 2,
        verify = false,
    }
    local bSuccess, bCode, bBody = pcall(https.request, bulletUrl, bulletOptions)
    if bSuccess and bCode and bCode >= 200 and bCode < 300 then
        local ok, data = pcall(love.data.decode, "string", "json", bBody)
        if ok and data then
            bullets = {}
            for bid, info in pairs(data) do
                if info.owner ~= myUid then
                    bullets[bid] = {
                        x = info.x,
                        y = info.y,
                        dx = info.dx,
                        dy = info.dy,
                        owner = info.owner,
                        time = info.time or 0,
                    }
                end
            end
        end
    end
end

function online.getPlayers()
    return players
end

function online.getBullets()
    return bullets
end

function online.updateSkin(skin)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    mySkin = skin
    local url = DB_URL .. ROOMS_PATH .. myRoomCode .. "/players/" .. myUid .. "/skin.json"
    local data = '"' .. skin .. '"'
    local options = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = data,
        timeout = 3,
        verify = false,
    }
    pcall(https.request, url, options)
end

function online.getMySkin()
    return mySkin
end

function online.leave()
    if not isConnected or not myUid or not myRoomCode then return end
    local url = DB_URL .. ROOMS_PATH .. myRoomCode .. "/players/" .. myUid .. ".json"
    local options = {
        method = "DELETE",
        timeout = 3,
        verify = false,
    }
    pcall(https.request, url, options)
    isConnected = false
    players = {}
    bullets = {}
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

    -- Интерполяция игроков
    local lerpSpeed = 4.5
    for uid, p in pairs(players) do
        if p.targetX and p.targetY then
            p.lerpTimer = math.min(1, (p.lerpTimer or 0) + dt * lerpSpeed)
            local t = p.lerpTimer
            local smooth = t * t * (3 - 2 * t)
            p.x = p.x + (p.targetX - p.x) * smooth
            p.y = p.y + (p.targetY - p.y) * smooth
        end
    end

    -- Отправка позиции (только если изменилась)
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

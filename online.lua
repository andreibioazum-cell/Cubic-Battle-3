-- online.lua – полный онлайн через JNI (Java вызывается из Lua)
local online = {}

local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com"
local PATH = "players/"

local myUid = nil
local myNickname = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false
local debugText = "Waiting..."

-- ============================================================
--  JNI (вызов Java из Lua)
-- ============================================================
local ffi = require("ffi")

-- Объявляем функцию из JNI-моста
ffi.cdef[[
    const char* Java_com_CB3_FirebaseBridge_sendRequest(const char* method, const char* path, const char* body);
]]

-- Вспомогательная функция для вызова Java
local function callJava(method, path, body)
    local result = ffi.C.Java_com_CB3_FirebaseBridge_sendRequest(method, path, body or "")
    return ffi.string(result)  -- преобразуем C-string в Lua string
end

-- ============================================================
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

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

-- ============================================================
--  ОСНОВНЫЕ ФУНКЦИИ
-- ============================================================

function online.init()
    setDebug("Online module ready (JNI)")
end

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

    local path = PATH .. myUid
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '"}'
    
    local response = callJava("PUT", path, data)
    if response and response:match("error") then
        setDebug("Failed to create room: " .. response)
        if callback then callback(false, response) end
    else
        isConnected = true
        setDebug("Room created: " .. roomCode)
        if callback then callback(true) end
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

    local path = PATH .. myUid
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '"}'
    
    local response = callJava("PUT", path, data)
    if response and response:match("error") then
        setDebug("Failed to join room: " .. response)
        if callback then callback(false, response) end
    else
        isConnected = true
        setDebug("Joined room: " .. roomCode)
        if callback then callback(true) end
    end
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("Not connected or no UID")
        return
    end
    local path = PATH .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. ',"nickname":"' .. myNickname .. '"}'
    local response = callJava("PUT", path, data)
    if response and response:match("error") then
        setDebug("Failed to send position: " .. response)
    else
        setDebug("Sent: " .. math.floor(x) .. "," .. math.floor(y))
    end
end

function online.fetchPlayers()
    if not isConnected then
        setDebug("Not connected")
        return
    end
    local response = callJava("GET", PATH, nil)
    if response and response:match("error") then
        setDebug("Failed to fetch players: " .. response)
        return
    end
    -- Парсим ответ от Java (JSON)
    local ok, data = pcall(love.data.decode, "string", "json", response)
    if ok and data then
        local newPlayers = {}
        for uid, info in pairs(data) do
            if uid ~= myUid and info.x and info.y then
                newPlayers[uid] = { x = info.x, y = info.y, nickname = info.nickname or "???" }
            end
        end
        players = newPlayers
        local count = 0
        for _ in pairs(players) do count = count + 1 end
        setDebug("Players loaded: " .. count)
    else
        setDebug("Invalid JSON response: " .. tostring(response))
    end
end

function online.getPlayers()
    return players
end

function online.leave()
    if not isConnected or not myUid then return end
    local path = PATH .. myUid
    local response = callJava("DELETE", path, nil)
    if response and response:match("error") then
        setDebug("Failed to leave: " .. response)
    else
        setDebug("Left room")
    end
    isConnected = false
    players = {}
    myUid = nil
    myNickname = nil
    myRoomCode = nil
end

function online.update(dt)
    if not isConnected then
        return
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
        online.fetchPlayers()
    end
end

function online.getDebugText()
    return debugText
end

function online.isConnected()
    return isConnected
end

return online

-- online.lua – синхронизация через Firebase с поддержкой комнат
local online = {}

local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com"
local ROOMS_PATH = "rooms/"

local myUid = nil
local myNickname = nil
local myRoomCode = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false
local debugText = "Waiting..."

local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

local function firebaseRequest(method, path, data, callback)
    local https = require("https")
    local url = DB_URL .. "/" .. path .. ".json"
    local options = {
        method = method,
        headers = { ["Content-Type"] = "application/json" },
        timeout = 5,
        verify = false,
    }
    if data then
        options.data = data
    end

    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        if callback then callback(true, body) end
    else
        if callback then callback(false, "Error: " .. tostring(code) .. " " .. tostring(body)) end
    end
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

function online.init()
    -- пустая функция для обратной совместимости
    setDebug("Online module initialized")
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

function online.roomExists(roomCode, callback)
    firebaseRequest("GET", ROOMS_PATH .. roomCode .. "/info", nil, function(success, body)
        if success and body and body ~= "null" then
            callback(true)
        else
            callback(false)
        end
    end)
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

    local path = ROOMS_PATH .. roomCode .. "/info"
    local infoData = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'
    firebaseRequest("PUT", path, infoData, function(success)
        if not success then
            setDebug("Failed to create room")
            if callback then callback(false, "Failed to create room") end
            return
        end
        online.joinRoom(roomCode, nickname, callback)
    end)
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

    online.roomExists(roomCode, function(exists)
        if not exists then
            setDebug("Room does not exist")
            if callback then callback(false, "Room not found") end
            return
        end

        myRoomCode = roomCode
        myUid = generateUuid()
        myNickname = nickname

        local path = ROOMS_PATH .. roomCode .. "/players/" .. myUid
        local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '"}'
        firebaseRequest("PUT", path, data, function(success)
            if success then
                isConnected = true
                setDebug("Joined room " .. roomCode .. " as " .. nickname)
                if callback then callback(true) end
            else
                setDebug("Failed to join room")
                if callback then callback(false, "Failed to join room") end
            end
        end)
    end)
end

function online.sendPosition(x, y)
    if not isConnected or not myUid or not myRoomCode then
        setDebug("Not connected or no room")
        return
    end
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. ',"nickname":"' .. myNickname .. '"}'
    firebaseRequest("PUT", path, data, function(success, body)
        if not success then
            setDebug("PUT failed: " .. (body or "unknown"))
        else
            setDebug("Sent: " .. math.floor(x) .. "," .. math.floor(y))
        end
    end)
end

function online.fetchPlayers()
    if not isConnected or not myRoomCode then
        setDebug("Not connected or no room")
        return
    end
    local path = ROOMS_PATH .. myRoomCode .. "/players/"
    firebaseRequest("GET", path, nil, function(success, body)
        if success then
            if not body or body == "" or body == "null" then
                players = {}
                setDebug("No players in room")
                return
            end
            local ok, data = pcall(love.data.decode, "string", "json", body)
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
                setDebug("Players in room: " .. count)
            else
                setDebug("Invalid JSON, skipping")
                print("[ERROR] Invalid JSON from Firebase:", body)
            end
        else
            setDebug("GET failed: " .. (body or "unknown"))
        end
    end)
end

function online.getPlayers()
    return players
end

function online.leave()
    if not isConnected or not myUid or not myRoomCode then return end
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    firebaseRequest("DELETE", path, nil, function()
        setDebug("Left room")
    end)
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

return online

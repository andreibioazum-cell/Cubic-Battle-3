-- online.lua – отправка команд в Java-мост (REST API)
local online = {}

local myUid = nil
local myNickname = nil
local myRoomCode = nil
local players = {}
local isConnected = false
local debugText = "Waiting..."

local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

function online.init()
    setDebug("Online module ready")
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
    myUid = os.time() .. math.random(1000, 9999)
    myNickname = nickname

    print("PUT rooms/" .. roomCode .. "/info {\"owner\":\"" .. myUid .. "\"}")
    print("PUT rooms/" .. roomCode .. "/players/" .. myUid .. " {\"x\":0,\"y\":0,\"nickname\":\"" .. nickname .. "\"}")
    isConnected = true
    setDebug("Room created: " .. roomCode)
    if callback then callback(true) end
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
    myUid = os.time() .. math.random(1000, 9999)
    myNickname = nickname

    print("PUT rooms/" .. roomCode .. "/players/" .. myUid .. " {\"x\":0,\"y\":0,\"nickname\":\"" .. nickname .. "\"}")
    isConnected = true
    setDebug("Joined room " .. roomCode)
    if callback then callback(true) end
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then return end
    print("PUT rooms/" .. myRoomCode .. "/players/" .. myUid .. " {\"x\":" .. math.floor(x) .. ",\"y\":" .. math.floor(y) .. ",\"nickname\":\"" .. myNickname .. "\"}")
end

function online.getPlayers()
    return players
end

function online.leave()
    if not isConnected or not myUid then return end
    print("DELETE rooms/" .. myRoomCode .. "/players/" .. myUid)
    isConnected = false
    players = {}
    myUid = nil
    myNickname = nil
    myRoomCode = nil
end

function online.update(dt)
    -- Java обрабатывает всё автоматически
end

function online.getDebugText()
    return debugText
end

function online.isConnected()
    return isConnected
end

return online

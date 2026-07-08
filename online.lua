-- online.lua – вызывает Java через JNI
local online = {}

local PATH = "players/"

local myUid = nil
local myNickname = nil
local myRoomCode = nil
local mySkin = "NONE"
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.15
local FETCH_INTERVAL = 0.2
local isConnected = false
local debugText = "Waiting..."

local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

-- ============================================================
--  JNI (вызов Java из Lua)
-- ============================================================
local ffi = require("ffi")
ffi.cdef[[
    const char* Java_com_CB3_FirebaseBridge_sendRequest(const char* method, const char* path, const char* body);
]]

local function callJava(method, path, body)
    local result = ffi.C.Java_com_CB3_FirebaseBridge_sendRequest(method, path, body or "")
    return ffi.string(result)
end

-- ============================================================
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================

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
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    setDebug("Online module ready, skin: " .. mySkin)
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
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    local path = PATH .. myUid
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    local response = callJava("PUT", path, data)
    if response and response:match("error") then
        setDebug("Failed to create room: " .. response)
        if callback then callback(false, response) end
    else
        isConnected = true
        setDebug("Room created: " .. roomCode .. " with skin " .. mySkin)
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
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    local path = PATH .. myUid
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    local response = callJava("PUT", path, data)
    if response and response:match("error") then
        setDebug("Failed to join room: " .. response)
        if callback then callback(false, response) end
    else
        isConnected = true
        setDebug("Joined room: " .. roomCode .. " with skin " .. mySkin)
        if callback then callback(true) end
    end
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("Not connected or no UID")
        return
    end
    local path = PATH .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. ',"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
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
    local ok, data = pcall(love.data.decode, "string", "json", response)
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

function online.updateSkin(skin)
    if not isConnected or not myUid then
        setDebug("Not connected, skin not saved")
        return
    end
    mySkin = skin
    local path = PATH .. myUid .. "/skin"
    local data = '"' .. skin .. '"'
    local response = callJava("PUT", path, data)
    if response and response:match("error") then
        setDebug("Failed to update skin: " .. response)
    else
        setDebug("Skin updated: " .. skin)
    end
end

function online.getMySkin()
    return mySkin
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

    -- Интерполяция
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

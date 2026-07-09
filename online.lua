-- online.lua – работает на ПК (socket.http) и Android (JNI)
local online = {}

local PATH = "players/"
local DB_URL = "http://cubic-battle-3-default-rtdb.firebaseio.com/"

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

-- Определяем платформу
local isAndroid = (love.system.getOS() == "Android")
local ffi = nil

if isAndroid then
    local ok, result = pcall(require, "ffi")
    if ok then
        ffi = result
        ffi.cdef([[
            const char* Java_com_CB3_FirebaseBridge_sendRequest(const char* method, const char* path, const char* body);
        ]])
    end
end

-- ============================================================
--  ОТПРАВКА ЗАПРОСОВ (JNI на Android, HTTP на ПК)
-- ============================================================
local function sendRequest(method, path, body)
    -- Android: используем JNI
    if isAndroid and ffi then
        local result = ffi.C.Java_com_CB3_FirebaseBridge_sendRequest(method, path, body or "")
        return ffi.string(result)
    end
    
    -- ПК: используем socket.http (есть везде)
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local url = DB_URL .. path .. ".json"
    
    local response_table = {}
    local res, code, headers = http.request{
        url = url,
        method = method,
        headers = {
            ["Content-Type"] = "application/json",
            ["Host"] = "cubic-battle-3-default-rtdb.firebaseio.com",
        },
        source = body and ltn12.source.string(body) or nil,
        sink = ltn12.sink.table(response_table),
        timeout = 10,
    }
    
    local codeNum = tonumber(code)
    if codeNum and codeNum >= 200 and codeNum < 300 then
        return table.concat(response_table)
    else
        return "{\"error\":\"HTTP " .. tostring(code) .. "\"}"
    end
end

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
    setDebug("Online ready, platform: " .. (isAndroid and "Android (JNI)" or "PC (HTTP)"))
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
    local response = sendRequest("PUT", path, data)
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
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    local path = PATH .. myUid
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    local response = sendRequest("PUT", path, data)
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
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. ',"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
    local response = sendRequest("PUT", path, data)
    if response and response:match("error") then
        setDebug("Failed to send: " .. response)
    else
        setDebug("Sent: " .. math.floor(x) .. "," .. math.floor(y))
    end
end

function online.fetchPlayers()
    if not isConnected then
        setDebug("Not connected")
        return
    end
    local response = sendRequest("GET", PATH, nil)
    if response and response:match("error") then
        setDebug("Failed to fetch: " .. response)
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
        setDebug("Players: " .. count)
    else
        setDebug("Invalid JSON")
    end
end

function online.getPlayers()
    return players
end

function online.updateSkin(skin)
    if not isConnected or not myUid then
        setDebug("Not connected")
        return
    end
    mySkin = skin
    local path = PATH .. myUid .. "/skin"
    local data = '"' .. skin .. '"'
    local response = sendRequest("PUT", path, data)
    if response and response:match("error") then
        setDebug("Skin update failed: " .. response)
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
    local response = sendRequest("DELETE", path, nil)
    if response and response:match("error") then
        setDebug("Leave failed: " .. response)
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

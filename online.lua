-- online.lua – полный онлайн (ПК + Android)
local online = {}

local PATH = "players/"
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"

local myUid = nil
local myNickname = nil
local myRoomCode = nil
local mySkin = "NONE"
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false
local debugText = "Waiting..."

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

    local url = DB_URL .. PATH .. myUid .. ".json"
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    local options = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = data,
        timeout = 5,
        verify = false,
    }
    
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        isConnected = true
        setDebug("Room created: " .. roomCode)
        if callback then callback(true) end
    else
        setDebug("Failed to create room: " .. tostring(code) .. " " .. tostring(body))
        if callback then callback(false, tostring(code)) end
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

    local url = DB_URL .. PATH .. myUid .. ".json"
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    local options = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = data,
        timeout = 5,
        verify = false,
    }
    
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        isConnected = true
        setDebug("Joined room: " .. roomCode)
        if callback then callback(true) end
    else
        setDebug("Failed to join room: " .. tostring(code) .. " " .. tostring(body))
        if callback then callback(false, tostring(code)) end
    end
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("Not connected or no UID")
        return
    end
    local url = DB_URL .. PATH .. myUid .. ".json"
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. ',"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
    local options = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = data,
        timeout = 5,
        verify = false,
    }
    
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        setDebug("Sent: " .. math.floor(x) .. "," .. math.floor(y))
    else
        setDebug("Failed to send: " .. tostring(code) .. " " .. tostring(body))
    end
end

function online.fetchPlayers()
    if not isConnected then
        setDebug("Not connected")
        return
    end
    local url = DB_URL .. PATH .. ".json"
    local options = {
        method = "GET",
        timeout = 5,
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
            local count = 0
            for _ in pairs(players) do count = count + 1 end
            setDebug("Players: " .. count)
        else
            setDebug("Invalid JSON")
        end
    else
        setDebug("Failed to fetch: " .. tostring(code) .. " " .. tostring(body))
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
    local url = DB_URL .. PATH .. myUid .. "/skin.json"
    local data = '"' .. skin .. '"'
    local options = {
        method = "PUT",
        headers = { ["Content-Type"] = "application/json" },
        data = data,
        timeout = 5,
        verify = false,
    }
    
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        setDebug("Skin updated: " .. skin)
    else
        setDebug("Skin update failed: " .. tostring(code) .. " " .. tostring(body))
    end
end

function online.getMySkin()
    return mySkin
end

function online.leave()
    if not isConnected or not myUid then return end
    local url = DB_URL .. PATH .. myUid .. ".json"
    local options = {
        method = "DELETE",
        timeout = 5,
        verify = false,
    }
    
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        setDebug("Left room")
    else
        setDebug("Leave failed: " .. tostring(code) .. " " .. tostring(body))
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

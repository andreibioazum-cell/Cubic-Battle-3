-- online.lua – финальная версия (ПК: socket.http, Android: https)
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
local retryCount = 0
local maxRetries = 3

local isAndroid = (love.system.getOS() == "Android")

-- ============================================================
--  ОТПРАВКА ЗАПРОСОВ (Адаптивно)
-- ============================================================
local function sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json"
    local request_body = body or ""
    
    -- На Android используем встроенный https
    if isAndroid then
        local https = require("https")
        local options = {
            method = method,
            headers = { ["Content-Type"] = "application/json" },
            data = request_body,
            timeout = 5,
            verify = false,
        }
        local success, code, response = pcall(https.request, url, options)
        if success and code and code >= 200 and code < 300 then
            if callback then callback(true, response) end
            return response
        else
            if callback then callback(false, "HTTPS " .. tostring(code)) end
            return nil
        end
    end
    
    -- На ПК используем socket.http (с fallback на HTTP)
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    
    -- Сначала пробуем HTTPS
    local response_table = {}
    local res, code, headers = http.request{
        url = url,
        method = method,
        headers = {
            ["Content-Type"] = "application/json",
        },
        source = body and ltn12.source.string(body) or nil,
        sink = ltn12.sink.table(response_table),
        timeout = 5,
    }
    
    local codeNum = tonumber(code)
    if codeNum and codeNum >= 200 and codeNum < 300 then
        local result = table.concat(response_table)
        if callback then callback(true, result) end
        return result
    else
        -- Пробуем HTTP (без SSL)
        local httpUrl = "http://cubic-battle-3-default-rtdb.firebaseio.com/" .. path .. ".json"
        local response_table2 = {}
        local res2, code2, headers2 = http.request{
            url = httpUrl,
            method = method,
            headers = {
                ["Content-Type"] = "application/json",
            },
            source = body and ltn12.source.string(body) or nil,
            sink = ltn12.sink.table(response_table2),
            timeout = 5,
        }
        local codeNum2 = tonumber(code2)
        if codeNum2 and codeNum2 >= 200 and codeNum2 < 300 then
            local result = table.concat(response_table2)
            if callback then callback(true, result) end
            return result
        else
            local err = "{\"error\":\"HTTP " .. tostring(code) .. " / " .. tostring(code2) .. "\"}"
            if callback then callback(false, err) end
            return err
        end
    end
end

-- ============================================================
--  ОТПРАВКА С ПОВТОРОМ
-- ============================================================
local function sendRequestWithRetry(method, path, body, callback, attempt)
    attempt = attempt or 0
    sendRequest(method, path, body, function(success, data)
        if success then
            if callback then callback(true, data) end
        else
            if attempt < maxRetries then
                setDebug("Retry " .. (attempt + 1) .. "/" .. maxRetries)
                love.timer.sleep(0.5)
                sendRequestWithRetry(method, path, body, callback, attempt + 1)
            else
                if callback then callback(false, data) end
            end
        end
    end)
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
    setDebug("Online ready, platform: " .. (isAndroid and "Android (https)" or "PC (socket.http)"))
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
    sendRequestWithRetry("PUT", path, data, function(success, response)
        if success then
            isConnected = true
            setDebug("Room created: " .. roomCode)
            if callback then callback(true) end
        else
            setDebug("Failed: " .. response)
            if callback then callback(false, response) end
        end
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

    myRoomCode = roomCode
    myUid = generateUuid()
    myNickname = nickname
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    local path = PATH .. myUid
    local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
    sendRequestWithRetry("PUT", path, data, function(success, response)
        if success then
            isConnected = true
            setDebug("Joined room: " .. roomCode)
            if callback then callback(true) end
        else
            setDebug("Failed: " .. response)
            if callback then callback(false, response) end
        end
    end)
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("Not connected or no UID")
        return
    end
    local path = PATH .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. ',"nickname":"' .. myNickname .. '","skin":"' .. mySkin .. '"}'
    sendRequestWithRetry("PUT", path, data, function(success, response)
        if success then
            setDebug("Sent: " .. math.floor(x) .. "," .. math.floor(y))
        else
            setDebug("Send failed: " .. response)
        end
    end)
end

function online.fetchPlayers()
    if not isConnected then
        setDebug("Not connected")
        return
    end
    sendRequestWithRetry("GET", PATH, nil, function(success, response)
        if success then
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
        else
            setDebug("Fetch failed: " .. response)
        end
    end)
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
    sendRequestWithRetry("PUT", path, data, function(success, response)
        if success then
            setDebug("Skin updated: " .. skin)
        else
            setDebug("Skin update failed: " .. response)
        end
    end)
end

function online.getMySkin()
    return mySkin
end

function online.leave()
    if not isConnected or not myUid then return end
    local path = PATH .. myUid
    sendRequestWithRetry("DELETE", path, nil, function(success, response)
        if success then
            setDebug("Left room")
        else
            setDebug("Leave failed: " .. response)
        end
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

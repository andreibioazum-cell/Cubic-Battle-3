-- online.lua – полный (ПК: адаптивно; Android: https)
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
local abilities = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
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
    setDebug("Online ready: " .. (isAndroid and "Android (https)" or "PC (adaptive)"))
end

-- ============================================================
--  ОТПРАВКА ЗАПРОСОВ (адаптивно)
-- ============================================================
local function sendRequest(method, path, body, callback)
    if isAndroid then
        local https = require("https")
        local url = DB_URL .. path .. ".json"
        local options = {
            method = method,
            headers = { ["Content-Type"] = "application/json" },
            data = body or "",
            timeout = 5,
            verify = false,
        }
        local success, code, response = pcall(https.request, url, options)
        if success and code and code >= 200 and code < 300 then
            if callback then callback(true, response) end
            return response
        else
            local err = "{\"error\":\"HTTPS " .. tostring(code) .. "\"}"
            if callback then callback(false, err) end
            return err
        end
    end
    
    local url = DB_URL .. path .. ".json"
    local request_body = body or ""
    
    -- 1. Пробуем ssl.https
    local hasSsl, ssl = pcall(require, "ssl.https")
    if hasSsl then
        local ltn12 = require("ltn12")
        local response_table = {}
        local res, code, headers = ssl.request{
            url = url,
            method = method,
            headers = { ["Content-Type"] = "application/json" },
            source = body and ltn12.source.string(body) or nil,
            sink = ltn12.sink.table(response_table),
            timeout = 5,
        }
        local codeNum = tonumber(code)
        if codeNum and codeNum >= 200 and codeNum < 300 then
            local result = table.concat(response_table)
            if callback then callback(true, result) end
            return result
        end
    end
    
    -- 2. Пробуем love.network
    if love.network then
        local req = love.network.newHTTPRequest(method, url, {
            ["Content-Type"] = "application/json"
        }, request_body)
        req:send()
        local response = req:getResponse()
        if response then
            local status = response:getStatus()
            local responseBody = response:getBody()
            if status >= 200 and status < 300 then
                if callback then callback(true, responseBody) end
                return responseBody
            end
        end
    end
    
    -- 3. Пробуем socket.http
    local http = require("socket.http")
    local ltn12 = require("ltn12")
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
        -- 4. HTTP (без SSL)
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

    local roomPath = ROOMS_PATH .. roomCode .. "/info"
    local roomData = '{"owner":"' .. myUid .. '","created":' .. os.time() .. '}'
    sendRequest("PUT", roomPath, roomData, function(success, response)
        if not success then
            setDebug("Failed to create room: " .. response)
            if callback then callback(false, response) end
            return
        end
        local playerPath = ROOMS_PATH .. roomCode .. "/players/" .. myUid
        local playerData = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
        sendRequest("PUT", playerPath, playerData, function(success2, response2)
            if success2 then
                isConnected = true
                setDebug("Room created: " .. roomCode)
                if callback then callback(true) end
            else
                setDebug("Failed to add player: " .. response2)
                if callback then callback(false, response2) end
            end
        end)
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

    local checkPath = ROOMS_PATH .. roomCode .. "/info"
    sendRequest("GET", checkPath, nil, function(success, response)
        if not success or response == "null" then
            setDebug("Room does not exist")
            if callback then callback(false, "Room not found") end
            return
        end
        local playerPath = ROOMS_PATH .. roomCode .. "/players/" .. myUid
        local playerData = '{"x":0,"y":0,"nickname":"' .. nickname .. '","skin":"' .. mySkin .. '"}'
        sendRequest("PUT", playerPath, playerData, function(success2, response2)
            if success2 then
                isConnected = true
                setDebug("Joined room: " .. roomCode)
                if callback then callback(true) end
            else
                setDebug("Failed to join: " .. response2)
                if callback then callback(false, response2) end
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
--  ОТПРАВКА ПУЛИ
-- ============================================================
function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/bullets/" .. bulletId
    local data = '{"x":' .. x .. ',"y":' .. y .. ',"dx":' .. dx .. ',"dy":' .. dy .. ',"owner":"' .. myUid .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ОТПРАВКА СПОСОБНОСТИ
-- ============================================================
function online.sendAbility(abilityType, x, y, dirX, dirY, targetUid)
    if not isConnected or not myUid or not myRoomCode then
        return
    end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ROOMS_PATH .. myRoomCode .. "/abilities/" .. abilityId
    local data = '{"type":"' .. abilityType .. '","x":' .. x .. ',"y":' .. y .. ',"dirX":' .. (dirX or 0) .. ',"dirY":' .. (dirY or 0) .. ',"owner":"' .. myUid .. '","target":"' .. (targetUid or "") .. '","time":' .. love.timer.getTime() .. '}'
    sendRequest("PUT", path, data)
end

-- ============================================================
--  ПОЛУЧЕНИЕ ДАННЫХ
-- ============================================================
function online.fetchData()
    if not isConnected or not myRoomCode then
        return
    end
    
    local path = ROOMS_PATH .. myRoomCode
    
    sendRequest("GET", path .. "/players.json", nil, function(success, response)
        if success and response and response ~= "null" then
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
            end
        end
    end)
    
    sendRequest("GET", path .. "/bullets.json", nil, function(success, response)
        if success and response and response ~= "null" then
            local ok, data = pcall(love.data.decode, "string", "json", response)
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
    end)
    
    sendRequest("GET", path .. "/abilities.json", nil, function(success, response)
        if success and response and response ~= "null" then
            local ok, data = pcall(love.data.decode, "string", "json", response)
            if ok and data then
                abilities = {}
                for aid, info in pairs(data) do
                    if info.owner ~= myUid then
                        abilities[aid] = {
                            type = info.type,
                            x = info.x,
                            y = info.y,
                            dirX = info.dirX or 0,
                            dirY = info.dirY or 0,
                            owner = info.owner,
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
    if not isConnected or not myUid or not myRoomCode then
        return
    end
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

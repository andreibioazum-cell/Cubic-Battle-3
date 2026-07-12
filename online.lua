local online = {}

local ROOMS_PATH = "rooms/"
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"

local myUid = nil
local myNickname = nil
local myRoomCode = nil
local mySkin = "NONE"
local players = {}
local isConnected = false
local debugText = "Disconnected"

local fetchTimer = 0
local FETCH_INTERVAL = 0.4 
local isAndroid = (love.system.getOS() == "Android")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

-- Простейший парсер JSON для игроков
local function parsePlayers(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return nil end
    local result = {}
    -- Ищем структуру "ID": { "nickname": "...", "skin": "...", "x": ..., "y": ... }
    for id, content in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local x = content:match('"x":%s*([%d%.%-]+)')
        local y = content:match('"y":%s*([%d%.%-]+)')
        local nick = content:match('"nickname":%s*"([^"]+)"')
        local skin = content:match('"skin":%s*"([^"]+)"')
        
        if x and y then
            result[id] = {
                x = tonumber(x),
                y = tonumber(y),
                nickname = nick or "Unknown",
                skin = skin or "NONE"
            }
        end
    end
    return result
end

local function sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json"
    if isAndroid then
        local https = require("ssl.https")
        local ltn12 = require("ltn12")
        local response_body = {}
        local res, code = https.request{
            url = url,
            method = method,
            headers = {
                ["Content-Type"] = "application/json",
                ["Content-Length"] = tostring(body and #body or 0)
            },
            source = body and ltn12.source.string(body) or nil,
            sink = ltn12.sink.table(response_body)
        }
        if callback then callback(code and code < 300, table.concat(response_body)) end
    else
        local curlCmd = 'curl -s -X ' .. method .. ' "' .. url .. '"'
        if body then
            local escapedBody = body:gsub('"', '\\"')
            curlCmd = curlCmd .. ' -d "' .. escapedBody .. '"'
        end
        local handle = io.popen(curlCmd)
        local result = handle:read("*a")
        handle:close()
        if callback then callback(result ~= nil and not result:match("error"), result) end
    end
end

function online.init()
    setDebug("Ready")
end

function online.createRoom(roomCode, nickname, callback)
    myRoomCode = roomCode
    myNickname = nickname
    myUid = "u" .. math.random(1000, 9999)
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    local data = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
    
    sendRequest("PUT", path, data, function(ok)
        if ok then
            isConnected = true
            setDebug("Created: " .. myRoomCode)
            if callback then callback(true, myRoomCode) end
        else
            if callback then callback(false, "Network Error") end
        end
    end)
end

function online.joinRoom(roomCode, nickname, callback)
    myRoomCode = roomCode
    myNickname = nickname
    myUid = "u" .. math.random(1000, 9999)
    mySkin = SAVE_DATA.equippedSkin or "NONE"

    sendRequest("GET", ROOMS_PATH .. myRoomCode .. "/players", nil, function(ok, res)
        if ok and res ~= "null" then
            local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
            local data = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
            sendRequest("PUT", path, data, function(ok2)
                if ok2 then
                    isConnected = true
                    setDebug("Joined: " .. myRoomCode)
                    if callback then callback(true, myRoomCode) end
                else
                    if callback then callback(false, "Join Error") end
                end
            end)
        else
            if callback then callback(false, "Room 404") end
        end
    end)
end

function online.sendPosition(x, y)
    if not isConnected then return end
    local path = ROOMS_PATH .. myRoomCode .. "/players/" .. myUid
    local data = string.format('{"x":%d,"y":%d,"nickname":"%s","skin":"%s"}', math.floor(x), math.floor(y), myNickname, mySkin)
    sendRequest("PUT", path, data)
end

function online.fetchData()
    if not isConnected then return end
    sendRequest("GET", ROOMS_PATH .. myRoomCode .. "/players", nil, function(ok, res)
        if ok then
            local newPlayers = parsePlayers(res)
            if newPlayers then
                for id, data in pairs(newPlayers) do
                    if id ~= myUid then
                        if not players[id] then
                            players[id] = data
                        else
                            players[id].targetX = data.x
                            players[id].targetY = data.y
                            players[id].nickname = data.nickname
                            players[id].skin = data.skin
                        end
                    end
                end
                -- Удаляем тех, кто вышел
                for id in pairs(players) do
                    if not newPlayers[id] then players[id] = nil end
                end
            end
        end
    end)
end

function online.update(dt)
    if not isConnected then return end
    
    -- Плавное движение (Lerp)
    for id, p in pairs(players) do
        if p.targetX then
            p.x = p.x or p.targetX
            p.y = p.y or p.targetY
            p.x = p.x + (p.targetX - p.x) * dt * 8
            p.y = p.y + (p.targetY - p.y) * dt * 8
        end
    end

    fetchTimer = fetchTimer + dt
    if fetchTimer > FETCH_INTERVAL then
        fetchTimer = 0
        online.fetchData()
    end
end

function online.getPlayers() return players end
function online.isConnected() return isConnected end
function online.getMyUid() return myUid end
function online.getDebugText() return debugText end
function online.updateSkin(skin) mySkin = skin end

function online.leave() 
    if isConnected then
        sendRequest("DELETE", ROOMS_PATH .. myRoomCode .. "/players/" .. myUid)
    end
    isConnected = false 
    players = {}
    myRoomCode = nil
end

return online

-- online.lua – работа с Firebase (ПК: socket.http, Android: https)
local online = {}

local DB_URL = "http://cubic-battle-3-default-rtdb.firebaseio.com/"
local PLAYERS_PATH = "players/"
local BULLETS_PATH = "bullets/"
local ABILITIES_PATH = "abilities/"

local myUid = nil
local myNickname = nil
local mySkin = "NONE"
local players = {}
local bullets = {}
local abilities = {}
local isConnected = false
local debugText = "Waiting..."
local lastSentX = nil
local lastSentY = nil
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.3
local FETCH_INTERVAL = 0.3

local isAndroid = (love.system.getOS() == "Android")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function sendToGameDebug(text, color)
    if _G.addDebugMessage then
        _G.addDebugMessage(text, color)
    end
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

-- ============================================================
--  ПАРСИНГ
-- ============================================================
local function parsePlayers(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local nick = data:match('"nickname":%s*"([^"]+)"')
        local skin = data:match('"skin":%s*"([^"]+)"')
        if x and y then
            result[id] = {
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                nickname = nick or "Player",
                skin = skin or "NONE",
                targetX = tonumber(x) or 0,
                targetY = tonumber(y) or 0
            }
        end
    end
    return result
end

local function parseBullets(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local dx = data:match('"dx":%s*([%d%.%-]+)')
        local dy = data:match('"dy":%s*([%d%.%-]+)')
        local owner = data:match('"owner":%s*"([^"]+)"')
        if x and y and dx and dy then
            result[id] = {
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                dx = tonumber(dx) or 0,
                dy = tonumber(dy) or 0,
                owner = owner or "",
                life = 3
            }
        end
    end
    return result
end

local function parseAbilities(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local type = data:match('"type":%s*"([^"]+)"')
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local owner = data:match('"owner":%s*"([^"]+)"')
        if type and x and y then
            result[id] = {
                type = type,
                x = tonumber(x) or 0,
                y = tonumber(y) or 0,
                owner = owner or "",
                dirX = tonumber(data:match('"dirX":%s*([%d%.%-]+)')) or 0,
                dirY = tonumber(data:match('"dirY":%s*([%d%.%-]+)')) or 0,
                time = tonumber(data:match('"time":%s*([%d%.%-]+)')) or 0
            }
        end
    end
    return result
end

-- ============================================================
--  ОТПРАВКА ЗАПРОСОВ (ПК: socket.http, Android: https)
-- ============================================================
local function sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json"
    
    sendToGameDebug("Request: " .. method .. " " .. path, {0.5, 0.5, 0.8, 1})
    
    if isAndroid then
        local ok, https = pcall(require, "https")
        if not ok then
            sendToGameDebug("Error: https module not found", {0.9, 0.2, 0.2, 1})
            if callback then callback(false, "https module not found") end
            return
        end
        
        local ltn12 = require("ltn12")
        local response_body = {}
        local request_body = body or ""
        local headers = {
            ["Content-Type"] = "application/json",
            ["Content-Length"] = tostring(#request_body),
        }
        
        -- ✅ ДОБАВЛЕН verify = false
        local res, code = https.request(url, {
            method = method,
            headers = headers,
            source = ltn12.source.string(request_body),
            sink = ltn12.sink.table(response_body),
            timeout = 10,
            verify = false,   -- <--- ОТКЛЮЧАЕМ ПРОВЕРКУ SSL
        })
        
        local response = table.concat(response_body)
        code = tonumber(code) or 0
        
        if code >= 200 and code < 300 then
            sendToGameDebug("Success: " .. method .. " " .. path, {0.2, 0.8, 0.2, 1})
            if callback then callback(true, response) end
        else
            sendToGameDebug("Error: " .. method .. " " .. path .. " - " .. tostring(code), {0.9, 0.2, 0.2, 1})
            if callback then callback(false, "HTTPS Error: " .. tostring(code)) end
        end
        return
    end
    
    -- Windows: socket.http
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local response_body = {}
    local request_body = body or ""
    local headers = {
        ["Content-Type"] = "application/json",
        ["Content-Length"] = tostring(#request_body),
    }
    
    local res, code = http.request{
        url = url,
        method = method,
        headers = headers,
        source = ltn12.source.string(request_body),
        sink = ltn12.sink.table(response_body),
        timeout = 10,
    }
    
    local response = table.concat(response_body)
    code = tonumber(code) or 0
    
    if code >= 200 and code < 300 then
        sendToGameDebug("Success: " .. method .. " " .. path, {0.2, 0.8, 0.2, 1})
        if callback then callback(true, response) end
    else
        sendToGameDebug("Error: " .. method .. " " .. path .. " - " .. tostring(code), {0.9, 0.2, 0.2, 1})
        if callback then callback(false, "HTTP Error: " .. tostring(code)) end
    end
end

-- ============================================================
--  ФУНКЦИИ
-- ============================================================
function online.init(nickname)
    myNickname = nickname or "Player"
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    myUid = generateUuid()
    
    setDebug("Online initialized")
    sendToGameDebug("Online initialized", {0.5, 0.5, 0.8, 1})
    
    online.connect()
end

function online.connect()
    if not myUid then return end
    
    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
    
    sendRequest("PUT", path, data, function(ok, response)
        if ok then
            isConnected = true
            setDebug("Connected to global server")
            sendToGameDebug("Connected to global server", {0.2, 0.8, 0.2, 1})
        else
            setDebug("Failed to connect: " .. tostring(response))
            sendToGameDebug("Failed to connect: " .. tostring(response), {0.9, 0.2, 0.2, 1})
        end
    end)
end

function online.getMyUid()
    return myUid
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

function online.isConnected()
    return isConnected
end

function online.getDebugText()
    return debugText
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then return end

    local newX = math.floor(x)
    local newY = math.floor(y)
    if lastSentX == newX and lastSentY == newY then return end

    lastSentX = newX
    lastSentY = newY

    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":%d,"y":%d,"nickname":"%s","skin":"%s"}', newX, newY, myNickname, mySkin)
    sendRequest("PUT", path, data)
end

function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = BULLETS_PATH .. bulletId
    local data = string.format('{"x":%d,"y":%d,"dx":%f,"dy":%f,"owner":"%s","time":%f}',
        math.floor(x), math.floor(y), dx, dy, myUid, love.timer.getTime())
    sendRequest("PUT", path, data)
end

function online.sendAbility(abilityType, x, y, dirX, dirY)
    if not isConnected or not myUid then return end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ABILITIES_PATH .. abilityId
    local data = string.format('{"type":"%s","x":%d,"y":%d,"dirX":%f,"dirY":%f,"owner":"%s","time":%f}',
        abilityType, math.floor(x), math.floor(y), dirX or 0, dirY or 0, myUid, love.timer.getTime())
    sendRequest("PUT", path, data)
end

function online.fetchPlayers()
    if not isConnected then
        sendToGameDebug("Cannot fetch: not connected", {0.9, 0.8, 0.2, 1})
        return
    end

    sendToGameDebug("Fetching players...", {0.5, 0.5, 0.8, 1})

    sendRequest("GET", PLAYERS_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            local newPlayers = parsePlayers(res)

            for id, data in pairs(newPlayers) do
                if id ~= myUid then
                    if not players[id] then
                        players[id] = data
                        sendToGameDebug("New player: " .. data.nickname, {0.2, 0.8, 0.2, 1})
                    else
                        players[id].targetX = data.x
                        players[id].targetY = data.y
                        players[id].nickname = data.nickname
                        players[id].skin = data.skin
                    end
                end
            end

            for id in pairs(players) do
                if not newPlayers[id] then
                    sendToGameDebug("Player left: " .. players[id].nickname, {0.9, 0.6, 0.2, 1})
                    players[id] = nil
                end
            end

            local count = 0
            local names = {}
            for id, info in pairs(players) do
                count = count + 1
                table.insert(names, info.nickname)
            end
            if count > 0 then
                sendToGameDebug("Players online: " .. count .. " - " .. table.concat(names, ", "), {0.2, 0.8, 0.2, 1})
            end
        else
            sendToGameDebug("No players online", {0.9, 0.6, 0.2, 1})
        end
    end)
end

function online.fetchData()
    if not isConnected then return end

    online.fetchPlayers()

    sendRequest("GET", BULLETS_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            local ok2, data = pcall(love.data.decode, "string", "json", res)
            if ok2 and data then
                bullets = {}
                for bid, info in pairs(data) do
                    if info.owner ~= myUid then
                        bullets[bid] = {
                            x = info.x or 0,
                            y = info.y or 0,
                            dx = info.dx or 0,
                            dy = info.dy or 0,
                            owner = info.owner or "",
                            time = info.time or 0,
                        }
                    end
                end
            end
        end
    end)

    sendRequest("GET", ABILITIES_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            local ok2, data = pcall(love.data.decode, "string", "json", res)
            if ok2 and data then
                abilities = {}
                for aid, info in pairs(data) do
                    if info.owner ~= myUid then
                        abilities[aid] = {
                            type = info.type or "",
                            x = info.x or 0,
                            y = info.y or 0,
                            dirX = info.dirX or 0,
                            dirY = info.dirY or 0,
                            owner = info.owner or "",
                            target = info.target or "",
                            time = info.time or 0,
                        }
                    end
                end
            end
        end
    end)
end

function online.update(dt)
    if not isConnected then return end

    for id, p in pairs(players) do
        if p.targetX then
            p.x = p.x or p.targetX
            p.y = p.y or p.targetY
            p.x = p.x + (p.targetX - p.x) * math.min(1, dt * 8)
            p.y = p.y + (p.targetY - p.y) * math.min(1, dt * 8)
        end
    end

    for id, b in pairs(bullets) do
        b.x = b.x + b.dx * 390 * dt
        b.y = b.y + b.dy * 390 * dt
        b.life = b.life - dt
        if b.life <= 0 then bullets[id] = nil end
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

function online.leave()
    if isConnected and myUid then
        sendRequest("DELETE", PLAYERS_PATH .. myUid)
    end
    isConnected = false
    players = {}
    bullets = {}
    abilities = {}
    myUid = nil
    myNickname = nil
    lastSentX = nil
    lastSentY = nil
    sendToGameDebug("Left server", {0.5, 0.5, 0.8, 1})
end

function online.updateSkin(skin)
    mySkin = skin
end

return online

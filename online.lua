-- online.lua - ПК = Scrap-Mods/http, ANDROID = lua-https (LÖVE 12)
local online = {}

local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local API_KEY = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4"

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
local lastSentTime = 0
local fetchTimer = 0

local isAndroid = (love.system.getOS() == "Android")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

-- ============================================================
--  ПК: Scrap-Mods/http
-- ============================================================
local http = nil
local httpLoaded = false

local function initHttp()
    local ok, result = pcall(require, "http")
    if ok then
        http = result
        httpLoaded = true
        print("[ONLINE] ✅ Scrap-Mods/http loaded on PC!")
        return true
    else
        print("[ONLINE] ❌ Scrap-Mods/http not found on PC")
        return false
    end
end

if not isAndroid then
    initHttp()
end

local function sendPCRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    
    print("[ONLINE] PC: " .. method .. " " .. path)
    print("[ONLINE] URL: " .. url)
    
    if httpLoaded and http then
        local options = {
            url = url,
            method = method,
            headers = {
                ["Content-Type"] = "application/json"
            }
        }
        
        if body then
            options.data = body
        end
        
        http.request(options, function(response)
            local code = response.status or 0
            if code >= 200 and code < 300 then
                print("[ONLINE] ✅ Scrap-Mods/http success! Code: " .. code)
                if callback then callback(true, response.body) end
            else
                print("[ONLINE] ❌ Scrap-Mods/http error: " .. code)
                if callback then callback(false, "HTTP error: " .. code) end
            end
        end)
        
        return true
    else
        local data = body or "{}"
        data = data:gsub('"', '\\"')
        
        local cmd
        if method == "GET" then
            cmd = 'curl -s -m 10 -X GET "' .. url .. '"'
        else
            cmd = 'curl -s -m 10 -X ' .. method .. ' -H "Content-Type: application/json" -d "' .. data .. '" "' .. url .. '"'
        end
        
        print("[ONLINE] CMD (fallback): " .. cmd)
        
        local handle = io.popen(cmd)
        local result = handle and handle:read("*a")
        if handle then handle:close() end
        
        if result and result ~= "" and not result:match("curl:") and not result:match("Failed") then
            print("[ONLINE] ✅ Curl success!")
            if callback then callback(true, result) end
            return true
        else
            print("[ONLINE] ❌ Curl failed: " .. tostring(result))
            if callback then callback(false, result or "Curl failed") end
            return false
        end
    end
end

-- ============================================================
--  ANDROID: lua-https (LÖVE 12)
-- ============================================================
local function sendAndroidRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    
    print("[ONLINE] Android: " .. method .. " " .. path)
    print("[ONLINE] URL: " .. url)
    
    local ok, https = pcall(require, "https")
    if not ok then
        print("[ONLINE] ❌ https not found on Android! Trying curl...")
        return sendAndroidCurl(method, path, body, callback)
    end
    
    local options = {
        method = method,
        headers = {
            ["Content-Type"] = "application/json"
        }
    }
    
    if body then
        options.data = body
    end
    
    local code, response = https.request(url, options)
    
    if code >= 200 and code < 300 then
        print("[ONLINE] ✅ Android lua-https success! Code: " .. code)
        if callback then callback(true, response) end
        return true
    else
        print("[ONLINE] ❌ Android lua-https error: " .. tostring(code))
        if callback then callback(false, "HTTP error: " .. code) end
        return false
    end
end

-- ============================================================
--  ANDROID FALLBACK: curl (если lua-https не работает)
-- ============================================================
local function sendAndroidCurl(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    
    print("[ONLINE] Android curl fallback: " .. method .. " " .. path)
    
    local data = body or "{}"
    data = data:gsub('"', '\\"')
    
    local cmd
    if method == "GET" then
        cmd = 'curl -s -m 10 -X GET "' .. url .. '"'
    else
        cmd = 'curl -s -m 10 -X ' .. method .. ' -H "Content-Type: application/json" -d "' .. data .. '" "' .. url .. '"'
    end
    
    print("[ONLINE] CMD: " .. cmd)
    
    local handle = io.popen(cmd)
    local result = handle and handle:read("*a")
    if handle then handle:close() end
    
    if result and result ~= "" and not result:match("curl:") and not result:match("Failed") then
        print("[ONLINE] ✅ Android curl success!")
        if callback then callback(true, result) end
        return true
    else
        print("[ONLINE] ❌ Android curl failed: " .. tostring(result))
        if callback then callback(false, result or "Curl failed") end
        return false
    end
end

function online.sendRequest(method, path, body, callback)
    if isAndroid then
        return sendAndroidRequest(method, path, body, callback)
    else
        return sendPCRequest(method, path, body, callback)
    end
end

function online.parsePlayers(jsonStr)
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

function online.parseBullets(jsonStr)
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

function online.parseAbilities(jsonStr)
    if not jsonStr or jsonStr == "" or jsonStr == "null" then return {} end
    local result = {}
    for id, data in jsonStr:gmatch('"([^"]+)":%s*({[^{}]+})') do
        local typ = data:match('"type":%s*"([^"]+)"')
        local x = data:match('"x":%s*([%d%.%-]+)')
        local y = data:match('"y":%s*([%d%.%-]+)')
        local owner = data:match('"owner":%s*"([^"]+)"')
        if typ and x and y then
            result[id] = {
                type = typ,
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

function online.init(nickname)
    myNickname = nickname or "Player"
    mySkin = SAVE_DATA.equippedSkin or "NONE"
    myUid = SAVE_DATA.uid or generateUuid()
    SAVE_DATA.uid = myUid
    SAVE_SAVE()
    
    setDebug("Online initialized with UID: " .. myUid)
    online.connect()
end

function online.connect()
    if not myUid then return end
    
    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":400,"y":300,"nickname":"%s","skin":"%s"}', myNickname, mySkin)
    
    setDebug("Connecting...")
    
    online.sendRequest("PUT", path, data, function(ok, response)
        if ok then
            isConnected = true
            setDebug("✅ Connected!")
            print("[ONLINE] ✅ Connected to Firebase!")
        else
            setDebug("❌ Failed to connect")
            isConnected = false
            print("[ONLINE] ❌ Connection failed!")
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
    
    local now = love.timer.getTime()
    if now - lastSentTime < 0.5 then return end
    lastSentTime = now

    lastSentX = newX
    lastSentY = newY

    local path = PLAYERS_PATH .. myUid
    local data = string.format('{"x":%d,"y":%d,"nickname":"%s","skin":"%s"}', 
        newX, newY, myNickname, mySkin)
    online.sendRequest("PATCH", path, data)
end

function online.sendBullet(x, y, dx, dy)
    if not isConnected or not myUid then return end
    local bulletId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = BULLETS_PATH .. bulletId
    local data = string.format('{"x":%d,"y":%d,"dx":%f,"dy":%f,"owner":"%s","time":%f}',
        math.floor(x), math.floor(y), dx, dy, myUid, love.timer.getTime())
    online.sendRequest("PUT", path, data)
end

function online.sendAbility(abilityType, x, y, dirX, dirY)
    if not isConnected or not myUid then return end
    local abilityId = myUid .. "_" .. os.time() .. "_" .. math.random(1000, 9999)
    local path = ABILITIES_PATH .. abilityId
    local data = string.format('{"type":"%s","x":%d,"y":%d,"dirX":%f,"dirY":%f,"owner":"%s","time":%f}',
        abilityType, math.floor(x), math.floor(y), dirX or 0, dirY or 0, myUid, love.timer.getTime())
    online.sendRequest("PUT", path, data)
end

function online.updateSkin(skin)
    mySkin = skin
    if isConnected and myUid then
        local path = PLAYERS_PATH .. myUid
        local data = string.format('{"skin":"%s"}', skin)
        online.sendRequest("PATCH", path, data)
    end
end

function online.fetchPlayers()
    if not isConnected then return end

    online.sendRequest("GET", PLAYERS_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            local newPlayers = online.parsePlayers(res)

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

            for id in pairs(players) do
                if not newPlayers[id] then
                    players[id] = nil
                end
            end
        end
    end)

    online.sendRequest("GET", BULLETS_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            bullets = online.parseBullets(res)
        end
    end)

    online.sendRequest("GET", ABILITIES_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            abilities = online.parseAbilities(res)
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

    fetchTimer = fetchTimer + dt
    if fetchTimer >= 2.0 then
        fetchTimer = 0
        online.fetchPlayers()
    end
end

function online.leave()
    if isConnected and myUid then
        online.sendRequest("DELETE", PLAYERS_PATH .. myUid)
    end
    isConnected = false
    players = {}
    bullets = {}
    abilities = {}
    myUid = nil
    myNickname = nil
    lastSentX = nil
    lastSentY = nil
end

return online

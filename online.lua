-- online.lua - УНИВЕРСАЛЬНЫЙ (ПК + Android + Mac/Linux)
local online = {}

-- ============================================================
--  КОНФИГУРАЦИЯ FIREBASE
-- ============================================================
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local API_KEY = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4"

local PLAYERS_PATH = "players/"
local BULLETS_PATH = "bullets/"
local ABILITIES_PATH = "abilities/"

-- ============================================================
--  СОСТОЯНИЕ
-- ============================================================
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
local isWindows = (love.system.getOS() == "Windows")
local isMac = (love.system.getOS() == "OS X")
local isLinux = (love.system.getOS() == "Linux")

local function setDebug(text)
    debugText = text
    print("[ONLINE] " .. text)
end

local function generateUuid()
    return "p" .. os.time() .. math.random(1000, 9999)
end

-- ============================================================
--  ПОИСК CURL НА ANDROID (ВСЕ ПУТИ)
-- ============================================================
local function findCurlAndroid()
    local paths = {
        "curl",
        "/system/bin/curl",
        "/system/xbin/curl",
        "/vendor/bin/curl",
        "/data/local/bin/curl",
        "/data/data/com.termux/files/usr/bin/curl",
        "/data/data/com.termux/files/home/bin/curl",
        "/sbin/curl",
        "/magisk/.core/bin/curl",
        "/data/adb/magisk/bin/curl",
        "/data/data/io.neoterm/files/usr/bin/curl",
        "/data/local/tmp/curl",
        "/mnt/sdcard/bin/curl",
        "/storage/emulated/0/bin/curl",
        "/system/sd/xbin/curl",
        "/system/bin/busybox",
        "/system/xbin/busybox",
        "/apex/com.android.runtime/bin/curl",
        "/apex/com.android.art/bin/curl"
    }
    
    for _, path in ipairs(paths) do
        local testCmd = path .. " --version 2>/dev/null"
        local handle = io.popen(testCmd)
        local result = handle and handle:read("*a")
        if handle then handle:close() end
        
        if result and result ~= "" and not result:match("not found") and not result:match("No such") then
            print("[ONLINE] ✅ Found curl at: " .. path)
            return path
        end
    end
    
    -- Пробуем through which
    local whichCmd = 'which curl 2>/dev/null'
    local handle = io.popen(whichCmd)
    local result = handle and handle:read("*a")
    if handle then handle:close() end
    
    if result and result ~= "" then
        local path = result:gsub("\n", "")
        print("[ONLINE] ✅ Found curl via which: " .. path)
        return path
    end
    
    return nil
end

-- ============================================================
--  ПОИСК HTTP КЛИЕНТА НА ПК (Windows/Mac/Linux)
-- ============================================================
local function findCurlPC()
    -- На ПК просто проверяем curl
    local testCmd = 'curl --version 2>/dev/null'
    local handle = io.popen(testCmd)
    local result = handle and handle:read("*a")
    if handle then handle:close() end
    
    if result and result ~= "" and not result:match("not found") then
        print("[ONLINE] ✅ Found curl on PC")
        return "curl"
    end
    
    -- Пробуем wget
    local testCmd2 = 'wget --version 2>/dev/null'
    local handle2 = io.popen(testCmd2)
    local result2 = handle2 and handle2:read("*a")
    if handle2 then handle2:close() end
    
    if result2 and result2 ~= "" and not result2:match("not found") then
        print("[ONLINE] ✅ Found wget on PC")
        return "wget"
    end
    
    -- На Windows пробуем PowerShell
    if isWindows then
        local testCmd3 = 'powershell -Command "Get-Command Invoke-RestMethod" 2>$null'
        local handle3 = io.popen(testCmd3)
        local result3 = handle3 and handle3:read("*a")
        if handle3 then handle3:close() end
        
        if result3 and result3 ~= "" then
            print("[ONLINE] ✅ Found PowerShell on Windows")
            return "powershell"
        end
    end
    
    print("[ONLINE] ❌ No HTTP client found on PC!")
    return nil
end

-- ============================================================
--  ВЫБОР HTTP КЛИЕНТА (ВСЕ ПЛАТФОРМЫ)
-- ============================================================
local httpClient = nil
local clientType = nil

if isAndroid then
    -- На Android ищем curl
    local curl = findCurlAndroid()
    if curl then
        httpClient = curl
        clientType = "curl"
        print("[ONLINE] Using curl on Android: " .. httpClient)
    else
        -- Пробуем wget
        local wgetPaths = {"wget", "/system/bin/wget", "/system/xbin/wget"}
        for _, path in ipairs(wgetPaths) do
            local testCmd = path .. " --version 2>/dev/null"
            local handle = io.popen(testCmd)
            local result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("not found") then
                httpClient = path
                clientType = "wget"
                print("[ONLINE] Using wget on Android: " .. httpClient)
                break
            end
        end
    end
else
    -- На ПК (Windows/Mac/Linux)
    local pcClient = findCurlPC()
    if pcClient then
        clientType = pcClient
        if pcClient == "curl" or pcClient == "wget" then
            httpClient = pcClient
            print("[ONLINE] Using " .. pcClient .. " on PC")
        elseif pcClient == "powershell" then
            clientType = "powershell"
            httpClient = "powershell"
            print("[ONLINE] Using PowerShell on Windows")
        end
    end
end

if not clientType then
    print("[ONLINE] ❌ No HTTP client found!")
    setDebug("No HTTP client found! Install curl or wget")
end

-- ============================================================
--  ОТПРАВКА ЗАПРОСА (УНИВЕРСАЛЬНАЯ)
-- ============================================================
function online.sendRequest(method, path, body, callback)
    local url = DB_URL .. path .. ".json?auth=" .. API_KEY
    
    print("[ONLINE] ========================================")
    print("[ONLINE] METHOD: " .. method)
    print("[ONLINE] PATH: " .. path)
    print("[ONLINE] URL: " .. url)
    
    local data = body or "{}"
    local result = nil
    local success = false
    
    if not clientType then
        print("[ONLINE] ❌ No HTTP client available!")
        if callback then callback(false, "No HTTP client") end
        return false
    end
    
    -- ============================================================
    --  ANDROID: curl или wget
    -- ============================================================
    if isAndroid then
        local escapedData = data:gsub('"', '\\"')
        
        if clientType == "curl" and httpClient then
            local cmd
            if method == "GET" then
                cmd = httpClient .. ' -s -m 5 -X GET "' .. url .. '"'
            else
                cmd = httpClient .. ' -s -m 5 -X ' .. method .. ' -H "Content-Type: application/json" -d "' .. escapedData .. '" "' .. url .. '"'
            end
            
            print("[ONLINE] CMD (Android curl): " .. cmd)
            
            local handle = io.popen(cmd)
            result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("curl:") and not result:match("not found") then
                success = true
                print("[ONLINE] ✅ Android curl success!")
            end
            
        elseif clientType == "wget" and httpClient then
            local cmd
            if method == "GET" then
                cmd = httpClient .. ' -q -O- --timeout=5 "' .. url .. '"'
            else
                cmd = httpClient .. ' -q -O- --timeout=5 --header="Content-Type: application/json" --post-data="' .. escapedData .. '" "' .. url .. '"'
            end
            
            print("[ONLINE] CMD (Android wget): " .. cmd)
            
            local handle = io.popen(cmd)
            result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("wget:") then
                success = true
                print("[ONLINE] ✅ Android wget success!")
            end
        end
    end
    
    -- ============================================================
    --  WINDOWS: curl, wget или PowerShell
    -- ============================================================
    if not success and isWindows then
        local escapedData = data:gsub('"', '\\"')
        
        if clientType == "curl" then
            local cmd
            if method == "GET" then
                cmd = 'curl -s -m 5 -X GET "' .. url .. '"'
            else
                cmd = 'curl -s -m 5 -X ' .. method .. ' -H "Content-Type: application/json" -d "' .. escapedData .. '" "' .. url .. '"'
            end
            
            print("[ONLINE] CMD (Windows curl): " .. cmd)
            
            local handle = io.popen(cmd)
            result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("curl:") then
                success = true
                print("[ONLINE] ✅ Windows curl success!")
            end
            
        elseif clientType == "wget" then
            local cmd
            if method == "GET" then
                cmd = 'wget -q -O- --timeout=5 "' .. url .. '"'
            else
                cmd = 'wget -q -O- --timeout=5 --header="Content-Type: application/json" --post-data="' .. escapedData .. '" "' .. url .. '"'
            end
            
            print("[ONLINE] CMD (Windows wget): " .. cmd)
            
            local handle = io.popen(cmd)
            result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("wget:") then
                success = true
                print("[ONLINE] ✅ Windows wget success!")
            end
            
        elseif clientType == "powershell" then
            local escapedData = data:gsub('"', '""')
            local psCmd
            
            if method == "GET" then
                psCmd = 'powershell -Command "try { $r = Invoke-RestMethod -Uri ''' .. url .. ''' -Method Get -TimeoutSec 5; $r | ConvertTo-Json -Compress } catch { exit 1 }"'
            else
                psCmd = 'powershell -Command "try { $r = Invoke-RestMethod -Uri ''' .. url .. ''' -Method ' .. method .. ' -Body ''' .. escapedData .. ''' -ContentType ''application/json'' -TimeoutSec 5; $r | ConvertTo-Json -Compress } catch { exit 1 }"'
            end
            
            print("[ONLINE] CMD (PowerShell): " .. psCmd)
            
            local handle = io.popen(psCmd)
            result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("error") then
                success = true
                print("[ONLINE] ✅ PowerShell success!")
            end
        end
    end
    
    -- ============================================================
    --  MAC / LINUX: curl или wget
    -- ============================================================
    if not success and (isMac or isLinux) then
        local escapedData = data:gsub('"', '\\"')
        
        if clientType == "curl" then
            local cmd
            if method == "GET" then
                cmd = 'curl -s -m 5 -X GET "' .. url .. '"'
            else
                cmd = 'curl -s -m 5 -X ' .. method .. ' -H "Content-Type: application/json" -d "' .. escapedData .. '" "' .. url .. '"'
            end
            
            print("[ONLINE] CMD (Mac/Linux curl): " .. cmd)
            
            local handle = io.popen(cmd)
            result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("curl:") then
                success = true
                print("[ONLINE] ✅ Mac/Linux curl success!")
            end
            
        elseif clientType == "wget" then
            local cmd
            if method == "GET" then
                cmd = 'wget -q -O- --timeout=5 "' .. url .. '"'
            else
                cmd = 'wget -q -O- --timeout=5 --header="Content-Type: application/json" --post-data="' .. escapedData .. '" "' .. url .. '"'
            end
            
            print("[ONLINE] CMD (Mac/Linux wget): " .. cmd)
            
            local handle = io.popen(cmd)
            result = handle and handle:read("*a")
            if handle then handle:close() end
            
            if result and result ~= "" and not result:match("wget:") then
                success = true
                print("[ONLINE] ✅ Mac/Linux wget success!")
            end
        end
    end
    
    -- ============================================================
    --  РЕЗУЛЬТАТ
    -- ============================================================
    if success then
        print("[ONLINE] ✅ Request successful!")
        if result then
            print("[ONLINE] Response: " .. result:sub(1, 100) .. "...")
        end
        if callback then callback(true, result) end
        return true
    else
        print("[ONLINE] ❌ Request failed!")
        if result then
            print("[ONLINE] Error: " .. result)
        end
        setDebug("Connection failed - check internet")
        if callback then callback(false, "All methods failed") end
        return false
    end
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

-- ============================================================
--  ОСНОВНЫЕ ФУНКЦИИ
-- ============================================================
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
            local newPlayers = parsePlayers(res)

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
            bullets = parseBullets(res)
        end
    end)

    online.sendRequest("GET", ABILITIES_PATH, nil, function(ok, res)
        if ok and res and res ~= "null" then
            abilities = parseAbilities(res)
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

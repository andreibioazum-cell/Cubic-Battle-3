-- online.lua – полный онлайн с защитой от любых ошибок JSON
local online = {}

local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com"
local PATH = "players/"

local myUid = nil
local myNickname = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false
local debugText = "Waiting..."

local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

local function firebaseRequest(method, path, data, callback)
    local https = require("https")
    local url = DB_URL .. "/" .. path .. ".json"
    local options = {
        method = method,
        headers = { ["Content-Type"] = "application/json" },
        timeout = 5,
        verify = false,
    }
    if data then
        options.data = data
    end

    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        if callback then callback(true, body) end
    else
        if callback then callback(false, "Error: " .. tostring(code) .. " " .. tostring(body)) end
    end
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

function online.isNicknameTaken(nickname, callback)
    if not nickname or nickname == "" then
        callback(false, "Nickname cannot be empty")
        return
    end
    firebaseRequest("GET", PATH, nil, function(success, body)
        if success and body then
            local ok, data = pcall(love.data.decode, "string", "json", body)
            if ok and data then
                for uid, info in pairs(data) do
                    if info.nickname and info.nickname == nickname and uid ~= myUid then
                        callback(true, "Nickname already taken")
                        return
                    end
                end
                callback(false, "Nickname available")
            else
                callback(false, "No players yet")
            end
        else
            callback(false, "Failed to check")
        end
    end)
end

function online.init(nickname, callback)
    if not nickname or nickname == "" then
        setDebug("Nickname required, using 'Player'")
        nickname = "Player"
    end

    myUid = generateUuid()
    myNickname = nickname
    setDebug("My ID: " .. myUid .. ", nick: " .. nickname)

    online.isNicknameTaken(nickname, function(taken, msg)
        if taken then
            setDebug("Nickname taken: " .. msg)
            if callback then callback(false, msg) end
            return
        end

        local path = PATH .. myUid
        local data = '{"x":0,"y":0,"nickname":"' .. nickname .. '"}'
        firebaseRequest("PUT", path, data, function(success)
            if success then
                isConnected = true
                setDebug("Connected as " .. nickname)
                if callback then callback(true) end
            else
                setDebug("Failed to register")
                if callback then callback(false, "Registration failed") end
            end
        end)
    end)
end

function online.connect(callback)
    if isConnected then
        if callback then callback(true) end
    else
        if callback then callback(false, "Not connected") end
    end
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("Not connected or no UID")
        return
    end
    local path = PATH .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. ',"nickname":"' .. myNickname .. '"}'
    firebaseRequest("PUT", path, data, function(success, body)
        if not success then
            setDebug("PUT failed: " .. (body or "unknown"))
        else
            setDebug("Sent: " .. math.floor(x) .. "," .. math.floor(y))
        end
    end)
end

function online.fetchPlayers()
    if not isConnected then
        setDebug("Not connected")
        return
    end
    firebaseRequest("GET", PATH, nil, function(success, body)
        if success then
            -- Выводим полный ответ в консоль (чтобы видеть, что приходит)
            print("[FIREBASE RAW] Response length:", #body)
            print("[FIREBASE RAW] Full response:", body)

            if body == "null" or body == "" then
                players = {}
                setDebug("Players loaded: 0 (empty)")
                return
            end

            -- Пытаемся декодировать JSON с защитой
            local ok, data = pcall(love.data.decode, "string", "json", body)
            if ok and data then
                -- Обновляем игроков
                local newPlayers = {}
                for uid, info in pairs(data) do
                    if uid ~= myUid and info.x and info.y then
                        newPlayers[uid] = { x = info.x, y = info.y, nickname = info.nickname or "???" }
                    end
                end
                players = newPlayers
                local count = 0
                for _ in pairs(players) do count = count + 1 end
                setDebug("Players loaded: " .. count)
            else
                -- Если JSON битый, показываем превью на экране и в консоли
                local preview = (body and #body > 200) and body:sub(1, 200) .. "..." or body or "(empty)"
                setDebug("Invalid JSON: " .. preview)
                print("[ERROR] Invalid JSON from Firebase, full response below:")
                print(body)
            end
        else
            setDebug("GET failed: " .. (body or "unknown"))
        end
    end)
end

function online.getPlayers()
    return players
end

function online.leave()
    if not isConnected or not myUid then return end
    local path = PATH .. myUid
    firebaseRequest("DELETE", path, nil, function()
        setDebug("Data deleted")
    end)
    isConnected = false
    players = {}
    myUid = nil
    myNickname = nil
end

-- Функция для принудительного добавления тестового игрока (для отладки)
function online.debugAddTestPlayer(nickname)
    if not nickname then nickname = "TestBot" end
    local testUid = generateUuid()
    local path = PATH .. testUid
    local data = '{"x":200,"y":300,"nickname":"' .. nickname .. '"}'
    firebaseRequest("PUT", path, data, function(success)
        if success then
            setDebug("Test player added: " .. nickname)
        else
            setDebug("Failed to add test player")
        end
    end)
end

function online.update(dt)
    if not isConnected then
        return
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

return online

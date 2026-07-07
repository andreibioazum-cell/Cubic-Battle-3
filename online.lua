-- online.lua – стабильная версия с отображением ошибок
local online = {}

local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com"
local PATH = "players/"

local myUid = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false
local debugText = "Waiting..."
local lastRawResponse = ""

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

function online.init()
    myUid = generateUuid()
    setDebug("My ID: " .. myUid)
    isConnected = true
end

function online.connect(callback)
    if isConnected then
        setDebug("Already connected")
        if callback then callback(true) end
        return
    end
    isConnected = true
    if callback then callback(true) end
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("Not connected or no UID")
        return
    end
    local path = PATH .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. '}'
    firebaseRequest("PUT", path, data, function(success, body)
        if success then
            setDebug("PUT OK")
        else
            setDebug("PUT failed: " .. (body or "unknown"))
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
            -- Сохраняем сырой ответ для отладки
            lastRawResponse = body or "(empty)"
            -- Пытаемся распарсить JSON
            local ok, data = pcall(love.data.decode, "string", "json", body)
            if ok and data then
                -- Проверяем, что data — таблица
                if type(data) == "table" then
                    local newPlayers = {}
                    for uid, pos in pairs(data) do
                        if uid ~= myUid and pos.x and pos.y then
                            newPlayers[uid] = { x = pos.x, y = pos.y }
                        end
                    end
                    players = newPlayers
                    local count = 0
                    for _ in pairs(players) do count = count + 1 end
                    setDebug("Players loaded: " .. count)
                else
                    setDebug("Response is not a table: " .. tostring(data))
                end
            else
                -- Если не удалось распарсить, показываем превью ответа
                local preview = (body and #body > 150) and body:sub(1, 150) .. "..." or (body or "(empty)")
                setDebug("Invalid JSON: " .. preview)
                print("[ERROR] Full response:", body)
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
end

function online.update(dt)
    if not isConnected then
        online.connect()
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

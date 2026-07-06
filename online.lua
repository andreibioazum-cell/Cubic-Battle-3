-- online.lua – БЕЗ АУТЕНТИФИКАЦИИ, работает с правилами .read/.write = true
local online = {}

-- ===== ТВОИ ДАННЫЕ =====
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com"
local PATH = "players/"

-- ===== СОСТОЯНИЕ =====
local myUid = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false
local debugText = "⏳ Ожидание..."

-- ===== ОТЛАДКА =====
local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

-- ===== HTTPS ЗАПРОС (без токена) =====
local function firebaseRequest(method, path, data, callback)
    local https = require("https")
    local url = DB_URL .. "/" .. path .. ".json"
    local options = {
        method = method,
        headers = { ["Content-Type"] = "application/json" },
        timeout = 5,
        verify = true,
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

-- ===== ГЕНЕРАТОР UUID (для идентификации игрока) =====
local function generateUuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = math.random(0, 15)
        if c == "x" then return string.format("%x", v)
        else return string.format("%x", math.random(8, 11))
        end
    end)
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====

function online.init()
    myUid = generateUuid()
    setDebug("🚀 Мой ID: " .. myUid)
    isConnected = true
end

function online.connect(callback)
    if isConnected then
        setDebug("✅ Уже подключены")
        if callback then callback(true) end
        return
    end
    -- В этой версии подключение происходит сразу, без аутентификации
    isConnected = true
    if callback then callback(true) end
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("⚠️ Не отправлено: нет соединения или UID")
        return
    end
    local path = PATH .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. '}'
    firebaseRequest("PUT", path, data, function(success)
        if not success then
            setDebug("⚠️ Ошибка отправки позиции")
        else
            setDebug("📤 Отправлено: " .. math.floor(x) .. "," .. math.floor(y))
        end
    end)
end

function online.fetchPlayers()
    if not isConnected then
        setDebug("⚠️ Не загружено: нет соединения")
        return
    end
    firebaseRequest("GET", PATH, nil, function(success, body)
        if success and body then
            local data = love.data.decode("json", body)
            if data then
                local newPlayers = {}
                for uid, pos in pairs(data) do
                    if uid ~= myUid and pos.x and pos.y then
                        newPlayers[uid] = { x = pos.x, y = pos.y }
                    end
                end
                players = newPlayers
                local count = 0
                for _ in pairs(players) do count = count + 1 end
                setDebug("👥 Загружено игроков: " .. count)
            else
                setDebug("⚠️ Нет данных о других игроках")
            end
        else
            setDebug("⚠️ Не удалось загрузить игроков")
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
        setDebug("🗑️ Данные удалены")
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

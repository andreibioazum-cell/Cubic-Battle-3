-- online.lua – синхронизация через Firebase с использованием firebase.lua
local firebase = require("firebase")
local online = {}

-- ===== СОСТОЯНИЕ =====
local myUid = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false

-- ===== ОТЛАДКА =====
local debugText = "⏳ Ожидание инициализации..."

local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====

function online.init()
    setDebug("🚀 Модуль online инициализирован")
    -- Инициализируем Firebase (данные из конфига)
    firebase.init({
        apiKey = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4",
        dbURL = "https://cubic-battle-3-default-rtdb.firebaseio.com",
        timeout = 3,
        verifySSL = false,  -- для Android
    })
    setDebug("✅ Firebase инициализирован")
end

function online.connect(callback)
    if isConnected then
        setDebug("✅ Уже подключены")
        if callback then callback(true) end
        return
    end
    setDebug("🔑 Запрос анонимной аутентификации...")
    firebase.authAnonymous(function(success, data)
        if success then
            myUid = data.localId
            isConnected = true
            setDebug("✅ Auth успешно! UID=" .. myUid)
            if callback then callback(true) end
        else
            setDebug("❌ Auth ошибка: " .. tostring(data))
            if callback then callback(false) end
        end
    end)
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then
        setDebug("⚠️ Не отправлено: нет соединения или UID")
        return
    end
    local path = "players/" .. myUid
    local data = { x = math.floor(x), y = math.floor(y) }
    firebase.put(path, data, function(success)
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
    firebase.get("players", function(success, data)
        if success then
            local newPlayers = {}
            if data then
                for uid, pos in pairs(data) do
                    if uid ~= myUid and pos.x and pos.y then
                        newPlayers[uid] = { x = pos.x, y = pos.y }
                    end
                end
            end
            players = newPlayers
            local count = 0
            for _ in pairs(players) do count = count + 1 end
            setDebug("👥 Загружено игроков: " .. count)
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
    local path = "players/" .. myUid
    firebase.delete(path, function()
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

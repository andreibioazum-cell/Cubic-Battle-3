-- online.lua – синхронизация через Firebase с отладкой на экране
local online = {}

-- ===== ТВОИ ДАННЫЕ =====
local API_KEY = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4"
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com"
local PATH = "players/"

-- ===== СОСТОЯНИЕ =====
local myUid = nil
local idToken = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.2
local FETCH_INTERVAL = 0.3
local isConnected = false
local authInProgress = false

-- ===== ОТЛАДОЧНЫЕ СООБЩЕНИЯ =====
local debugText = "⏳ Инициализация..."  -- Это сообщение будет видно на экране

-- Функция для обновления отладочного текста
local function setDebug(text)
    debugText = text
    print("[DEBUG] " .. text)  -- также дублируем в консоль
end

-- ===== HTTPS ОБЁРТКА =====
local function firebaseRequest(method, path, data, callback)
    if not idToken then
        setDebug("❌ Нет токена аутентификации")
        if callback then callback(false, "No auth token") end
        return
    end

    -- Проверяем наличие модуля https
    local hasHttps, https = pcall(require, "https")
    if not hasHttps then
        setDebug("❌ Модуль HTTPS не найден! Скачай APK с LÖVE 11.5")
        if callback then callback(false, "https not found") end
        return
    end

    local url = DB_URL .. "/" .. path .. ".json?auth=" .. idToken
    local options = {
        method = method,
        headers = { ["Content-Type"] = "application/json" },
        timeout = 3,
        verify = false,
    }
    if data then
        options.data = data
    end

    setDebug("📤 " .. method .. " " .. path)
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        setDebug("✅ " .. method .. " успешно (код " .. code .. ")")
        if callback then callback(true, body) end
    else
        local errMsg = "❌ Ошибка " .. tostring(code) .. " (" .. tostring(body) .. ")"
        setDebug(errMsg)
        if callback then callback(false, errMsg) end
    end
end

-- ===== АУТЕНТИФИКАЦИЯ =====
local function authenticate(callback)
    if authInProgress then
        setDebug("⏳ Аутентификация уже идёт...")
        return
    end
    if isConnected then
        setDebug("✅ Уже подключены")
        if callback then callback(true) end
        return
    end
    authInProgress = true
    setDebug("🔑 Запрос анонимного входа...")

    local hasHttps, https = pcall(require, "https")
    if not hasHttps then
        setDebug("❌ HTTPS недоступен")
        authInProgress = false
        if callback then callback(false) end
        return
    end

    local authUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" .. API_KEY
    local options = {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        data = '{"returnSecureToken":true}',
        timeout = 3,
        verify = false,
    }

    local success, code, body = pcall(https.request, authUrl, options)
    if success and code == 200 then
        local data = love.data.decode("json", body)
        if data and data.localId and data.idToken then
            myUid = data.localId
            idToken = data.idToken
            isConnected = true
            setDebug("✅ Auth успешно! UID=" .. myUid)
            if callback then callback(true) end
        else
            setDebug("❌ Ответ без UID/token")
            if callback then callback(false) end
        end
    else
        setDebug("❌ Auth ошибка: " .. tostring(code))
        if callback then callback(false) end
    end
    authInProgress = false
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====

function online.init()
    setDebug("🚀 Модуль инициализирован")
end

function online.connect(callback)
    if isConnected then
        setDebug("✅ Уже подключены")
        if callback then callback(true) end
        return
    end
    authenticate(callback)
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
                setDebug("👥 Загружено игроков: " .. #players)
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
        -- Пытаемся подключиться, если ещё не пробовали
        online.connect()
        return
    end

    -- Отправляем позицию
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

    -- Получаем данные других игроков
    fetchTimer = fetchTimer + dt
    if fetchTimer >= FETCH_INTERVAL then
        fetchTimer = 0
        online.fetchPlayers()
    end
end

-- Функция для получения отладочного текста (для отрисовки)
function online.getDebugText()
    return debugText
end

return online

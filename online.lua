-- online.lua – синхронизация через Firebase REST API (HTTPS)
local online = {}

-- ===== ТВОИ ДАННЫЕ ИЗ FIREBASE =====
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

-- ===== HTTPS ОБЁРТКА =====
local function firebaseRequest(method, path, data, callback)
    if not idToken then
        if callback then callback(false, "No auth token") end
        return
    end
    local https = require("https")
    local url = DB_URL .. "/" .. path .. ".json?auth=" .. idToken
    local options = {
        method = method,
        headers = { ["Content-Type"] = "application/json" },
        timeout = 3,
        verify = false,   -- отключаем проверку сертификата для Android
    }
    if data then
        options.data = data
    end

    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        if callback then callback(true, body) end
    else
        if callback then callback(false, "Ошибка: " .. tostring(code)) end
    end
end

-- ===== АУТЕНТИФИКАЦИЯ (анонимный вход) =====
local function authenticate(callback)
    if authInProgress then return end
    if isConnected then
        if callback then callback(true) end
        return
    end
    authInProgress = true

    local https = require("https")
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
            print("✅ Auth успешно: UID=" .. myUid)
            if callback then callback(true) end
        else
            print("❌ Auth ответ без UID/token")
            if callback then callback(false) end
        end
    else
        print("❌ Auth ошибка: " .. tostring(code))
        if callback then callback(false) end
    end
    authInProgress = false
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====
function online.init()
    print("Firebase клиент инициализирован")
end

function online.connect(callback)
    if isConnected then
        if callback then callback(true) end
        return
    end
    authenticate(callback)
end

function online.sendPosition(x, y)
    if not isConnected or not myUid then return end
    local path = PATH .. myUid
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. '}'
    firebaseRequest("PUT", path, data, function(success)
        if not success then
            print("⚠️ Ошибка отправки позиции")
        end
    end)
end

function online.fetchPlayers()
    if not isConnected then return end
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
            end
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
        print("🗑️ Данные удалены из Firebase")
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

return online

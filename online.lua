-- online.lua
-- Использует встроенный lua-https для работы с Firebase REST API
-- Работает на ПК, Android и iOS

local online = {}

-- ===== НАСТРОЙКИ =====
-- Твой URL базы данных из консоли Firebase
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com/"
local PATH = "players/" -- Путь в базе, где будут храниться игроки

-- ===== СОСТОЯНИЕ =====
local myId = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.1      -- Отправлять позицию каждые 0.1 сек
local FETCH_INTERVAL = 0.15    -- Получать данные других игроков каждые 0.15 сек
local isConnected = false

-- ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

-- Генерация уникального ID для игрока
local function generateId()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = math.random(0, 15)
        if c == "x" then return string.format("%x", v)
        else return string.format("%x", math.random(8, 11))
        end
    end)
end

-- Выполнение HTTPS-запроса к Firebase
local function firebaseRequest(method, path, data, callback)
    local https = require("https")
    local url = DB_URL .. path .. ".json"
    local options = {
        method = method,
        headers = { ["Content-Type"] = "application/json" }
    }
    if data then
        options.data = data
    end

    local success, code, body, headers = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        if callback then callback(true, body) end
    else
        if callback then callback(false, "Ошибка: " .. tostring(code)) end
    end
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====

-- Инициализация (вызывать при старте игры)
function online.init()
    if not myId then
        myId = generateId()
        print("Online: Мой ID = " .. myId)
    end
end

-- Подключение к Firebase (просто сбрасываем состояние)
function online.connect()
    isConnected = true
    print("Online: Подключено к Firebase")
end

-- Отправить свои координаты
function online.sendPosition(x, y)
    if not isConnected or not myId then return end
    local path = PATH .. myId
    local data = '{"x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. '}'
    firebaseRequest("PUT", path, data, function(success)
        if not success then
            print("Online: Ошибка отправки позиции")
        end
    end)
end

-- Получить данные всех игроков
function online.fetchPlayers()
    if not isConnected then return end
    firebaseRequest("GET", PATH, nil, function(success, body)
        if success and body then
            local data = love.data.decode("json", body)
            if data then
                local newPlayers = {}
                for id, pos in pairs(data) do
                    if id ~= myId and pos.x and pos.y then
                        newPlayers[id] = { x = pos.x, y = pos.y }
                    end
                end
                players = newPlayers
            end
        end
    end)
end

-- Получить таблицу с другими игроками
function online.getPlayers()
    return players
end

-- Выйти из игры (удалить свои данные)
function online.leave()
    if not myId then return end
    local path = PATH .. myId
    firebaseRequest("DELETE", path, nil, function(success)
        if success then
            print("Online: Данные удалены")
        end
    end)
    isConnected = false
    players = {}
end

-- Обновление (вызывать из love.update)
function online.update(dt)
    if not isConnected then return end

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

return online

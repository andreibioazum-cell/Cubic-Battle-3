-- online.lua – с отладочным выводом на экран
local online = {}

local API_KEY = "AIzaSyCe25SaGWfaQsPyje10wi_Wsmr5yHz3HE4"
local DB_URL = "https://cubic-battle-3-default-rtdb.firebaseio.com"
local PATH = "players/"

local myUid = nil
local idToken = nil
local players = {}
local sendTimer = 0
local fetchTimer = 0
local SEND_INTERVAL = 0.25
local FETCH_INTERVAL = 0.3
local isConnected = false
local authInProgress = false
local statusMessage = "Не подключено"
local playerCount = 0

local function generateUuid()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return string.gsub(template, "[xy]", function(c)
        local v = math.random(0, 15)
        if c == "x" then return string.format("%x", v)
        else return string.format("%x", math.random(8, 11))
        end
    end)
end

local function hasHttps()
    local ok, _ = pcall(require, "https")
    return ok
end

local function firebaseRequest(method, path, data, callback)
    if not idToken then
        if callback then callback(false, "No auth token") end
        return
    end
    if not hasHttps() then
        statusMessage = "ОШИБКА: нет https"
        if callback then callback(false, "https not found") end
        return
    end
    local https = require("https")
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

    statusMessage = "Запрос: " .. method .. " " .. path
    local success, code, body = pcall(https.request, url, options)
    if success and code and code >= 200 and code < 300 then
        statusMessage = "✅ " .. method .. " OK (" .. code .. ")"
        if callback then callback(true, body) end
    else
        statusMessage = "❌ Ошибка " .. tostring(code)
        if callback then callback(false, "Ошибка: " .. tostring(code)) end
    end
end

local function authenticate(callback)
    if authInProgress then return end
    if isConnected then
        if callback then callback(true) end
        return
    end
    authInProgress = true

    if not hasHttps() then
        statusMessage = "Нет https!"
        if callback then callback(false) end
        return
    end

    local https = require("https")
    local authUrl = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=" .. API_KEY
    local options = {
        method = "POST",
        headers = { ["Content-Type"] = "application/json" },
        data = '{"returnSecureToken":true}',
        timeout = 3,
        verify = false,
    }

    statusMessage = "Аутентификация..."
    local success, code, body = pcall(https.request, authUrl, options)
    if success and code == 200 then
        local data = love.data.decode("json", body)
        if data and data.localId and data.idToken then
            myUid = data.localId
            idToken = data.idToken
            isConnected = true
            statusMessage = "✅ Auth OK, UID=" .. string.sub(myUid,1,8)
            if callback then callback(true) end
        else
            statusMessage = "❌ Auth нет UID"
            if callback then callback(false) end
        end
    else
        statusMessage = "❌ Auth ошибка " .. tostring(code)
        if callback then callback(false) end
    end
    authInProgress = false
end

function online.init()
    statusMessage = "Модуль инициализирован"
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
            statusMessage = "⚠️ Ошибка PUT"
        end
    end)
end

function online.fetchPlayers()
    if not isConnected then return end
    firebaseRequest("GET", PATH, nil, function(success, body)
        if success and body then
            local data = love.data.decode("json", body)
            if data then
                local count = 0
                for uid, pos in pairs(data) do
                    if uid ~= myUid and pos.x and pos.y then
                        count = count + 1
                        if players[uid] then
                            players[uid].targetX = pos.x
                            players[uid].targetY = pos.y
                            players[uid].lerpTimer = 0
                        else
                            players[uid] = {
                                x = pos.x, y = pos.y,
                                targetX = pos.x, targetY = pos.y,
                                lerpTimer = 0
                            }
                        end
                    end
                end
                playerCount = count
                -- удаляем ушедших
                for uid, _ in pairs(players) do
                    if not data[uid] then players[uid] = nil end
                end
                statusMessage = "Игроков: " .. playerCount
            end
        else
            statusMessage = "❌ GET ошибка"
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
        statusMessage = "🗑️ Удалён"
    end)
    isConnected = false
    players = {}
end

function online.update(dt)
    if not isConnected then
        online.connect()
        return
    end

    -- интерполяция
    for uid, p in pairs(players) do
        p.lerpTimer = p.lerpTimer + dt * 2.5
        if p.lerpTimer > 1 then p.lerpTimer = 1 end
        local t = p.lerpTimer
        local smooth = t * t * (3 - 2 * t)
        p.x = p.x + (p.targetX - p.x) * smooth
        p.y = p.y + (p.targetY - p.y) * smooth
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

-- функция для отображения статуса на экране
function online.drawStatus()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Online: " .. statusMessage, 10, love.graphics.getHeight() - 40)
    love.graphics.print("Игроков: " .. playerCount, 10, love.graphics.getHeight() - 20)
end

return online

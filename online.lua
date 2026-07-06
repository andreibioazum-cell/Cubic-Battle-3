-- online.lua – WebSocket клиент для LÖVE (без внешних библиотек)
-- Подключается к серверу на Python (QPython) через ws://
local online = {}

-- ===== НАСТРОЙКИ =====
-- ЗАМЕНИ НА РЕАЛЬНЫЙ IP И ПОРТ СЕРВЕРА (который показал QPython)
local SERVER_URL = "ws://192.168.0.102:8080"   -- пример, поменяй на свой

-- ===== СОСТОЯНИЕ =====
local ws = nil
local connected = false
local myId = nil
local players = {}
local sendTimer = 0
local SEND_INTERVAL = 0.2   -- отправка позиции каждые 0.2 сек

-- ===== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ =====

-- Base64 (для WebSocket handshake)
local function base64(data)
    local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
    local padding = 2 - (string.len(data) % 3)
    if padding == 3 then padding = 0 end
    local result = {}
    for i = 1, string.len(data), 3 do
        local a, b, c = string.byte(data, i, i+2)
        local n = (a or 0) * 65536 + (b or 0) * 256 + (c or 0)
        for j = 1, 4 do
            local idx = (n >> (6*(4-j))) & 0x3F
            table.insert(result, b64chars:sub(idx+1, idx+1))
        end
    end
    for i = 1, padding do
        result[#result] = '='
    end
    return table.concat(result)
end

-- ===== ВСТРОЕННЫЙ WEBSOCKET КЛИЕНТ =====
local function websocket_connect(url, onOpen, onMessage, onClose)
    local socket = require("socket")
    -- Парсим URL
    local host, port, path = url:match("ws://([^:/]+)(%d*)(.*)")
    if not host then return nil, "Invalid URL" end
    if port == "" then port = 80 else port = tonumber(port) end
    if path == "" then path = "/" end

    local client = socket.tcp()
    client:settimeout(3)
    local ok, err = client:connect(host, port)
    if not ok then return nil, err end

    -- Генерируем ключ
    local key = string.gsub(
        ("%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c"):rep(4),
        "%c",
        function() return string.char(math.random(0, 255)) end
    )
    local acceptKey = base64(key)

    -- Handshake
    local handshake = string.format(
        "GET %s HTTP/1.1\r\n" ..
        "Host: %s\r\n" ..
        "Upgrade: websocket\r\n" ..
        "Connection: Upgrade\r\n" ..
        "Sec-WebSocket-Key: %s\r\n" ..
        "Sec-WebSocket-Version: 13\r\n" ..
        "\r\n",
        path, host, acceptKey
    )
    client:send(handshake)

    -- Читаем ответ
    local response = ""
    while true do
        local line, err = client:receive("*l")
        if not line then break end
        response = response .. line .. "\r\n"
        if line == "" then break end
    end

    if not response:match("HTTP/1.1 101") then
        client:close()
        return nil, "Handshake failed"
    end

    if onOpen then onOpen() end

    -- Отправка фрейма
    local function sendFrame(data)
        local frame = string.char(0x82) -- FIN + opcode text
        local len = #data
        if len < 126 then
            frame = frame .. string.char(0x80 + len)
        elseif len < 65536 then
            frame = frame .. string.char(0x80 + 126) .. string.pack(">I2", len)
        else
            frame = frame .. string.char(0x80 + 127) .. string.pack(">I8", len)
        end
        -- Маска (клиент обязан маскировать)
        local mask = string.char(math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255))
        frame = frame .. mask
        local masked = ""
        for i = 1, len do
            masked = masked .. string.char(string.byte(data, i) ~ string.byte(mask, (i-1)%4 + 1))
        end
        frame = frame .. masked
        client:send(frame)
    end

    -- Получение фреймов (неблокирующее)
    local function receiveFrames()
        while true do
            local byte1, err = client:receive(1)
            if not byte1 then break end
            local opcode = string.byte(byte1) & 0x0F
            if opcode == 0x8 then -- close
                client:close()
                if onClose then onClose() end
                return
            end
            local byte2 = client:receive(1)
            local len = string.byte(byte2) & 0x7F
            if len == 126 then
                len = string.unpack(">I2", client:receive(2))
            elseif len == 127 then
                len = string.unpack(">I8", client:receive(8))
            end
            -- Маска (сервер не маскирует, но мы пропускаем 4 байта)
            local mask = client:receive(4) -- просто читаем, не используем
            local payload = client:receive(len)
            if payload then
                if opcode == 0x1 then -- text
                    if onMessage then onMessage(payload) end
                end
            end
        end
    end

    return {
        send = sendFrame,
        receive = receiveFrames,
        close = function() client:close() end,
        socket = client
    }
end

-- ===== ПУБЛИЧНЫЕ ФУНКЦИИ =====

function online.init()
    print("WebSocket клиент инициализирован")
end

function online.connect()
    if connected then
        print("Уже подключены")
        return
    end
    ws = websocket_connect(SERVER_URL,
        function() -- onOpen
            print("✅ Подключено к серверу")
            connected = true
        end,
        function(msg) -- onMessage
            local ok, data = pcall(love.data.decode, "json", msg)
            if ok and data then
                if data.type == "init" then
                    myId = data.id
                    print("Мой ID: " .. myId)
                elseif data.type == "join" then
                    players[data.id] = { x = data.x, y = data.y }
                    print("➕ Игрок " .. data.id .. " присоединился")
                elseif data.type == "move" then
                    if players[data.id] then
                        players[data.id].x = data.x
                        players[data.id].y = data.y
                    else
                        players[data.id] = { x = data.x, y = data.y }
                    end
                elseif data.type == "leave" then
                    players[data.id] = nil
                    print("➖ Игрок " .. data.id .. " ушёл")
                end
            end
        end,
        function() -- onClose
            connected = false
            ws = nil
            print("❌ Соединение разорвано")
        end
    )
    if not ws then
        print("❌ Не удалось подключиться к серверу")
    end
end

function online.sendPosition(x, y)
    if not connected or not ws or not myId then return end
    local msg = '{"type":"move","x":' .. math.floor(x) .. ',"y":' .. math.floor(y) .. '}'
    ws.send(msg)
end

function online.receive()
    if connected and ws then
        ws.receive()
    end
end

function online.getPlayers()
    return players
end

function online.leave()
    if ws then ws.close() end
    connected = false
    players = {}
end

function online.update(dt)
    if not connected then
        -- Пытаемся переподключиться, если ещё не подключены
        online.connect()
        return
    end
    -- Принимаем входящие сообщения
    online.receive()

    -- Отправляем свою позицию
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
end

return online

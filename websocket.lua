-- websocket.lua
-- Простой WebSocket-клиент на Lua (RFC 6455), использует luasocket
-- Поддерживает только текстовые сообщения, без фрагментации, без шифрования (ws://)

local socket = require("socket")
local base64 = require("base64")  -- нужно скачать base64.lua (или использовать свою реализацию)
local sha1 = require("sha1")      -- нужно скачать sha1.lua

local websocket = {}

local function handshake(host, port, path, key)
    local request = "GET " .. path .. " HTTP/1.1\r\n" ..
                    "Host: " .. host .. "\r\n" ..
                    "Upgrade: websocket\r\n" ..
                    "Connection: Upgrade\r\n" ..
                    "Sec-WebSocket-Key: " .. key .. "\r\n" ..
                    "Sec-WebSocket-Version: 13\r\n" ..
                    "\r\n"
    return request
end

local function generateKey()
    local bytes = ""
    for i = 1, 16 do
        bytes = bytes .. string.char(math.random(0, 255))
    end
    return base64.encode(bytes)
end

local function computeAccept(key)
    local magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    local sha = sha1(key .. magic, true)
    return base64.encode(sha)
end

function websocket.connect(url)
    -- url: ws://host:port/path
    local host, port, path = url:match("ws://([^:/]+):?(%d*)(.*)")
    if not host then
        error("Invalid WebSocket URL")
    end
    if port == "" then port = 80 end
    if path == "" then path = "/" end

    local sock = socket.tcp()
    sock:settimeout(5)
    local ok, err = sock:connect(host, tonumber(port))
    if not ok then return nil, err end

    local key = generateKey()
    local req = handshake(host, port, path, key)
    sock:send(req)

    local response, err = sock:receive("*l")
    if not response then return nil, err end
    if not response:match("101") then
        return nil, "Handshake failed"
    end

    -- Читаем заголовки до пустой строки
    while true do
        local line, err = sock:receive("*l")
        if not line then break end
        if line == "" then break end
    end

    -- Здесь можно проверить Sec-WebSocket-Accept, но пропустим

    return sock
end

function websocket.send(sock, data)
    local frame = {}
    -- FIN=1, opcode=0x1 (текст)
    table.insert(frame, string.char(0x81))
    local len = #data
    if len <= 125 then
        table.insert(frame, string.char(0x80 | len))  -- mask=1
    elseif len <= 65535 then
        table.insert(frame, string.char(0x80 | 126))
        table.insert(frame, string.char((len >> 8) & 0xFF))
        table.insert(frame, string.char(len & 0xFF))
    else
        table.insert(frame, string.char(0x80 | 127))
        -- 8 байт длины (для простоты только 4 байта)
        table.insert(frame, string.char(0, 0, 0, 0))
        table.insert(frame, string.char((len >> 24) & 0xFF))
        table.insert(frame, string.char((len >> 16) & 0xFF))
        table.insert(frame, string.char((len >> 8) & 0xFF))
        table.insert(frame, string.char(len & 0xFF))
    end
    -- Маскирующий ключ (4 байта)
    local maskKey = string.char(math.random(0,255), math.random(0,255), math.random(0,255), math.random(0,255))
    table.insert(frame, maskKey)
    -- Маскируем данные
    local masked = {}
    for i = 1, #data do
        local byte = data:byte(i)
        local maskByte = maskKey:byte((i-1) % 4 + 1)
        table.insert(masked, string.char(byte ~ maskByte))
    end
    table.insert(frame, table.concat(masked))
    return sock:send(table.concat(frame))
end

function websocket.receive(sock)
    -- Читаем заголовок (2 байта)
    local header, err = sock:receive(2)
    if not header then return nil, err end
    local b1, b2 = header:byte(1), header:byte(2)
    local opcode = b1 & 0x0F
    local masked = (b2 & 0x80) ~= 0
    local payloadLen = b2 & 0x7F

    if payloadLen == 126 then
        local lenBytes, err = sock:receive(2)
        if not lenBytes then return nil, err end
        payloadLen = (lenBytes:byte(1) << 8) | lenBytes:byte(2)
    elseif payloadLen == 127 then
        local lenBytes, err = sock:receive(8)
        if not lenBytes then return nil, err end
        -- просто берём первые 4 байта (для простоты)
        payloadLen = 0
        for i = 1, 4 do
            payloadLen = (payloadLen << 8) | lenBytes:byte(i)
        end
    end

    local maskKey
    if masked then
        maskKey, err = sock:receive(4)
        if not maskKey then return nil, err end
    end

    local payload, err = sock:receive(payloadLen)
    if not payload then return nil, err end

    if masked then
        local unmasked = {}
        for i = 1, #payload do
            local byte = payload:byte(i)
            local maskByte = maskKey:byte((i-1) % 4 + 1)
            table.insert(unmasked, string.char(byte ~ maskByte))
        end
        payload = table.concat(unmasked)
    end

    if opcode == 0x8 then  -- закрытие
        return nil, "closed"
    end

    return payload
end

return websocket

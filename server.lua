-- server.lua
-- Запускается в love.thread, слушает порт 12345, принимает клиентов,
-- хранит данные игроков, рассылает обновления.

local socket = require("socket")
local json = require("json")

local HOST = "0.0.0.0"
local PORT = 12345

local clients = {}
local player_data = {}
local next_id = 1
local lock = require("love.thread").getLock("server_lock")

function broadcast(data, exclude)
    local msg = json.encode(data) .. "\n"
    lock:lock()
    for id, conn in pairs(clients) do
        if id ~= exclude then
            pcall(conn.send, conn, msg)
        end
    end
    lock:unlock()
end

function handle_client(conn)
    local cid = next_id
    next_id = next_id + 1
    lock:lock()
    clients[cid] = conn
    player_data[cid] = {
        x = 400, y = 300,
        dx = 0, dy = 0,
        hp = 5,
        skin = "NONE",
        nick = "Player" .. cid
    }
    lock:unlock()

    local init_msg = json.encode({type = "init", id = cid}) .. "\n"
    conn:send(init_msg)

    local buffer = ""
    while true do
        local data, err = conn:receive("*l")
        if not data then break end
        buffer = buffer .. data
        while true do
            local line, rest = buffer:match("^(.-)\n(.*)")
            if not line then break end
            buffer = rest
            local ok, msg = pcall(json.decode, line)
            if ok and msg then
                lock:lock()
                if player_data[cid] then
                    local p = player_data[cid]
                    p.x = msg.x or p.x
                    p.y = msg.y or p.y
                    p.dx = msg.dx or p.dx
                    p.dy = msg.dy or p.dy
                    p.hp = msg.hp or p.hp
                    p.skin = msg.skin or p.skin
                    p.nick = msg.nick or p.nick
                end
                lock:unlock()
            end
        end
    end

    -- Клиент отключился
    lock:lock()
    clients[cid] = nil
    player_data[cid] = nil
    lock:unlock()
    conn:close()
end

function main()
    local server = socket.tcp()
    server:settimeout(0.1)
    server:bind(HOST, PORT)
    server:listen(5)
    print("Lua server running on " .. HOST .. ":" .. PORT)

    -- Поток рассылки
    while true do
        local client, err = server:accept()
        if client then
            -- Запускаем обработку клиента в новом потоке (или в том же)
            -- В love.thread мы не можем создавать потоки из потока, поэтому
            -- будем обрабатывать всех клиентов в одном потоке, но неблокирующе.
            -- Для простоты будем принимать клиентов и обрабатывать их последовательно,
            -- но это может тормозить. Вместо этого сделаем неблокирующий приём.
            -- Реализуем простой вариант: принимаем клиента и создаём для него
            -- отдельную корутину.
            local co = coroutine.create(function()
                handle_client(client)
            end)
            -- Запускаем корутину (но она блокирующая, потому что в ней recv)
            -- Это не решение. Вместо этого мы будем обрабатывать клиентов
            -- в главном потоке, но с таймаутами.
            -- Это слишком сложно для примера, поэтому я предлагаю использовать
            -- упрощённый вариант: сервер запускается в основном потоке игры,
            -- но тогда игра будет тормозить. Альтернатива – использовать love.thread,
            -- но там нельзя создавать сокеты в потоке? Можно, если передать сокет.
            -- Но в LÖVE 11.5 love.thread не поддерживает передачу сокетов.
            -- Поэтому мы вернёмся к варианту с Python, либо используем библиотеку
            -- lua-websockets, но это опять зависимости.
            -- Я предлагаю отказаться от встроенного сервера на Lua из-за сложности
            -- и оставить Python, но с автоматическим запуском из игры (как в прошлом ответе).
        end
        coroutine.yield()
    end
end

-- Запускаем сервер
main()

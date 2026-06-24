local multiplayer = {}

local json = require("json")
local controls = require("controls")

local socket_ok, socket = pcall(require, "socket")

local SERVER_HOST = "127.0.0.1"
local SERVER_PORT = 12345

local tcp = nil
local connected = false
local playerId = nil
local players = {}
local localPlayer = { x = 400, y = 300, dx = 0, dy = 0, hp = 5, skin = "NONE" }
local sendTimer = 0
local SEND_INTERVAL = 0.05
local errorMessage = nil

function multiplayer.connect()
    if connected then return true end
    if not socket_ok then
        errorMessage = "LuaSocket not installed!\nPlease install luasocket for multiplayer."
        return false
    end
    tcp = socket.tcp()
    tcp:settimeout(0.1)
    local ok, err = tcp:connect(SERVER_HOST, SERVER_PORT)
    if not ok then
        errorMessage = "Cannot connect to server.\nMake sure server is running."
        return false
    end
    connected = true
    errorMessage = nil
    print("Connected to server")
    return true
end

function multiplayer.load()
    local skin = SAVE_DATA and SAVE_DATA.equippedSkin or "NONE"
    localPlayer.skin = skin
    if not multiplayer.connect() then
        -- Если не удалось подключиться, возвращаемся в лобби через 1 секунду
        love.timer.sleep(0.5)
        GameState.current = "lobby"
    end
end

function multiplayer.update(dt)
    if not connected then
        return
    end

    -- Защита от ошибок при отправке/приёме
    local success, err = pcall(function()
        local moveX, moveY = controls.getMove()
        local aimX, aimY = controls.getAim()
        local shot, _, _ = controls.getShot()

        localPlayer.x = localPlayer.x + moveX * 260 * dt
        localPlayer.y = localPlayer.y + moveY * 260 * dt
        local w, h = love.graphics.getDimensions()
        localPlayer.x = math.max(30, math.min(w - 30, localPlayer.x))
        localPlayer.y = math.max(30, math.min(h - 30, localPlayer.y))

        if moveX ~= 0 or moveY ~= 0 then
            localPlayer.dx = moveX
            localPlayer.dy = moveY
        end

        sendTimer = sendTimer - dt
        if sendTimer <= 0 then
            sendTimer = SEND_INTERVAL
            local data = {
                x = localPlayer.x,
                y = localPlayer.y,
                dx = localPlayer.dx,
                dy = localPlayer.dy,
                hp = localPlayer.hp,
                skin = localPlayer.skin,
                shot = shot or false,
                aimX = aimX or 0,
                aimY = aimY or -1
            }
            local msg = json.encode(data) .. "\n"
            tcp:send(msg)
        end

        -- Приём данных
        while true do
            local chunk, err = tcp:receive("*l")
            if not chunk then
                if err ~= "timeout" then
                    connected = false
                    errorMessage = "Connection lost"
                end
                break
            end
            local ok, parsed = pcall(json.decode, chunk)
            if ok and parsed then
                if parsed.type == "init" then
                    playerId = parsed.id
                    print("Player ID:", playerId)
                elseif parsed.type == "update" then
                    players = parsed.players or {}
                    if playerId and players[playerId] then
                        local p = players[playerId]
                        localPlayer.x = p.x
                        localPlayer.y = p.y
                        localPlayer.dx = p.dx
                        localPlayer.dy = p.dy
                        localPlayer.hp = p.hp
                        localPlayer.skin = p.skin
                    end
                end
            end
        end
    end)
    if not success then
        -- Если произошла ошибка, закрываем соединение и возвращаемся
        print("Multiplayer error:", err)
        if tcp then tcp:close() end
        connected = false
        GameState.current = "lobby"
    end
end

function multiplayer.draw()
    love.graphics.setColor(0.15, 0.15, 0.25, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    if errorMessage then
        love.graphics.setColor(1, 0.6, 0.6, 1)
        love.graphics.printf(errorMessage, 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
        love.graphics.setColor(1,1,1,1)
        love.graphics.printf("Press ESC to return", 0, love.graphics.getHeight()/2 + 30, love.graphics.getWidth(), "center")
        return
    end

    -- Рисуем других игроков
    for id, p in pairs(players) do
        if id ~= playerId then
            love.graphics.setColor(0.8, 0.3, 0.3, 1)
            love.graphics.rectangle("fill", p.x - 25, p.y - 25, 50, 50)
            love.graphics.setColor(1,1,1,1)
            love.graphics.print("P" .. id, p.x - 10, p.y - 10)
        end
    end

    -- Локальный игрок
    love.graphics.setColor(0.3, 0.8, 0.3, 1)
    love.graphics.rectangle("fill", localPlayer.x - 25, localPlayer.y - 25, 50, 50)
    love.graphics.setColor(1,1,1,1)
    love.graphics.print("YOU", localPlayer.x - 15, localPlayer.y - 10)

    controls.draw()

    love.graphics.setColor(1,1,1,1)
    love.graphics.print("Connected", 10, 10)
    if playerId then
        love.graphics.print("ID: " .. playerId, 10, 30)
    end
    love.graphics.print("Players online: " .. #players, 10, 50)
end

function multiplayer.touchpressed(id, x, y)
    controls.touchpressed(id, x, y)
end

function multiplayer.touchmoved(id, x, y)
    controls.touchmoved(id, x, y)
end

function multiplayer.touchreleased(id, x, y)
    controls.touchreleased(id, x, y)
end

function multiplayer.keypressed(key)
    controls.keypressed(key)
    if key == "escape" then
        if tcp then tcp:close() end
        connected = false
        GameState.current = "lobby"
        playButtonSound()
    end
end

function multiplayer.keyreleased(key)
    controls.keyreleased(key)
end

return multiplayer

local multiplayer = {}

local json = require("json")
local installer = require("installer")
local controls = require("controls")   -- <-- ДОБАВЛЯЕМ ЭТУ СТРОКУ

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
local showError = false
local errorMessage = ""
local showInstructions = false

function multiplayer.connect(host, port)
    if connected then return true end
    if installer.isMobile() then
        showError = true
        showInstructions = true
        errorMessage = "Multiplayer is not supported on mobile devices.\nPlease play Singleplayer."
        return false
    end
    if not socket_ok then
        showError = true
        showInstructions = true
        errorMessage = installer.getInstructions()
        return false
    end
    host = host or SERVER_HOST
    port = port or SERVER_PORT
    tcp = socket.tcp()
    tcp:settimeout(0.1)
    local ok, err = tcp:connect(host, port)
    if not ok then
        showError = true
        showInstructions = false
        errorMessage = "Cannot connect to " .. host .. ":" .. port .. "\n" .. tostring(err)
        return false
    end
    connected = true
    showError = false
    showInstructions = false
    print("Connected to server")
    return true
end

function multiplayer.load()
    local skin = SAVE_DATA and SAVE_DATA.equippedSkin or "NONE"
    localPlayer.skin = skin
    multiplayer.connect()
end

function multiplayer.update(dt)
    if not connected then
        if not showError then
            multiplayer.connect()
        end
        return
    end

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
        local sent, err = tcp:send(msg)
        if not sent then
            connected = false
            tcp:close()
            showError = true
            showInstructions = false
            errorMessage = "Connection lost"
        end
    end

    while true do
        local chunk, err = tcp:receive("*l")
        if not chunk then
            if err ~= "timeout" then
                connected = false
                tcp:close()
                showError = true
                showInstructions = false
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
end

function multiplayer.draw()
    love.graphics.setColor(0.15, 0.15, 0.25, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    if showError then
        love.graphics.setColor(1, 0.6, 0.6, 1)
        if showInstructions then
            love.graphics.printf(errorMessage, 50, love.graphics.getHeight()/2 - 150, love.graphics.getWidth() - 100, "center")
            love.graphics.setColor(1,1,1,1)
            love.graphics.printf("Press ESC to return", 0, love.graphics.getHeight()/2 + 100, love.graphics.getWidth(), "center")
        else
            love.graphics.printf(errorMessage, 0, love.graphics.getHeight()/2 - 20, love.graphics.getWidth(), "center")
            love.graphics.setColor(1,1,1,1)
            love.graphics.printf("Press ESC to return", 0, love.graphics.getHeight()/2 + 30, love.graphics.getWidth(), "center")
        end
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

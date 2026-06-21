local lobby = require("lobby")
local game = require("game")
local controls = require("controls")

GameState = { current = "lobby" }

local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local lastTap = 0
local lastState = nil
local shotCooldown = 0
local SHOT_DELAY = 0.15

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    controls.load()
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

    if GameState.current ~= lastState then
        if GameState.current == "lobby" and lobby.load then lobby.load() end
        if GameState.current == "game"  and game.load  then game.load()  end
        lastState = GameState.current
    end

    if GameState.current == "lobby" then
        lobby.update(dt)
    elseif GameState.current == "game" then
        controls.update(dt)
        
        if shotCooldown > 0 then
            shotCooldown = shotCooldown - dt
        end
        
        -- Выстрел с клавиатуры (ПК)
        local shot, dx, dy = controls.getShot()
        if shot and shotCooldown <= 0 and game.spawnPlayerBullet then
            game.spawnPlayerBullet(dx, dy)
            shotCooldown = SHOT_DELAY
        end
        
        game.update(dt)
    end

    if GameState.current ~= lastState then
        if GameState.current == "lobby" and lobby.load then lobby.load() end
        if GameState.current == "game"  and game.load  then game.load()  end
        lastState = GameState.current
    end
end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "game" then
        game.draw()
        controls.draw()
    end
end

function love.resize(w, h)
    if lobby.resize then lobby.resize(w, h) end
    if game.resize  then game.resize(w, h)  end
    controls.resize()
end

-- ========== КЛАВИАТУРА ==========
function love.keypressed(key)
    if GameState.current == "game" then
        controls.keypressed(key)
    end
    
    if key == "escape" then
        GameState.current = "lobby"
    end
end

function love.keyreleased(key)
    if GameState.current == "game" then
        controls.keyreleased(key)
    end
end

-- ========== ТАЧ / МЫШЬ ==========
local function dispatch(fn, id, x, y)
    local s = GameState.current
    if s == "lobby" and lobby[fn] then lobby[fn](id, x, y)
    elseif s == "game" and game[fn] then game[fn](id, x, y) end
end

function love.touchpressed(id, x, y)
    local now = love.timer.getTime()
    if now - lastTap < 0.05 then return end
    lastTap = now
    
    if GameState.current == "game" then
        controls.touchpressed(id, x, y)
    end
    
    dispatch("touchpressed", id, x, y)
end

function love.touchmoved(id, x, y)
    if GameState.current == "game" then
        controls.touchmoved(id, x, y)
    end
    dispatch("touchmoved", id, x, y)
end

function love.touchreleased(id, x, y)
    if GameState.current == "game" then
        local shot, dx, dy = controls.touchreleased(id)
        if shot and game.spawnPlayerBullet then
            game.spawnPlayerBullet(dx, dy)
        end
    end
    dispatch("touchreleased", id, x, y)
end

-- МЫШЬ для ПК
function love.mousepressed(x, y, button, istouch)
    if isMobile or istouch then return end
    if button == 1 then
        love.touchpressed(1, x, y)
    end
end

function love.mousemoved(x, y)
    if isMobile then return end
    if love.mouse.isDown(1) then love.touchmoved(1, x, y) end
end

function love.mousereleased(x, y, button, istouch)
    if isMobile or istouch then return end
    if button == 1 then
        love.touchreleased(1, x, y)
    end
end

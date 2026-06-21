local lobby = require("lobby")
local game = require("game")

GameState = { current = "lobby" }

local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local lastTap = 0
local lastState = nil

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
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
        game.update(dt)
    end
end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "game" then
        game.draw()
    end
end

function love.resize(w, h)
    if lobby.resize then lobby.resize(w, h) end
    if game.resize  then game.resize(w, h)  end
end

local function dispatch(fn, id, x, y)
    local s = GameState.current
    if s == "lobby" and lobby[fn] then lobby[fn](id, x, y)
    elseif s == "game" and game[fn] then game[fn](id, x, y) end
end

function love.touchpressed(id, x, y)
    local now = love.timer.getTime()
    if now - lastTap < 0.05 then return end
    lastTap = now
    dispatch("touchpressed", id, x, y)
end

function love.touchmoved(id, x, y)
    dispatch("touchmoved", id, x, y)
end

function love.touchreleased(id, x, y)
    dispatch("touchreleased", id, x, y)
end

function love.mousepressed(x, y)
    if isMobile then return end
    love.touchpressed(1, x, y)
end

function love.mousemoved(x, y)
    if isMobile then return end
    if love.mouse.isDown(1) then love.touchmoved(1, x, y) end
end

function love.mousereleased(x, y)
    if isMobile then return end
    love.touchreleased(1, x, y)
end

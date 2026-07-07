-- main.lua
local lobby = require("lobby")
local game = require("game")
local controls = require("controls")
local shop = require("shop")
local credits = require("credits")
local settings = require("settings")
local mode_select = require("mode_select")
local difficulty = require("difficulty")
local online = require("online")
local room = require("room")   -- новый модуль

GameState = { current = "lobby" }

local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local lastTap = 0
local lastState = nil
local shotCooldown = 0
local SHOT_DELAY = 0.15

-- ЗВУКИ И МУЗЫКА (оставь как есть)
-- ...

function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    loadSave()
    controls.load()
    loadMusic()
    online.init()
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

    if GameState.current ~= lastState then
        print("Switch to: " .. tostring(GameState.current))
        if GameState.current == "lobby" then
            if lobby.load then lobby.load() end
        elseif GameState.current == "mode_select" then
            if mode_select.load then mode_select.load() end
        elseif GameState.current == "difficulty" then
            if difficulty.load then difficulty.load() end
        elseif GameState.current == "game" then
            if game.load then game.load() end
        elseif GameState.current == "online" then
            if game.load then game.load() end
            local nickname = SAVE_DATA.nickname or "Player"
            online.init(nickname, function(success, msg)
                if success then
                    print("Online started as " .. nickname)
                else
                    print("Online error:", msg)
                end
            end)
        elseif GameState.current == "room" then
            if room.load then room.load() end
        elseif GameState.current == "shop" then
            if shop.load then shop.load(SAVE_DATA) end
        elseif GameState.current == "credits" then
            if credits.load then credits.load() end
        elseif GameState.current == "settings" then
            if settings.load then settings.load() end
        end
        lastState = GameState.current
    end

    if GameState.current == "lobby" then
        lobby.update(dt)
    elseif GameState.current == "game" then
        game.update(dt)
        controls.update(dt)
        if shotCooldown > 0 then
            shotCooldown = shotCooldown - dt
        end
        local shot, dx, dy = controls.getShot()
        if shot and shotCooldown <= 0 and game.spawnPlayerBullet then
            game.spawnPlayerBullet(dx, dy)
            shotCooldown = SHOT_DELAY
        end
    elseif GameState.current == "online" then
        if game.getPlayerPosition then
            local x, y = game.getPlayerPosition()
            online.onSendPosition = function() return x, y end
        end
        online.update(dt)
        game.update(dt)
        controls.update(dt)
        if shotCooldown > 0 then
            shotCooldown = shotCooldown - dt
        end
        local shot, dx, dy = controls.getShot()
        if shot and shotCooldown <= 0 and game.spawnPlayerBullet then
            game.spawnPlayerBullet(dx, dy)
            shotCooldown = SHOT_DELAY
        end
    elseif GameState.current == "room" then
        -- ничего не обновляем
    end
end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "mode_select" then
        mode_select.draw()
    elseif GameState.current == "difficulty" then
        difficulty.draw()
    elseif GameState.current == "game" or GameState.current == "online" then
        game.draw()
        controls.draw()
    elseif GameState.current == "room" then
        room.draw()
    elseif GameState.current == "shop" then
        shop.draw(SAVE_DATA.coins)
    elseif GameState.current == "credits" then
        credits.draw()
    elseif GameState.current == "settings" then
        settings.draw()
    end
end

function love.resize(w, h)
    if lobby.resize then lobby.resize(w, h) end
    if mode_select.resize then mode_select.resize(w, h) end
    if difficulty.resize then difficulty.resize(w, h) end
    if game.resize then game.resize(w, h) end
    if shop.resize then shop.resize() end
    if credits.resize then credits.resize() end
    if settings.resize then settings.resize() end
    controls.resize()
end

function love.keypressed(key)
    if GameState.current == "game" or GameState.current == "online" then
        controls.keypressed(key)
    elseif GameState.current == "settings" and settings.keypressed then
        settings.keypressed(key)
    elseif GameState.current == "room" and room.keypressed then
        room.keypressed(key)
    end

    if key == "escape" then
        if GameState.current == "game" then
            online.leave()
            GameState.current = "lobby"
            playButtonSound()
        elseif GameState.current == "online" then
            online.leave()
            GameState.current = "lobby"
            playButtonSound()
        elseif GameState.current == "room" then
            GameState.current = "lobby"
            playButtonSound()
        elseif GameState.current == "mode_select" then
            GameState.current = "lobby"
            playButtonSound()
        elseif GameState.current == "difficulty" then
            GameState.current = "mode_select"
            playButtonSound()
        end
    end
    if key == "m" then
        toggleMusic()
        SAVE_SAVE()
        playButtonSound()
    end
end

function love.keyreleased(key)
    if GameState.current == "game" or GameState.current == "online" then
        controls.keyreleased(key)
    end
end

function love.textinput(t)
    if GameState.current == "settings" and settings.textinput then
        settings.textinput(t)
    elseif GameState.current == "room" and room.textinput then
        room.textinput(t)
    end
end

-- ===== DISPATCHER =====
local function dispatch(fn, ...)
    local s = GameState.current
    if s == "lobby" and lobby[fn] then
        lobby[fn](...)
    elseif s == "mode_select" and mode_select[fn] then
        mode_select[fn](...)
    elseif s == "difficulty" and difficulty[fn] then
        difficulty[fn](...)
    elseif s == "game" and game[fn] then
        game[fn](...)
    elseif s == "online" and game[fn] then
        game[fn](...)
    elseif s == "room" and room[fn] then
        room[fn](...)
    elseif s == "shop" and shop[fn] then
        if fn == "touchpressed" then
            local id, x, y = ...
            local newCoins, changed = shop.touchpressed(id, x, y, SAVE_DATA.coins, SAVE_DATA)
            if changed or newCoins ~= SAVE_DATA.coins then
                SAVE_DATA.coins = newCoins
                SAVE_SAVE()
            end
        else
            shop[fn](...)
        end
    elseif s == "credits" and credits[fn] then
        credits[fn](...)
    elseif s == "settings" and settings[fn] then
        settings[fn](...)
    end
end

function love.touchpressed(id, x, y)
    local now = love.timer.getTime()
    if now - lastTap < 0.05 then return end
    lastTap = now

    if GameState.current == "game" or GameState.current == "online" then
        controls.touchpressed(id, x, y)
    end

    dispatch("touchpressed", id, x, y)
end

function love.touchmoved(id, x, y)
    if GameState.current == "game" or GameState.current == "online" then
        controls.touchmoved(id, x, y)
    end
    dispatch("touchmoved", id, x, y)
end

function love.touchreleased(id, x, y)
    if GameState.current == "game" or GameState.current == "online" then
        local shot, dx, dy = controls.touchreleased(id)
        if shot and game.spawnPlayerBullet then
            game.spawnPlayerBullet(dx, dy)
        end
    end
    dispatch("touchreleased", id, x, y)
end

function love.mousepressed(x, y, button, istouch)
    if isMobile or istouch then return end
    if button == 1 then
        love.touchpressed(1, x, y)
    end
end

function love.mousemoved(x, y)
    if isMobile then return end
    if love.mouse.isDown(1) then
        love.touchmoved(1, x, y)
    end
end

function love.mousereleased(x, y, button, istouch)
    if isMobile or istouch then return end
    if button == 1 then
        love.touchreleased(1, x, y)
    end
end

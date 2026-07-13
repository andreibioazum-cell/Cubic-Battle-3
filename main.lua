-- main.lua – с поддержкой онлайн-режима и кнопками управления окном
local lobby = require("lobby")
local game = require("game")
local controls = require("controls")
local shop = require("shop")
local credits = require("credits")
local settings = require("settings")
local mode_select = require("mode_select")
local difficulty = require("difficulty")
local online = require("online")
local room = require("room")

GameState = { current = "lobby" }

local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local lastTap = 0
local lastState = nil
local shotCooldown = 0
local SHOT_DELAY = 0.15

-- ============================================================
--  КНОПКИ УПРАВЛЕНИЯ ОКНОМ (только для ПК)
-- ============================================================
local windowButtons = {
    close = { x = 0, y = 0, w = 30, h = 30 },
    maximize = { x = 0, y = 0, w = 30, h = 30 },
    minimize = { x = 0, y = 0, w = 30, h = 30 },
    isFullscreen = false,
    hoverClose = false,
    hoverMaximize = false,
    hoverMinimize = false,
    show = not isMobile
}

local function updateWindowButtons()
    local w, h = love.graphics.getDimensions()
    local size = 30
    local spacing = 6
    local padding = 8
    
    windowButtons.minimize.x = w - padding - size - spacing - size - spacing - size
    windowButtons.minimize.y = padding
    windowButtons.minimize.w = size
    windowButtons.minimize.h = size
    
    windowButtons.maximize.x = w - padding - size - spacing - size
    windowButtons.maximize.y = padding
    windowButtons.maximize.w = size
    windowButtons.maximize.h = size
    
    windowButtons.close.x = w - padding - size
    windowButtons.close.y = padding
    windowButtons.close.w = size
    windowButtons.close.h = size
end

local function drawWindowButtons()
    if not windowButtons.show then return end
    
    local size = windowButtons.close.w
    
    -- Фон для кнопок
    love.graphics.setColor(0.08, 0.08, 0.12, 0.6)
    love.graphics.rectangle("fill", windowButtons.close.x - 10, 2, 
                            windowButtons.close.w + windowButtons.maximize.w + windowButtons.minimize.w + 50, 
                            windowButtons.close.h + 10, 6, 6)
    
    -- ===== СВЕРНУТЬ =====
    local minColor = windowButtons.hoverMinimize and {0.4, 0.4, 0.5, 1} or {0.25, 0.25, 0.35, 0.85}
    love.graphics.setColor(minColor[1], minColor[2], minColor[3], minColor[4])
    love.graphics.rectangle("fill", windowButtons.minimize.x, windowButtons.minimize.y, size, size, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(windowButtons.minimize.x + 8, windowButtons.minimize.y + size/2, 
                       windowButtons.minimize.x + size - 8, windowButtons.minimize.y + size/2)
    
    -- ===== РАЗВЕРНУТЬ =====
    local maxColor = windowButtons.hoverMaximize and {0.4, 0.4, 0.5, 1} or {0.25, 0.25, 0.35, 0.85}
    love.graphics.setColor(maxColor[1], maxColor[2], maxColor[3], maxColor[4])
    love.graphics.rectangle("fill", windowButtons.maximize.x, windowButtons.maximize.y, size, size, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    if windowButtons.isFullscreen then
        love.graphics.rectangle("line", windowButtons.maximize.x + 4, windowButtons.maximize.y + 8, size - 12, size - 12)
        love.graphics.rectangle("line", windowButtons.maximize.x + 8, windowButtons.maximize.y + 4, size - 12, size - 12)
    else
        love.graphics.rectangle("line", windowButtons.maximize.x + 5, windowButtons.maximize.y + 5, size - 10, size - 10)
    end
    
    -- ===== ЗАКРЫТЬ =====
    local closeColor = windowButtons.hoverClose and {0.9, 0.2, 0.2, 1} or {0.7, 0.15, 0.15, 0.9}
    love.graphics.setColor(closeColor[1], closeColor[2], closeColor[3], closeColor[4])
    love.graphics.rectangle("fill", windowButtons.close.x, windowButtons.close.y, size, size, 4, 4)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.setLineWidth(2.5)
    local m = 8
    love.graphics.line(windowButtons.close.x + m, windowButtons.close.y + m, 
                       windowButtons.close.x + size - m, windowButtons.close.y + size - m)
    love.graphics.line(windowButtons.close.x + size - m, windowButtons.close.y + m, 
                       windowButtons.close.x + m, windowButtons.close.y + size - m)
end

local function handleWindowButtons(x, y)
    if not windowButtons.show then return false end
    
    if x >= windowButtons.close.x and x <= windowButtons.close.x + windowButtons.close.w and
       y >= windowButtons.close.y and y <= windowButtons.close.y + windowButtons.close.h then
        love.event.quit()
        return true
    end
    
    if x >= windowButtons.maximize.x and x <= windowButtons.maximize.x + windowButtons.maximize.w and
       y >= windowButtons.maximize.y and y <= windowButtons.maximize.y + windowButtons.maximize.h then
        windowButtons.isFullscreen = not windowButtons.isFullscreen
        love.window.setFullscreen(windowButtons.isFullscreen, "desktop")
        return true
    end
    
    if x >= windowButtons.minimize.x and x <= windowButtons.minimize.x + windowButtons.minimize.w and
       y >= windowButtons.minimize.y and y <= windowButtons.minimize.y + windowButtons.minimize.h then
        love.window.minimize()
        return true
    end
    
    return false
end

local function windowButtonsMousemoved(x, y)
    if not windowButtons.show then return end
    
    windowButtons.hoverClose = x >= windowButtons.close.x and x <= windowButtons.close.x + windowButtons.close.w and
                               y >= windowButtons.close.y and y <= windowButtons.close.y + windowButtons.close.h
    
    windowButtons.hoverMaximize = x >= windowButtons.maximize.x and x <= windowButtons.maximize.x + windowButtons.maximize.w and
                                  y >= windowButtons.maximize.y and y <= windowButtons.maximize.y + windowButtons.maximize.h
    
    windowButtons.hoverMinimize = x >= windowButtons.minimize.x and x <= windowButtons.minimize.x + windowButtons.minimize.w and
                                  y >= windowButtons.minimize.y and y <= windowButtons.minimize.y + windowButtons.minimize.h
end

-- ============================================================
--  ЗВУКИ И МУЗЫКА
-- ============================================================
local bgMusic = nil
musicOn = true
sfxOn = true

function toggleMusic()
    if bgMusic then
        if bgMusic:isPlaying() then
            bgMusic:pause()
            musicOn = false
        else
            bgMusic:play()
            musicOn = true
        end
    end
end

function toggleSfx()
    sfxOn = not sfxOn
end

local function loadMusic()
    local ok, source = pcall(love.audio.newSource, "Aaron Kenny - Christmas Village.mp3", "stream")
    if ok and source then
        bgMusic = source
        bgMusic:setLooping(true)
        bgMusic:setVolume(0.5)
        if musicOn then bgMusic:play() end
    else
        musicOn = false
        print("Music not loaded")
    end
end

function playButtonSound()
    if not sfxOn then return end
    local sound, err = love.audio.newSource("cartoon-button-click-sound.mp3", "static")
    if sound then
        sound:setVolume(0.5)
        sound:play()
    end
end

local shootSound = nil
local hitSound = nil

function playShootSound()
    if not sfxOn then return end
    if not shootSound then
        local ok, source = pcall(love.audio.newSource, "The_Sound_Of_A_Gunshot.wav", "static")
        if ok and source then
            shootSound = source
            shootSound:setVolume(1.0)
        else
            return
        end
    end
    local clone = shootSound:clone()
    clone:setVolume(1.0)
    clone:play()
end

function playHitSound()
    if not sfxOn then return end
    if not hitSound then
        local ok, source = pcall(love.audio.newSource, "hit.mp3", "static")
        if ok and source then
            hitSound = source
            hitSound:setVolume(0.3)
        else
            return
        end
    end
    hitSound:stop()
    hitSound:play()
end

_G.playShootSound = playShootSound
_G.playHitSound = playHitSound
game.playShootSound = playShootSound
game.playHitSound = playHitSound

-- ============================================================
--  СОХРАНЕНИЕ
-- ============================================================
SAVE_DATA = { 
    coins = 0, 
    ownedSkins = {}, 
    equippedSkin = "NONE", 
    musicOn = true, 
    sfxOn = true,
    nickname = "Player"
}
local SAVE_FILE = "data.txt"

function SAVE_SAVE()
    local ownedStr = table.concat(SAVE_DATA.ownedSkins, ",")
    local content = tostring(SAVE_DATA.coins) .. "\n" ..
                    ownedStr .. "\n" ..
                    SAVE_DATA.equippedSkin .. "\n" ..
                    tostring(musicOn and 1 or 0) .. "\n" ..
                    tostring(sfxOn and 1 or 0) .. "\n" ..
                    (SAVE_DATA.nickname or "Player")
    pcall(function()
        love.filesystem.write(SAVE_FILE, content)
    end)
end

function loadSave()
    local info = love.filesystem.getInfo(SAVE_FILE)
    if not info then
        SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", musicOn = true, sfxOn = true, nickname = "Player" }
        musicOn = true
        sfxOn = true
        return
    end
    local data, err = love.filesystem.read(SAVE_FILE)
    if not data then
        SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", musicOn = true, sfxOn = true, nickname = "Player" }
        musicOn = true
        sfxOn = true
        return
    end
    local lines = {}
    for line in data:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    local coins = tonumber(lines[1]) or 0
    local ownedStr = lines[2] or ""
    local equippedSkin = lines[3] or "NONE"
    local musicVal = tonumber(lines[4]) or 1
    local sfxVal = tonumber(lines[5]) or 1
    local nickname = lines[6] or "Player"

    local ownedSkins = {}
    if ownedStr ~= "" then
        for name in ownedStr:gmatch("[^,]+") do
            table.insert(ownedSkins, name)
        end
    end
    SAVE_DATA = { 
        coins = coins, 
        ownedSkins = ownedSkins, 
        equippedSkin = equippedSkin,
        nickname = nickname
    }
    musicOn = musicVal == 1
    sfxOn = sfxVal == 1
end

-- ============================================================
--  LOVE CALLBACKS
-- ============================================================
function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    loadSave()
    controls.load()
    loadMusic()
    online.init()
    updateWindowButtons()
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
        
        if online.isConnected() then
            online.update(dt)
            local px, py = game.getPlayerPosition()
            if px and py then
                online.sendPosition(px, py)
            end
        end
        
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
        -- nothing
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
    
    -- Рисуем кнопки управления окном поверх всего
    drawWindowButtons()
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
    updateWindowButtons()
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
            _G.roomCode = nil
            online.leave()
            GameState.current = "lobby"
            playButtonSound()
        elseif GameState.current == "online" then
            _G.roomCode = nil
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

    -- Проверяем кнопки окна
    if handleWindowButtons(x, y) then
        return
    end

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
        -- Проверяем кнопки окна
        if handleWindowButtons(x, y) then
            return
        end
        love.touchpressed(1, x, y)
    end
end

function love.mousemoved(x, y)
    if isMobile then return end
    windowButtonsMousemoved(x, y)
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

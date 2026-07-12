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
local lastState = nil
local shotCooldown = 0
local SHOT_DELAY = 0.15
local onlineTimer = 0
local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"

-- Данные игрока
SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", nickname = "Player" }
musicOn = true
sfxOn = true

function playButtonSound()
    if not sfxOn then return end
    pcall(function() love.audio.newSource("cartoon-button-click-sound.mp3", "static"):play() end)
end

function playShootSound()
    if not sfxOn then return end
    pcall(function() love.audio.newSource("The_Sound_Of_A_Gunshot.wav", "static"):play() end)
end

function playHitSound()
    if not sfxOn then return end
    pcall(function() love.audio.newSource("hit.mp3", "static"):play() end)
end

_G.playShootSound = playShootSound
_G.playHitSound = playHitSound

function SAVE_SAVE()
    local ownedStr = table.concat(SAVE_DATA.ownedSkins, ",")
    local content = string.format("%d\n%s\n%s\n%s", SAVE_DATA.coins, ownedStr, SAVE_DATA.equippedSkin, SAVE_DATA.nickname)
    love.filesystem.write("data.txt", content)
end

function love.load()
    online.init()
    controls.load()
    -- Принудительный расчет координат кнопок при старте
    love.resize(love.graphics.getWidth(), love.graphics.getHeight())
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

    if GameState.current ~= lastState then
        local s = GameState.current
        -- Вызываем load только если он есть в модуле
        local modules = {lobby=lobby, game=game, shop=shop, room=room, settings=settings, credits=credits, mode_select=mode_select, difficulty=difficulty}
        if modules[s] and modules[s].load then modules[s].load(SAVE_DATA) end
        lastState = s
    end

    if GameState.current == "lobby" then
        lobby.update(dt)
    elseif GameState.current == "game" then
        game.update(dt)
        controls.update(dt)
        if online.isConnected() then
            online.update(dt)
            onlineTimer = onlineTimer + dt
            if onlineTimer > 0.2 then
                local px, py = game.getPlayerPosition()
                online.sendPosition(px, py)
                onlineTimer = 0
            end
        end
        if shotCooldown > 0 then shotCooldown = shotCooldown - dt end
        local shot, dx, dy = controls.getShot()
        if shot and shotCooldown <= 0 then
            game.spawnPlayerBullet(dx, dy)
            shotCooldown = SHOT_DELAY
        end
    end
end

function love.draw()
    local s = GameState.current
    if s == "lobby" then lobby.draw()
    elseif s == "game" then game.draw(); controls.draw()
    elseif s == "mode_select" then mode_select.draw()
    elseif s == "difficulty" then difficulty.draw()
    elseif s == "room" then room.draw()
    elseif s == "shop" then shop.draw(SAVE_DATA.coins)
    elseif s == "credits" then credits.draw()
    elseif s == "settings" then settings.draw()
    end
end

-- Обработка кликов
local function handlePress(id, x, y)
    local s = GameState.current
    if s == "game" then 
        if controls.touchpressed then controls.touchpressed(id, x, y) end
    end
    
    local m = {lobby=lobby, mode_select=mode_select, difficulty=difficulty, room=room, settings=settings, credits=credits}
    if m[s] and m[s].touchpressed then
        m[s].touchpressed(id, x, y)
    elseif s == "shop" then
        local nc, ch = shop.touchpressed(id, x, y, SAVE_DATA.coins, SAVE_DATA)
        if ch then SAVE_DATA.coins = nc; SAVE_SAVE() end
    end
end

function love.touchpressed(id, x, y) handlePress(id, x, y) end
function love.mousepressed(x, y, btn) if not isMobile and btn == 1 then handlePress(1, x, y) end end

function love.touchmoved(id, x, y)
    if GameState.current == "game" and controls.touchmoved then controls.touchmoved(id, x, y) end
end
function love.mousemoved(x, y)
    if not isMobile and love.mouse.isDown(1) and GameState.current == "game" then controls.touchmoved(1, x, y) end
end

function love.touchreleased(id, x, y)
    if GameState.current == "game" then
        local shot, dx, dy = controls.touchreleased(id)
        if shot then game.spawnPlayerBullet(dx, dy) end
    end
end
function love.mousereleased(x, y, btn)
    if not isMobile and btn == 1 and GameState.current == "game" then
        local shot, dx, dy = controls.touchreleased(1)
        if shot then game.spawnPlayerBullet(dx, dy) end
    end
end

-- БЕЗОПАСНЫЙ РЕЗАЙЗ (Проверяет наличие функции)
function love.resize(w, h)
    local mods = {lobby, game, shop, room, settings, credits, mode_select, difficulty, controls}
    for _, m in ipairs(mods) do
        if m and m.resize then m.resize(w, h) end
    end
end

function love.keypressed(k)
    if k == "escape" then online.leave(); GameState.current = "lobby" end
    if GameState.current == "game" then controls.keypressed(k) end
end

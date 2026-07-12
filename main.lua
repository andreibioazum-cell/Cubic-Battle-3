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
local SHOT_DELAY = 0.2
local onlineSendTimer = 0

-- Заглушки для звуков, если файлы отсутствуют
function playButtonSound() end
function playShootSound() end
function playHitSound() end

-- Глобальные настройки
musicOn = true
sfxOn = true
SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", nickname = "Player" }

function SAVE_SAVE() 
    -- Здесь твоя логика сохранения в файл
end

function love.load()
    online.init()
    controls.load()
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

    -- Переключение состояний
    if GameState.current ~= lastState then
        local s = GameState.current
        if s == "lobby" then lobby.load()
        elseif s == "game" then game.load()
        elseif s == "shop" then shop.load(SAVE_DATA)
        elseif s == "room" then room.load()
        end
        lastState = s
    end

    if GameState.current == "lobby" then
        lobby.update(dt)
    elseif GameState.current == "game" then
        game.update(dt)
        controls.update(dt)

        -- ОБНОВЛЕНИЕ СЕТИ ВНУТРИ ИГРЫ
        if online.isConnected() then
            online.update(dt)
            onlineSendTimer = onlineSendTimer + dt
            if onlineSendTimer > 0.2 then
                local px, py = game.getPlayerPosition()
                online.sendPosition(px, py)
                onlineSendTimer = 0
            end
        end

        -- Стрельба
        if shotCooldown > 0 then shotCooldown = shotCooldown - dt end
        local shot, dx, dy = controls.getShot()
        if shot and shotCooldown <= 0 then
            game.spawnPlayerBullet(dx, dy)
            shotCooldown = SHOT_DELAY
        end
    end
end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "game" then
        game.draw()
        controls.draw()
    elseif GameState.current == "mode_select" then
        mode_select.draw()
    elseif GameState.current == "difficulty" then
        difficulty.draw()
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

function love.touchpressed(id, x, y)
    local s = GameState.current
    if s == "game" then controls.touchpressed(id, x, y) end
    
    if s == "lobby" then lobby.touchpressed(id, x, y)
    elseif s == "mode_select" then mode_select.touchpressed(id, x, y)
    elseif s == "difficulty" then difficulty.touchpressed(id, x, y)
    elseif s == "room" then room.touchpressed(id, x, y)
    elseif s == "shop" then 
        local newCoins, changed = shop.touchpressed(id, x, y, SAVE_DATA.coins, SAVE_DATA)
        SAVE_DATA.coins = newCoins
    elseif s == "settings" then settings.touchpressed(id, x, y)
    elseif s == "credits" then credits.touchpressed(id, x, y)
    end
end

function love.touchmoved(id, x, y)
    if GameState.current == "game" then controls.touchmoved(id, x, y) end
end

function love.touchreleased(id, x, y)
    if GameState.current == "game" then
        local shot, dx, dy = controls.touchreleased(id)
        if shot then game.spawnPlayerBullet(dx, dy) end
    end
end

function love.keypressed(key)
    if key == "escape" then GameState.current = "lobby"; online.leave() end
end

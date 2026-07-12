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

-- МУЗЫКА И ЗВУКИ (твоя логика)
musicOn = true
sfxOn = true
local bgMusic = nil

function playButtonSound()
    if not sfxOn then return end
    local sound = love.audio.newSource("cartoon-button-click-sound.mp3", "static")
    if sound then sound:setVolume(0.5); sound:play() end
end

function playShootSound()
    if not sfxOn then return end
    local sound = love.audio.newSource("The_Sound_Of_A_Gunshot.wav", "static")
    if sound then sound:setVolume(0.6); sound:play() end
end

function playHitSound()
    if not sfxOn then return end
    local sound = love.audio.newSource("hit.mp3", "static")
    if sound then sound:setVolume(0.4); sound:play() end
end

_G.playShootSound = playShootSound
_G.playHitSound = playHitSound

-- СОХРАНЕНИЯ
SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", nickname = "Player" }
function SAVE_SAVE()
    local content = string.format("%d\n%s\n%s\n%s", SAVE_DATA.coins, table.concat(SAVE_DATA.ownedSkins, ","), SAVE_DATA.equippedSkin, SAVE_DATA.nickname)
    love.filesystem.write("data.txt", content)
end

function love.load()
    online.init()
    controls.load()
    local ok, source = pcall(love.audio.newSource, "Aaron Kenny - Christmas Village.mp3", "stream")
    if ok then bgMusic = source; bgMusic:setLooping(true); bgMusic:play() end
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

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
        
        -- СЕТЕВОЕ ОБНОВЛЕНИЕ
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

function love.touchpressed(id, x, y)
    local s = GameState.current
    if s == "game" then controls.touchpressed(id, x, y) end
    if s == "lobby" then lobby.touchpressed(id, x, y)
    elseif s == "mode_select" then mode_select.touchpressed(id, x, y)
    elseif s == "difficulty" then difficulty.touchpressed(id, x, y)
    elseif s == "room" then room.touchpressed(id, x, y)
    elseif s == "shop" then 
        local newCoins, changed = shop.touchpressed(id, x, y, SAVE_DATA.coins, SAVE_DATA)
        SAVE_DATA.coins = newCoins; SAVE_SAVE()
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
    if key == "escape" then online.leave(); GameState.current = "lobby" end
    if GameState.current == "game" then controls.keypressed(key) end
end

function love.keyreleased(key)
    if GameState.current == "game" then controls.keyreleased(key) end
end

-- main.lua для Cubic Battle 3
local lobby = require("lobby")
local game = require("game")
local controls = require("controls")
local shop = require("shop")
local credits = require("credits")
local settings = require("settings")
local mode_select = require("mode_select")

GameState = { current = "lobby" }

local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local lastTap = 0
local lastState = nil
local shotCooldown = 0
local SHOT_DELAY = 0.15

-- ========== ЗВУКИ И МУЗЫКА ==========
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
    local ok, source = pcall(love.audio.newSource, "Kevin_MacLeod_-_Sneaky_Snitch_74768437.mp3", "stream")
    if ok and source then
        bgMusic = source
        bgMusic:setLooping(true)
        bgMusic:setVolume(0.5)
        if musicOn then bgMusic:play() end
    else
        musicOn = false
        print("Не удалось загрузить музыку")
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

-- ========== СОХРАНЕНИЕ ==========
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
    local success, err = pcall(function()
        love.filesystem.write(SAVE_FILE, content)
    end)
    if success then
        print("Сохранено: coins=" .. SAVE_DATA.coins .. ", owned=" .. ownedStr .. ", equipped=" .. SAVE_DATA.equippedSkin)
    else
        print("Ошибка сохранения: " .. tostring(err))
    end
end

local function loadSave()
    local info = love.filesystem.getInfo(SAVE_FILE)
    if not info then
        SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", nickname = "Player" }
        musicOn = true
        sfxOn = true
        return
    end
    local data, err = love.filesystem.read(SAVE_FILE)
    if not data then
        SAVE_DATA = { coins = 0, ownedSkins = {}, equippedSkin = "NONE", nickname = "Player" }
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
    print("Загружено: coins=" .. coins .. ", owned=" .. ownedStr .. ", equipped=" .. equippedSkin .. ", nick=" .. nickname)
end

-- ========== LOVE CALLBACKS ==========
function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    loadSave()
    controls.load()
    loadMusic()
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

    if GameState.current ~= lastState then
        print("Переход в состояние: " .. tostring(GameState.current))
        if GameState.current == "lobby" then
            if lobby.load then lobby.load() end
        elseif GameState.current == "mode_select" then
            if mode_select.load then mode_select.load() end
        elseif GameState.current == "game" then
            if game.load then game.load() end
        elseif GameState.current == "multiplayer" then
            if multiplayer.load then 
                local mode = GameState.multiplayerMode or "client"
                multiplayer.load(mode)
            end
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
    elseif GameState.current == "mode_select" then
        -- ничего
    elseif GameState.current == "game" then
        controls.update(dt)
        if shotCooldown > 0 then
            shotCooldown = shotCooldown - dt
        end
        local shot, dx, dy = controls.getShot()
        if shot and shotCooldown <= 0 and game.spawnPlayerBullet then
            game.spawnPlayerBullet(dx, dy)
            shotCooldown = SHOT_DELAY
        end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "mode_select" then
        mode_select.draw()
    elseif GameState.current == "game" then
        game.draw()
        controls.draw()
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
    if game.resize then game.resize(w, h) end
    if shop.resize then shop.resize() end
    if credits.resize then credits.resize() end
    if settings.resize then settings.resize() end
    controls.resize()
end

function love.keypressed(key)
    if GameState.current == "game" then
        controls.keypressed(key)
    elseif GameState.current == "multiplayer" then
        multiplayer.keypressed(key)
    elseif GameState.current == "settings" then
        settings.keypressed(key)
    end

    if key == "escape" then
        if GameState.current == "game" or GameState.current == "multiplayer" then
            GameState.current = "lobby"
            playButtonSound()
        elseif GameState.current == "mode_select" then
            GameState.current = "lobby"
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
    if GameState.current == "game" then
        controls.keyreleased(key)
    elseif GameState.current == "multiplayer" then
        multiplayer.keyreleased(key)
    end
end

function love.textinput(t)
    if GameState.current == "settings" and settings.textinput then
        settings.textinput(t)
    end
end

local function dispatch(fn, id, x, y)
    local s = GameState.current
    if s == "lobby" and lobby[fn] then
        lobby[fn](id, x, y)
    elseif s == "mode_select" and mode_select[fn] then
        mode_select[fn](id, x, y)
    elseif s == "game" and game[fn] then
        game[fn](id, x, y)
    elseif s == "multiplayer" and multiplayer[fn] then
        multiplayer[fn](id, x, y)
    elseif s == "shop" and shop[fn] then
        if fn == "touchpressed" then
            local newCoins, changed = shop.touchpressed(id, x, y, SAVE_DATA.coins, SAVE_DATA)
            if changed then
                SAVE_SAVE()
            end
            if newCoins ~= SAVE_DATA.coins then
                SAVE_DATA.coins = newCoins
                SAVE_SAVE()
            end
        else
            shop[fn](id, x, y)
        end
    elseif s == "credits" and credits[fn] then
        credits[fn](id, x, y)
    elseif s == "settings" and settings[fn] then
        settings[fn](id, x, y)
    end
end

function love.touchpressed(id, x, y)
    local now = love.timer.getTime()
    if now - lastTap < 0.05 then return end
    lastTap = now

    if GameState.current == "game" or GameState.current == "multiplayer" then
        controls.touchpressed(id, x, y)
    end

    dispatch("touchpressed", id, x, y)
end

function love.touchmoved(id, x, y)
    if GameState.current == "game" or GameState.current == "multiplayer" then
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

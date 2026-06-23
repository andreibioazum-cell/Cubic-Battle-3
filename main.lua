local lobby = require("lobby")
local game = require("game")
local controls = require("controls")
local shop = require("shop")
local credits = require("credits")
local settings = require("settings")   -- новый модуль настроек

GameState = { current = "lobby" }

local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local lastTap = 0
local lastState = nil
local shotCooldown = 0
local SHOT_DELAY = 0.15

-- ========== ЗВУКИ И МУЗЫКА ==========
local bgMusic = nil
musicOn = true      -- глобальная переменная (используется в других модулях)
sfxOn = true        -- глобальная переменная для звуковых эффектов

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
    if not sfxOn then return end   -- если звуки выключены – молчим
    local sound, err = love.audio.newSource("cartoon-button-click-sound.mp3", "static")
    if sound then
        sound:setVolume(0.5)
        sound:play()
    else
        -- print("Звук кнопки не загружен")
    end
end

-- ========== СОХРАНЕНИЕ (5 строк) ==========
SAVE_DATA = { coins = 0, ownedSkin = "NONE", equippedSkin = "NONE", musicOn = true, sfxOn = true }
local SAVE_FILE = "data.txt"

function SAVE_SAVE()
    local content = tostring(SAVE_DATA.coins) .. "\n" ..
                    SAVE_DATA.ownedSkin .. "\n" ..
                    SAVE_DATA.equippedSkin .. "\n" ..
                    tostring(musicOn and 1 or 0) .. "\n" ..
                    tostring(sfxOn and 1 or 0)
    local success, err = pcall(function()
        love.filesystem.write(SAVE_FILE, content)
    end)
    if success then
        print("Сохранено: coins=" .. SAVE_DATA.coins .. ", music=" .. tostring(musicOn) .. ", sfx=" .. tostring(sfxOn))
    else
        print("Ошибка сохранения: " .. tostring(err))
    end
end

local function loadSave()
    local info = love.filesystem.getInfo(SAVE_FILE)
    if not info then
        print("Нет файла сохранения, используем значения по умолчанию")
        SAVE_DATA = { coins = 0, ownedSkin = "NONE", equippedSkin = "NONE" }
        musicOn = true
        sfxOn = true
        return
    end

    local data, err = love.filesystem.read(SAVE_FILE)
    if not data then
        print("Ошибка чтения сохранения: " .. tostring(err))
        SAVE_DATA = { coins = 0, ownedSkin = "NONE", equippedSkin = "NONE" }
        musicOn = true
        sfxOn = true
        return
    end

    local lines = {}
    for line in data:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local coins = tonumber(lines[1]) or 0
    local ownedSkin = lines[2] or "NONE"
    local equippedSkin = lines[3] or "NONE"
    local musicVal = tonumber(lines[4]) or 1
    local sfxVal = tonumber(lines[5]) or 1

    SAVE_DATA = {
        coins = coins,
        ownedSkin = ownedSkin,
        equippedSkin = equippedSkin
    }
    musicOn = musicVal == 1
    sfxOn = sfxVal == 1

    print("Загружено: coins=" .. coins .. ", owned=" .. ownedSkin .. ", equipped=" .. equippedSkin ..
          ", music=" .. tostring(musicOn) .. ", sfx=" .. tostring(sfxOn))
end

-- ========== LOVE CALLBACKS ==========
function love.load()
    love.graphics.setDefaultFilter("linear", "linear")
    loadSave()          -- загружаем настройки и монеты
    controls.load()     -- загружаем управление
    loadMusic()         -- загружаем музыку (учитывая musicOn)
end

function love.update(dt)
    if dt > 0.05 then dt = 0.05 end

    -- Обработка смены состояния
    if GameState.current ~= lastState then
        print("Переход в состояние: " .. tostring(GameState.current))
        if GameState.current == "lobby" then
            if lobby.load then lobby.load() end
        elseif GameState.current == "game" then
            if game.load then game.load() end
        elseif GameState.current == "shop" then
            if shop.load then shop.load(SAVE_DATA) end
        elseif GameState.current == "credits" then
            if credits.load then credits.load() end
        elseif GameState.current == "settings" then
            if settings.load then settings.load() end
        end
        lastState = GameState.current
    end

    -- Обновление логики в зависимости от состояния
    if GameState.current == "lobby" then
        lobby.update(dt)
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
        game.update(dt)
    -- остальные состояния не требуют обновления
    end
end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "game" then
        game.draw()
        controls.draw()   -- рисуем элементы управления поверх игры
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
    if game.resize  then game.resize(w, h)  end
    if shop.resize  then shop.resize()      end
    if credits.resize then credits.resize() end
    if settings.resize then settings.resize() end
    controls.resize()
end

-- ========== КЛАВИАТУРА ==========
function love.keypressed(key)
    if GameState.current == "game" then
        controls.keypressed(key)
    end

    if key == "escape" then
        GameState.current = "lobby"
        playButtonSound()
    end

    if key == "m" then
        toggleMusic()
        SAVE_SAVE()   -- сохраняем состояние музыки
        playButtonSound()
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
    if s == "lobby" and lobby[fn] then
        lobby[fn](id, x, y)
    elseif s == "game" and game[fn] then
        game[fn](id, x, y)
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

-- МЫШЬ для ПК (эмуляция тача)
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

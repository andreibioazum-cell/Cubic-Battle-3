local lobby = require("lobby")
local game = require("game")
local controls = require("controls")
local shop = require("shop")
local credits = require("credits")

GameState = { current = "lobby" }

local isMobile = love.system.getOS() == "Android" or love.system.getOS() == "iOS"
local lastTap = 0
local lastState = nil
local shotCooldown = 0
local SHOT_DELAY = 0.15

-- ========== ФОНОВАЯ МУЗЫКА ==========
local bgMusic = nil

local function loadMusic()
    local ok, source = pcall(love.audio.newSource, "Kevin_MacLeod_-_Sneaky_Snitch_74768437.mp3", "stream")
    if ok and source then
        bgMusic = source
        bgMusic:setLooping(true)
        bgMusic:setVolume(0.5)
        bgMusic:play()
        print("Фоновая музыка запущена")
    else
        print("Не удалось загрузить музыку: файл не найден или формат не поддерживается")
    end
end

-- ========== СОХРАНЕНИЕ (ПОЛНОСТЬЮ ПЕРЕРАБОТАННОЕ) ==========
SAVE_DATA = { coins = 0, hasAzumSkin = false }

-- Функция сохранения с защитой и отладкой
function SAVE_SAVE()
    local str = "return {\n"
    for k, v in pairs(SAVE_DATA) do
        local val
        if type(v) == "string" then
            val = string.format("%q", v)
        elseif type(v) == "boolean" then
            val = v and "true" or "false"
        else
            val = tostring(v)
        end
        str = str .. "  [" .. tostring(k) .. "] = " .. val .. ",\n"
    end
    str = str .. "}"

    print("Попытка сохранить данные: " .. str)

    local success, err = pcall(function()
        love.filesystem.write("save.lua", str)
    end)
    if success then
        print("Сохранение выполнено успешно. Путь: " .. (love.filesystem.getSaveDirectory() or "неизвестно"))
    else
        print("Ошибка сохранения: " .. tostring(err))
    end
end

-- Функция загрузки с отладкой
local function loadSave()
    -- Проверяем, существует ли файл
    local info = love.filesystem.getInfo("save.lua")
    if not info then
        print("Файл сохранения не найден, создаём новые данные по умолчанию")
        SAVE_DATA = { coins = 0, hasAzumSkin = false }
        return
    end

    print("Файл сохранения найден, размер: " .. tostring(info.size) .. " байт")

    local chunk, err = love.filesystem.load("save.lua")
    if not chunk then
        print("Ошибка загрузки чанка: " .. tostring(err))
        SAVE_DATA = { coins = 0, hasAzumSkin = false }
        return
    end

    local ok, data = pcall(chunk)
    if not ok then
        print("Ошибка выполнения чанка: " .. tostring(data))
        SAVE_DATA = { coins = 0, hasAzumSkin = false }
        return
    end

    if type(data) ~= "table" then
        print("Загруженные данные не являются таблицей, используем значения по умолчанию")
        SAVE_DATA = { coins = 0, hasAzumSkin = false }
        return
    end

    -- Убедимся, что есть поля coins и hasAzumSkin
    SAVE_DATA = data
    if SAVE_DATA.coins == nil then SAVE_DATA.coins = 0 end
    if SAVE_DATA.hasAzumSkin == nil then SAVE_DATA.hasAzumSkin = false end

    print("Сохранение загружено: coins = " .. tostring(SAVE_DATA.coins) .. ", hasAzumSkin = " .. tostring(SAVE_DATA.hasAzumSkin))
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
        print("Переключение состояния: " .. tostring(lastState) .. " -> " .. tostring(GameState.current))
        if GameState.current == "lobby" then
            if lobby.load then lobby.load() end
        elseif GameState.current == "game" then
            if game.load then game.load(SAVE_DATA.hasAzumSkin) end
        elseif GameState.current == "shop" then
            if shop.load then shop.load(SAVE_DATA) end
        elseif GameState.current == "credits" then
            if credits.load then credits.load() end
        end
        lastState = GameState.current
    end

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
    elseif GameState.current == "shop" then
        -- ничего
    elseif GameState.current == "credits" then
        -- ничего
    end
end

function love.draw()
    if GameState.current == "lobby" then
        lobby.draw()
    elseif GameState.current == "game" then
        game.draw()
        controls.draw()
    elseif GameState.current == "shop" then
        shop.draw(SAVE_DATA.coins)
    elseif GameState.current == "credits" then
        credits.draw()
    end
end

function love.resize(w, h)
    if lobby.resize then lobby.resize(w, h) end
    if game.resize  then game.resize(w, h)  end
    if shop.resize  then shop.resize()      end
    if credits.resize then credits.resize() end
    controls.resize()
end

-- ========== КЛАВИАТУРА ==========
function love.keypressed(key)
    if GameState.current == "game" then
        controls.keypressed(key)
    end

    if key == "escape" then
        if GameState.current == "credits" then
            GameState.current = "lobby"
        else
            GameState.current = "lobby"
        end
    end

    if key == "m" and bgMusic then
        if bgMusic:isPlaying() then
            bgMusic:pause()
        else
            bgMusic:play()
        end
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
    elseif s == "game" and game[fn] then game[fn](id, x, y)
    elseif s == "shop" and shop[fn] then
        if fn == "touchpressed" then
            local newCoins, bought = shop.touchpressed(id, x, y, SAVE_DATA.coins, SAVE_DATA)
            if newCoins ~= SAVE_DATA.coins then
                print("Монеты изменились: " .. tostring(SAVE_DATA.coins) .. " -> " .. tostring(newCoins))
                SAVE_DATA.coins = newCoins
                SAVE_SAVE()
            end
            if bought then
                SAVE_SAVE()
            end
        else
            shop[fn](id, x, y)
        end
    elseif s == "credits" and credits[fn] then
        credits[fn](id, x, y)
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

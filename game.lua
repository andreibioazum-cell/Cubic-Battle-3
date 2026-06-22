local controls = require("controls")
local enemy = require("enemy")

local game = {}

-- Глобальные переменные для сохранения (устанавливаются из main.lua)
SAVE_DATA = SAVE_DATA or { coins = 0, hasAzumSkin = false }
SAVE_SAVE = SAVE_SAVE or function() end

local PLAYER_SIZE = 55
local PLAYER_HP_MAX = 5
local BULLET_SPEED = 340 * 1.15

local cube = { x=0, y=0, speed=260, angle=0, hp=PLAYER_HP_MAX, hit=0 }
local bullets = {}
local bg, playerImg, azumImg, font
local cam = { x=0, y=0 }
local dead = false

-- Флаги для скина и способности
local hasAzumSkin = false
local resurrectionUsed = false   -- использована ли способность в текущей игре

-- ========== СОЗДАНИЕ ПУЛИ ==========
local function spawnBullet(x, y, dx, dy)
    table.insert(bullets, {
        x=x, y=y,
        vx=dx*BULLET_SPEED,
        vy=dy*BULLET_SPEED,
        life=3
    })
end

-- ========== ОТРИСОВКА ПОЛОСЫ HP ==========
local function drawHPBar(x, y, w, h, hp, max, color)
    if hp < 0 then hp = 0 end
    love.graphics.setColor(0,0,0,0.5)
    love.graphics.rectangle("fill", x-2, y-2, w+4, h+4, 6, 6)
    love.graphics.setColor(0.15,0.15,0.15,1)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", x, y, w * (hp/max), h, 4, 4)
    love.graphics.setColor(0,0,0,1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
end

-- ========== ОБРАБОТЧИК ПОЛУЧЕНИЯ УРОНА ==========
-- АВТОМАТИЧЕСКОГО ВОСКРЕШЕНИЯ ЗДЕСЬ НЕТ!
local function onHitPlayer(dmg)
    if dead then return end
    cube.hp = cube.hp - dmg
    cube.hit = 1

    -- Если здоровье упало до 0 или ниже – игрок умирает, переходим в лобби
    if cube.hp <= 0 then
        cube.hp = 0
        dead = true
        GameState.current = "lobby"
    end
end

-- ========== ЗАГРУЗКА ИГРЫ ==========
function game.load(hasAzum)
    hasAzumSkin = hasAzum or false
    resurrectionUsed = false   -- сбрасываем использование способности

    cube.x, cube.y = 0, 0
    cube.angle = 0
    cube.hp = PLAYER_HP_MAX
    cube.hit = 0
    dead = false
    bullets = {}
    cam.x, cam.y = -love.graphics.getWidth()/2, -love.graphics.getHeight()/2

    bg = bg or love.graphics.newImage("grass.png")
    bg:setWrap("repeat","repeat")

    playerImg = playerImg or love.graphics.newImage("player.png")
    playerImg:setFilter("nearest","nearest")

    azumImg = azumImg or love.graphics.newImage("azum.png")
    azumImg:setFilter("nearest","nearest")

    font = font or love.graphics.newFont("Fredoka-Bold.ttf", 18)

    controls.load()
    enemy.load()
    enemy.reset()
end

function game.resize()
    controls.resize()
end

-- ========== ОБНОВЛЕНИЕ ИГРЫ ==========
function game.update(dt)
    if dead then return end

    controls.update(dt)

    -- ========== РУЧНАЯ АКТИВАЦИЯ СПОСОБНОСТИ (ТОЛЬКО ПО КНОПКЕ!) ==========
    if controls.getAbilityTrigger() then
        -- Условия: есть скин, способность ещё не использована, здоровье <= 1
        if hasAzumSkin and not resurrectionUsed and cube.hp <= 1 then
            cube.hp = 5          -- воскрешение до 5 HP
            resurrectionUsed = true
            cube.hit = 0         -- убираем эффект попадания
        end
    end

    -- ========== ДВИЖЕНИЕ ИГРОКА ==========
    local dx, dy = controls.getMove()
    cube.x = cube.x + dx * cube.speed * dt
    cube.y = cube.y + dy * cube.speed * dt

    if dx ~= 0 or dy ~= 0 then
        cube.angle = math.atan2(dy, dx) + math.pi/2
    end

    cube.hit = math.max(0, cube.hit - dt*3)

    -- ========== КАМЕРА ==========
    local targetX = cube.x - love.graphics.getWidth()/2
    local targetY = cube.y - love.graphics.getHeight()/2
    local k = 1 - math.exp(-dt * 7.3)
    cam.x = cam.x + (targetX - cam.x) * k
    cam.y = cam.y + (targetY - cam.y) * k

    -- ========== ОБНОВЛЕНИЕ ПУЛЬ ИГРОКА ==========
    for i=#bullets,1,-1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 then
            table.remove(bullets, i)
        end
    end

    -- ========== ОБНОВЛЕНИЕ ВРАГА ==========
    local enemyKilled = enemy.update(dt, cube.x, cube.y, bullets, onHitPlayer)
    if enemyKilled then
        -- Начисляем монеты за убийство врага
        SAVE_DATA.coins = (SAVE_DATA.coins or 0) + 10
        SAVE_SAVE()
        GameState.current = "lobby"
        return
    end

    -- ========== ПРОВЕРКА ПОПАДАНИЙ ПУЛЬ ВРАГА В ИГРОКА ==========
    local eBullets = enemy.getBullets()
    for i=#eBullets, 1, -1 do
        local b = eBullets[i]
        local bx = b.x - cube.x
        local by = b.y - cube.y
        if bx*bx + by*by <= (PLAYER_SIZE*0.5)^2 then
            onHitPlayer(1)
            table.remove(eBullets, i)
            if dead then return end
        end
    end
end

-- ========== ОТРИСОВКА ==========
function game.draw()
    love.graphics.setColor(1,1,1,1)

    love.graphics.push()
    love.graphics.translate(-cam.x, -cam.y)

    -- ФОН
    local w,h = love.graphics.getDimensions()
    local tw,th = bg:getWidth(), bg:getHeight()
    local sX = math.floor(cam.x/tw)*tw
    local sY = math.floor(cam.y/th)*th
    for x=sX, sX+w+tw, tw do
        for y=sY, sY+h+th, th do
            love.graphics.draw(bg, x, y)
        end
    end

    -- ПУЛИ ИГРОКА
    love.graphics.setColor(0, 0, 0, 1)
    for _, b in ipairs(bullets) do
        love.graphics.circle("fill", b.x, b.y, 8)
    end

    -- ПУЛИ ВРАГА
    enemy.drawBullets()

    -- ЛИНИЯ ПРИЦЕЛА
    if controls.isAiming() then
        local ax, ay = controls.getAim()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.setLineWidth(16)
        love.graphics.line(
            cube.x, cube.y,
            cube.x + ax * 180,
            cube.y + ay * 180
        )
    end

    -- ВРАГ
    enemy.draw()

    -- ИГРОК (С УЧЁТОМ СКИНА)
    local imgToDraw = hasAzumSkin and azumImg or playerImg

    -- Тень
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.push()
    love.graphics.translate(cube.x + 6, cube.y + 8)
    love.graphics.rotate(cube.angle)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE/2, -PLAYER_SIZE/2)
    love.graphics.pop()

    -- Сам игрок
    love.graphics.push()
    love.graphics.translate(cube.x, cube.y)
    love.graphics.rotate(cube.angle)
    local t = cube.hit
    love.graphics.setColor(1, 1 - t*0.6, 1 - t*0.6, 1)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE/2, -PLAYER_SIZE/2)
    love.graphics.pop()

    love.graphics.pop()

    -- UI
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(font)

    local barW, barH = 200, 18
    local px = 20
    local py = 20
    drawHPBar(px, py, barW, barH, cube.hp, PLAYER_HP_MAX, {0.3, 0.85, 0.35})

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("HP " .. math.max(0, cube.hp) .. " / " .. PLAYER_HP_MAX,
        px, py + 22, barW, "left")

    local e = enemy.get()
    if e then
        local epx = love.graphics.getWidth() - barW - 20
        local epy = 20
        drawHPBar(epx, epy, barW, barH, e.hp, 10, {0.9, 0.2, 0.2})
        
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ENEMY " .. math.max(0, e.hp) .. " / 10",
            epx, epy + 22, barW, "right")
    end

    -- ЭЛЕМЕНТЫ УПРАВЛЕНИЯ
    controls.draw()
end

-- ========== ОБРАБОТЧИКИ ТАЧ ==========
function game.touchpressed(id, x, y)
    controls.touchpressed(id, x, y)
end

function game.touchmoved(id, x, y)
    controls.touchmoved(id, x, y)
end

function game.touchreleased(id, x, y)
    local shot, dx, dy = controls.touchreleased(id)
    if shot then
        spawnBullet(cube.x, cube.y, dx, dy)
    end
end

-- ========== ВЫСТРЕЛ С КЛАВИАТУРЫ (ПРОБЕЛ) ==========
function game.spawnPlayerBullet(dx, dy)
    if dead then return end
    spawnBullet(cube.x, cube.y, dx, dy)
end

return game

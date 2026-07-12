local controls = require("controls")
local enemy = require("enemy")
local online = require("online")

local game = {}

-- Переменные игрока
local PLAYER_SIZE = 55
local PLAYER_HP_MAX = 5
local BULLET_SPEED = 390
local cube = { x = 0, y = 0, speed = 260, angle = 0, hp = PLAYER_HP_MAX, hit = 0 }
local bullets = {}
local cam = { x = 0, y = 0 }
local dead = false

-- Ресурсы
local bg, playerImg, azumImg, nastyaImg, bukImg, font
local snowflakes = {}

-- Способности
local equippedSkin = "NONE"
local resurrectionUsed = false
local laserCooldown = 0
local LASER_COOLDOWN = 15
local laserActive = false
local laserTimer = 0
local LASER_DURATION = 0.15
local laserEndX, laserEndY = 0, 0
local LASER_RANGE = 800

local dashCooldown = 0
local dashTimer = 0
local isDashing = false
local DASH_DURATION = 0.2
local DASH_SPEED_MULT = 4
local DASH_COOLDOWN = 10
local dashDirX, dashDirY = 0, 0

-- ============================================================
--  6-ЛУЧЕВОЙ СНЕГ
-- ============================================================
local function drawRealSnowflake(x, y, size, alpha, rotation, twinkle)
    love.graphics.setColor(1, 1, 1, alpha * twinkle)
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    for i = 0, 5 do
        local angle = i * math.pi / 3
        love.graphics.push()
        love.graphics.rotate(angle)
        love.graphics.setLineWidth(1)
        love.graphics.line(0, 0, size * 3, 0)
        for j = 1, 2 do
            local pos = j * (size * 1.5)
            love.graphics.line(pos, -size * 0.8, pos, size * 0.8)
        end
        love.graphics.pop()
    end
    love.graphics.pop()
end

local function initSnow()
    local w, h = love.graphics.getDimensions()
    snowflakes = {}
    for i = 1, 120 do
        table.insert(snowflakes, {
            x = math.random(0, 2000), y = math.random(0, 2000),
            size = 2 + math.random(3), speed = 40 + math.random(50),
            phase = math.random() * 10, rot = math.random() * 6
        })
    end
end

-- ============================================================
--  ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ============================================================
local function spawnBullet(x, y, dx, dy, isDash)
    table.insert(bullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED, vy = dy * BULLET_SPEED,
        life = 3, damage = isDash and 3 or 1, isDash = isDash
    })
    if _G.playShootSound then _G.playShootSound() end
end

local function drawHPBar(x, y, w, h, hp, max, color)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x-2, y-2, w+4, h+4, 5)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", x, y, w * (math.max(0, hp)/max), h, 3)
end

function game.load()
    local w, h = love.graphics.getDimensions()
    cube.x, cube.y = w/2, h/2
    cube.hp = PLAYER_HP_MAX
    bullets = {}
    dead = false
    resurrectionUsed = false
    
    bg = love.graphics.newImage("snow.png")
    bg:setWrap("repeat", "repeat")
    playerImg = love.graphics.newImage("player.png")
    azumImg = love.graphics.newImage("azum.png")
    nastyaImg = love.graphics.newImage("nastya.png")
    bukImg = love.graphics.newImage("buk.png")
    font = love.graphics.newFont(18)

    equippedSkin = SAVE_DATA.equippedSkin or "NONE"
    
    if not online.isConnected() then
        enemy.setDifficulty(_G.difficulty or "normal")
        enemy.reset()
    end
    initSnow()
end

function game.resize(w, h) initSnow() end

function game.update(dt)
    if dead then return end

    -- Движение
    local dx, dy = controls.getMove()
    if isDashing then
        cube.x = cube.x + dashDirX * cube.speed * DASH_SPEED_MULT * dt
        cube.y = cube.y + dashDirY * cube.speed * DASH_SPEED_MULT * dt
        dashTimer = dashTimer - dt
        if dashTimer <= 0 then isDashing = false end
    else
        cube.x = cube.x + dx * cube.speed * dt
        cube.y = cube.y + dy * cube.speed * dt
    end

    if dx ~= 0 or dy ~= 0 then cube.angle = math.atan2(dy, dx) + math.pi / 2 end

    -- Способности (Твоя логика)
    laserCooldown = math.max(0, laserCooldown - dt)
    dashCooldown = math.max(0, dashCooldown - dt)
    
    if controls.getAbilityTrigger() then
        if equippedSkin == "AZUM CUBE" and not resurrectionUsed and cube.hp <= 1 then
            cube.hp = 5; resurrectionUsed = true
        elseif equippedSkin == "NASTYA CUBE" and laserCooldown <= 0 then
            laserActive = true; laserTimer = LASER_DURATION; laserCooldown = LASER_COOLDOWN
            local ax, ay = controls.getAim(); laserEndX = cube.x + ax * LASER_RANGE; laserEndY = cube.y + ay * LASER_RANGE
            if not online.isConnected() then enemy.takeDamage(3) end
        elseif equippedSkin == "BUK CUBE" and dashCooldown <= 0 then
            isDashing = true; dashTimer = DASH_DURATION; dashCooldown = DASH_COOLDOWN
            local adx, ady = controls.getAim(); spawnBullet(cube.x, cube.y, adx, ady, true)
        end
    end

    -- Камера
    local sw, sh = love.graphics.getDimensions()
    cam.x = cam.x + (cube.x - sw/2 - cam.x) * dt * 6
    cam.y = cam.y + (cube.y - sh/2 - cam.y) * dt * 6

    -- Пули
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt; b.y = b.y + b.vy * dt; b.life = b.life - dt
        if b.life <= 0 then table.remove(bullets, i) end
    end

    -- Враг и Оффлайн логика
    if not online.isConnected() then
        local killed = enemy.update(dt, cube.x, cube.y, bullets, function() cube.hp = cube.hp - 1 end)
        if killed then SAVE_DATA.coins = SAVE_DATA.coins + 10; SAVE_SAVE(); GameState.current = "lobby" end
        
        local eb = enemy.getBullets()
        for i = #eb, 1, -1 do
            local b = eb[i]
            if math.sqrt((b.x-cube.x)^2 + (b.y-cube.y)^2) < 30 then
                cube.hp = cube.hp - 1; table.remove(eb, i)
                if cube.hp <= 0 then dead = true; GameState.current = "lobby" end
            end
        end
    end
end

function game.draw()
    love.graphics.push()
    love.graphics.translate(-cam.x, -cam.y)

    -- Фон
    local tw, th = bg:getDimensions()
    for x = -1, 5 do for y = -1, 5 do love.graphics.draw(bg, cam.x + x*tw, cam.y + y*th) end end

    -- Снег
    for _, s in ipairs(snowflakes) do
        drawRealSnowflake(s.x, s.y, s.size, 0.6, s.rot, 1)
    end

    -- ДРУГИЕ ИГРОКИ (ОНЛАЙН)
    if online.isConnected() then
        for id, p in pairs(online.getPlayers()) do
            local img = (p.skin == "AZUM CUBE") and azumImg or (p.skin == "NASTYA CUBE") and nastyaImg or (p.skin == "BUK CUBE") and bukImg or playerImg
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(img, p.x - PLAYER_SIZE/2, p.y - PLAYER_SIZE/2)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle("fill", p.x - 50, p.y - 50, 100, 20, 5)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.printf(p.nickname, p.x - 50, p.y - 48, 100, "center")
        end
    else
        enemy.drawBullets()
        enemy.draw()
    end

    -- Лазер
    if laserActive then
        love.graphics.setLineWidth(10); love.graphics.setColor(1, 0, 0, 0.5)
        love.graphics.line(cube.x, cube.y, laserEndX, laserEndY)
        laserTimer = laserTimer - love.timer.getDelta()
        if laserTimer <= 0 then laserActive = false end
    end

    -- Игрок
    local myImg = (equippedSkin == "AZUM CUBE") and azumImg or (equippedSkin == "NASTYA CUBE") and nastyaImg or (equippedSkin == "BUK CUBE") and bukImg or playerImg
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push(); love.graphics.translate(cube.x, cube.y); love.graphics.rotate(cube.angle)
    love.graphics.draw(myImg, -PLAYER_SIZE/2, -PLAYER_SIZE/2)
    love.graphics.pop()

    -- Пули
    for _, b in ipairs(bullets) do
        love.graphics.setColor(b.isDash and {1, 0.5, 0} or {0, 0, 0})
        love.graphics.circle("fill", b.x, b.y, b.isDash and 12 or 8)
    end

    love.graphics.pop()

    -- UI
    drawHPBar(20, 20, 200, 20, cube.hp, PLAYER_HP_MAX, {0.2, 0.8, 0.2})
    love.graphics.setColor(1, 1, 1); love.graphics.print("HP: " .. cube.hp, 25, 20)
    
    if not online.isConnected() then
        local e, _, eMax = enemy.get()
        if e then drawHPBar(love.graphics.getWidth()-220, 20, 200, 20, e.hp, eMax, {0.8, 0.2, 0.2}) end
    end
end

function game.spawnPlayerBullet(dx, dy)
    spawnBullet(cube.x, cube.y, dx, dy, false)
end

function game.getPlayerPosition() return cube.x, cube.y end

return game

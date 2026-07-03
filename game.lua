local controls = require("controls")
local enemy = require("enemy")

local game = {}

SAVE_DATA = SAVE_DATA or { coins = 0, ownedSkin = "NONE", equippedSkin = "NONE" }
SAVE_SAVE = SAVE_SAVE or function() end

local PLAYER_SIZE = 55
local PLAYER_HP_MAX = 5
local BULLET_SPEED = 340 * 1.15

local cube = { x = 0, y = 0, speed = 260, angle = 0, hp = PLAYER_HP_MAX, hit = 0 }
local bullets = {}
local bg, playerImg, azumImg, nastyaImg, bukImg, font
local cam = { x = 0, y = 0 }
local dead = false

local equippedSkin = "NONE"
local resurrectionUsed = false
local currentDifficulty = "normal"

-- ЛАЗЕР (вместо щита)
local laserCooldown = 0
local LASER_COOLDOWN = 5   -- секунд

-- Рывок (BUK CUBE)
local dashCooldown = 0
local dashTimer = 0
local isDashing = false
local DASH_DURATION = 0.2
local DASH_SPEED_MULT = 4
local DASH_COOLDOWN = 10
local dashDirX, dashDirY = 0, 0

-- --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---

local function spawnBullet(x, y, dx, dy)
    table.insert(bullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED,
        vy = dy * BULLET_SPEED,
        dirX = dx, dirY = dy,
        life = 3,
        isDash = false,
        damage = 1
    })
    if _G.playShootSound then _G.playShootSound() end
end

local function spawnDashBullet(x, y, dx, dy)
    table.insert(bullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED,
        vy = dy * BULLET_SPEED,
        dirX = dx, dirY = dy,
        life = 3,
        isDash = true,
        damage = 3
    })
    if _G.playShootSound then _G.playShootSound() end
end

-- Новая функция для лазерного выстрела
local function spawnLaserBullet(x, y, dx, dy)
    if dx == 0 and dy == 0 then
        dx, dy = 0, -1
    end
    local len = math.sqrt(dx*dx + dy*dy)
    if len > 0 then
        dx, dy = dx/len, dy/len
    end
    table.insert(bullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED * 1.5,   -- быстрее обычной
        vy = dy * BULLET_SPEED * 1.5,
        dirX = dx, dirY = dy,
        life = 4,
        isDash = false,
        isLaser = true,                 -- метка для отрисовки
        damage = 5                      -- высокий урон
    })
    if _G.playShootSound then _G.playShootSound() end
end

local function drawHPBar(x, y, w, h, hp, max, color)
    if hp < 0 then hp = 0 end
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, 6, 6)
    love.graphics.setColor(0.15, 0.15, 0.15, 1)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", x, y, w * (hp / max), h, 4, 4)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
end

local function onHitPlayer(dmg)
    if dead then return end
    -- Щита больше нет, урон всегда проходит
    cube.hp = cube.hp - dmg
    cube.hit = 1
    if _G.playHitSound then _G.playHitSound() end
    if cube.hp <= 0 then
        cube.hp = 0
        dead = true
        GameState.current = "lobby"
    end
end

-- --- ЗАГРУЗКА И ОБНОВЛЕНИЕ ---

function game.load()
    currentDifficulty = _G.difficulty or "normal"
    enemy.setDifficulty(currentDifficulty)

    equippedSkin = SAVE_DATA.equippedSkin or "NONE"
    resurrectionUsed = false

    -- Инициализация лазера
    laserCooldown = 0

    dashCooldown = 0
    dashTimer = 0
    isDashing = false

    cube.x, cube.y = 0, 0
    cube.angle = 0
    cube.hp = PLAYER_HP_MAX
    cube.hit = 0
    dead = false
    bullets = {}
    cam.x, cam.y = -love.graphics.getWidth() / 2, -love.graphics.getHeight() / 2

    bg = bg or love.graphics.newImage("grass.png")
    bg:setWrap("repeat", "repeat")
    playerImg = playerImg or love.graphics.newImage("player.png")
    playerImg:setFilter("nearest", "nearest")
    azumImg = azumImg or love.graphics.newImage("azum.png")
    azumImg:setFilter("nearest", "nearest")
    nastyaImg = nastyaImg or love.graphics.newImage("nastya.png")
    nastyaImg:setFilter("nearest", "nearest")
    bukImg = bukImg or love.graphics.newImage("buk.png")
    bukImg:setFilter("nearest", "nearest")
    font = font or love.graphics.newFont("Fredoka-Bold.ttf", 18)

    controls.load()
    enemy.load()
    enemy.reset()
end

function game.resize()
    controls.resize()
end

function game.update(dt)
    if dead then return end

    controls.update(dt)

    -- Обновление лазера
    laserCooldown = math.max(0, laserCooldown - dt)

    -- Обновление рывка (BUK)
    if dashCooldown > 0 then
        dashCooldown = dashCooldown - dt
        if dashCooldown < 0 then dashCooldown = 0 end
    end

    -- Обработка активации способности
    if controls.getAbilityTrigger() then
        if equippedSkin == "AZUM CUBE" and not resurrectionUsed and cube.hp <= 1 then
            cube.hp = 5
            resurrectionUsed = true
            cube.hit = 0
            controls.setAbilityAvailable(false)
        elseif equippedSkin == "NASTYA CUBE" and laserCooldown <= 0 then
            -- ЛАЗЕР
            local aimX, aimY = controls.getAim()
            spawnLaserBullet(cube.x, cube.y, aimX, aimY)
            laserCooldown = LASER_COOLDOWN
            controls.setAbilityAvailable(false)
        elseif equippedSkin == "BUK CUBE" and not isDashing and dashCooldown <= 0 then
            -- Рывок
            local dx, dy = controls.getMove()
            if dx == 0 and dy == 0 then
                dx, dy = controls.getAim()
            end
            if dx ~= 0 or dy ~= 0 then
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    dashDirX, dashDirY = dx/len, dy/len
                else
                    dashDirX, dashDirY = 0, -1
                end
            else
                dashDirX, dashDirY = 0, -1
            end
            isDashing = true
            dashTimer = DASH_DURATION
            dashCooldown = DASH_COOLDOWN
            controls.setAbilityAvailable(false)
            spawnDashBullet(cube.x, cube.y, dashDirX, dashDirY)
        end
    end

    -- Обновление состояния доступности способностей
    if equippedSkin == "AZUM CUBE" then
        controls.setAbilityAvailable(not resurrectionUsed and cube.hp <= 1)
    elseif equippedSkin == "NASTYA CUBE" then
        controls.setAbilityAvailable(laserCooldown <= 0)
    elseif equippedSkin == "BUK CUBE" then
        controls.setAbilityAvailable(not isDashing and dashCooldown <= 0)
    else
        controls.setAbilityAvailable(false)
    end

    -- Движение игрока
    local dx, dy = controls.getMove()
    cube.x = cube.x + dx * cube.speed * dt
    cube.y = cube.y + dy * cube.speed * dt
    if dx ~= 0 or dy ~= 0 then
        cube.angle = math.atan2(dy, dx) + math.pi / 2
    end
    cube.hit = math.max(0, cube.hit - dt * 3)

    -- Рывок (дополнительное перемещение)
    if isDashing then
        dashTimer = dashTimer - dt
        cube.x = cube.x + dashDirX * cube.speed * DASH_SPEED_MULT * dt
        cube.y = cube.y + dashDirY * cube.speed * DASH_SPEED_MULT * dt
        if dashTimer <= 0 then
            isDashing = false
        end
    end

    -- Камера
    local targetX = cube.x - love.graphics.getWidth() / 2
    local targetY = cube.y - love.graphics.getHeight() / 2
    local k = 1 - math.exp(-dt * 7.3)
    cam.x = cam.x + (targetX - cam.x) * k
    cam.y = cam.y + (targetY - cam.y) * k

    -- Обновление пуль игрока
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 then table.remove(bullets, i) end
    end

    -- Обновление врага (передаём пули игрока)
    local enemyKilled = enemy.update(dt, cube.x, cube.y, bullets, onHitPlayer)
    if enemyKilled then
        local reward = 10
        if currentDifficulty == "easy" then reward = 5
        elseif currentDifficulty == "hard" then reward = 50
        elseif currentDifficulty == "impossible" then reward = 100 end
        SAVE_DATA.coins = (SAVE_DATA.coins or 0) + reward
        SAVE_SAVE()
        GameState.current = "lobby"
        return
    end

    -- Проверка попадания вражеских пуль в игрока
    local eBullets = enemy.getBullets()
    for i = #eBullets, 1, -1 do
        local b = eBullets[i]
        local bx = b.x - cube.x
        local by = b.y - cube.y
        if bx * bx + by * by <= (PLAYER_SIZE * 0.5) ^ 2 then
            onHitPlayer(1)
            table.remove(eBullets, i)
            if dead then return end
        end
    end
end

-- --- ОТРИСОВКА ---

function game.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(-cam.x, -cam.y)

    -- Фон
    local w, h = love.graphics.getDimensions()
    local tw, th = bg:getWidth(), bg:getHeight()
    local sX = math.floor(cam.x / tw) * tw
    local sY = math.floor(cam.y / th) * th
    for x = sX, sX + w + tw, tw do
        for y = sY, sY + h + th, th do
            love.graphics.draw(bg, x, y)
        end
    end

    -- Пули игрока (обычные – чёрные, рывка – белые большие, лазер – красные)
    for _, b in ipairs(bullets) do
        if b.isLaser then
            love.graphics.setColor(1, 0.1, 0.1, 1)
            love.graphics.circle("fill", b.x, b.y, 16)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.circle("fill", b.x, b.y, 10)
            love.graphics.setColor(0, 0, 0, 0.5)
            love.graphics.circle("line", b.x, b.y, 16)
        elseif b.isDash then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("fill", b.x, b.y, 12)
            love.graphics.setColor(0, 0, 0, 0.3)
            love.graphics.circle("line", b.x, b.y, 12)
        else
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.circle("fill", b.x, b.y, 8)
        end
    end
    enemy.drawBullets()

    -- Линия прицела
    if controls.isAiming() then
        local ax, ay = controls.getAim()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.setLineWidth(16)
        love.graphics.line(cube.x, cube.y, cube.x + ax * 180, cube.y + ay * 180)
    end

    enemy.draw()

    -- Выбор спрайта игрока
    local imgToDraw
    if equippedSkin == "AZUM CUBE" then
        imgToDraw = azumImg
    elseif equippedSkin == "NASTYA CUBE" then
        imgToDraw = nastyaImg
    elseif equippedSkin == "BUK CUBE" then
        imgToDraw = bukImg
    else
        imgToDraw = playerImg
    end

    -- Тень
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.push()
    love.graphics.translate(cube.x + 6, cube.y + 8)
    love.graphics.rotate(cube.angle)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE / 2, -PLAYER_SIZE / 2)
    love.graphics.pop()

    -- Игрок
    love.graphics.push()
    love.graphics.translate(cube.x, cube.y)
    love.graphics.rotate(cube.angle)
    local t = cube.hit
    love.graphics.setColor(1, 1 - t * 0.6, 1 - t * 0.6, 1)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE / 2, -PLAYER_SIZE / 2)
    love.graphics.pop()

    -- Эффект рывка (опционально)
    if isDashing then
        love.graphics.setColor(1, 1, 1, 0.3)
        love.graphics.circle("fill", cube.x, cube.y, PLAYER_SIZE * 1.2)
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", cube.x, cube.y, PLAYER_SIZE * 1.2)
    end

    love.graphics.pop()

    -- HUD
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    local barW, barH = 200, 18
    local px, py = 20, 20
    drawHPBar(px, py, barW, barH, cube.hp, PLAYER_HP_MAX, {0.3, 0.85, 0.35})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("HP " .. math.max(0, cube.hp) .. " / " .. PLAYER_HP_MAX, px, py + 22, barW, "left")

    local diffText = "NORMAL"
    if currentDifficulty == "easy" then diffText = "EASY" end
    if currentDifficulty == "hard" then diffText = "HARD" end
    if currentDifficulty == "impossible" then diffText = "IMPOSSIBLE" end
    love.graphics.printf("DIFFICULTY: " .. diffText, px, py + 44, 200, "left")

    -- Отображение статуса способности BUK CUBE
    if equippedSkin == "BUK CUBE" then
        local cd = math.max(0, dashCooldown)
        if isDashing then
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("DASH!", px, py + 66, 200, "left")
        elseif cd > 0 then
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            love.graphics.printf("DASH CD: " .. math.ceil(cd) .. "s", px, py + 66, 200, "left")
        else
            love.graphics.setColor(1, 1, 1, 0.8)
            love.graphics.printf("DASH READY", px, py + 66, 200, "left")
        end
    elseif equippedSkin == "NASTYA CUBE" then
        local cd = math.max(0, laserCooldown)
        if cd > 0 then
            love.graphics.setColor(0.8, 0.8, 0.8, 0.8)
            love.graphics.printf("LASER CD: " .. math.ceil(cd) .. "s", px, py + 66, 200, "left")
        else
            love.graphics.setColor(1, 0.2, 0.2, 0.8)
            love.graphics.printf("LASER READY", px, py + 66, 200, "left")
        end
    end

    -- ХП врага
    local e, _, enemyMaxHP = enemy.get()
    if e then
        local epx = love.graphics.getWidth() - barW - 20
        local epy = 20
        drawHPBar(epx, epy, barW, barH, e.hp, enemyMaxHP, {0.9, 0.2, 0.2})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ENEMY " .. math.max(0, e.hp) .. " / " .. enemyMaxHP, epx, epy + 22, barW, "right")
    end

    controls.draw()
end

-- --- ОБРАБОТКА ВВОДА ---

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

function game.spawnPlayerBullet(dx, dy)
    if dead then return end
    spawnBullet(cube.x, cube.y, dx, dy)
end

return game

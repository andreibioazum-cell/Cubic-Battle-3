local controls = require("controls")
local enemy = require("enemy")

local game = {}

SAVE_DATA = SAVE_DATA or { coins = 0, hasAzumSkin = false }
SAVE_SAVE = SAVE_SAVE or function() end

local PLAYER_SIZE = 55
local PLAYER_HP_MAX = 5
local BULLET_SPEED = 340 * 1.15

local cube = { x = 0, y = 0, speed = 260, angle = 0, hp = PLAYER_HP_MAX, hit = 0 }
local bullets = {}
local bg, playerImg, azumImg, font
local cam = { x = 0, y = 0 }
local dead = false

local hasAzumSkin = false
local resurrectionUsed = false

local function spawnBullet(x, y, dx, dy)
    table.insert(bullets, {
        x = x, y = y,
        vx = dx * BULLET_SPEED,
        vy = dy * BULLET_SPEED,
        dirX = dx, dirY = dy,
        life = 3
    })
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
    cube.hp = cube.hp - dmg
    cube.hit = 1
    if cube.hp <= 0 then
        cube.hp = 0
        dead = true
        GameState.current = "lobby"
    end
end

function game.load(hasAzum)
    hasAzumSkin = hasAzum or false
    resurrectionUsed = false
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

    if controls.getAbilityTrigger() then
        if hasAzumSkin and not resurrectionUsed and cube.hp <= 1 then
            cube.hp = 5
            resurrectionUsed = true
            cube.hit = 0
        end
    end

    local dx, dy = controls.getMove()
    cube.x = cube.x + dx * cube.speed * dt
    cube.y = cube.y + dy * cube.speed * dt
    if dx ~= 0 or dy ~= 0 then
        cube.angle = math.atan2(dy, dx) + math.pi / 2
    end
    cube.hit = math.max(0, cube.hit - dt * 3)

    local targetX = cube.x - love.graphics.getWidth() / 2
    local targetY = cube.y - love.graphics.getHeight() / 2
    local k = 1 - math.exp(-dt * 7.3)
    cam.x = cam.x + (targetX - cam.x) * k
    cam.y = cam.y + (targetY - cam.y) * k

    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx * dt
        b.y = b.y + b.vy * dt
        b.life = b.life - dt
        if b.life <= 0 then
            table.remove(bullets, i)
        end
    end

    local enemyKilled = enemy.update(dt, cube.x, cube.y, bullets, onHitPlayer)
    if enemyKilled then
        SAVE_DATA.coins = (SAVE_DATA.coins or 0) + 10
        SAVE_SAVE()
        GameState.current = "lobby"
        return
    end

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
end   -- <-- ВАЖНО: ЭТОТ END ЗАКРЫВАЕТ game.update

function game.draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(-cam.x, -cam.y)

    local w, h = love.graphics.getDimensions()
    local tw, th = bg:getWidth(), bg:getHeight()
    local sX = math.floor(cam.x / tw) * tw
    local sY = math.floor(cam.y / th) * th
    for x = sX, sX + w + tw, tw do
        for y = sY, sY + h + th, th do
            love.graphics.draw(bg, x, y)
        end
    end

    love.graphics.setColor(0, 0, 0, 1)
    for _, b in ipairs(bullets) do
        love.graphics.circle("fill", b.x, b.y, 8)
    end
    enemy.drawBullets()

    if controls.isAiming() then
        local ax, ay = controls.getAim()
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.setLineWidth(16)
        love.graphics.line(cube.x, cube.y, cube.x + ax * 180, cube.y + ay * 180)
    end

    enemy.draw()

    local imgToDraw = hasAzumSkin and azumImg or playerImg
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.push()
    love.graphics.translate(cube.x + 6, cube.y + 8)
    love.graphics.rotate(cube.angle)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE / 2, -PLAYER_SIZE / 2)
    love.graphics.pop()

    love.graphics.push()
    love.graphics.translate(cube.x, cube.y)
    love.graphics.rotate(cube.angle)
    local t = cube.hit
    love.graphics.setColor(1, 1 - t * 0.6, 1 - t * 0.6, 1)
    love.graphics.draw(imgToDraw, -PLAYER_SIZE / 2, -PLAYER_SIZE / 2)
    love.graphics.pop()

    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setFont(font)
    local barW, barH = 200, 18
    local px, py = 20, 20
    drawHPBar(px, py, barW, barH, cube.hp, PLAYER_HP_MAX, {0.3, 0.85, 0.35})
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("HP " .. math.max(0, cube.hp) .. " / " .. PLAYER_HP_MAX, px, py + 22, barW, "left")

    local e = enemy.get()
    if e then
        local epx = love.graphics.getWidth() - barW - 20
        local epy = 20
        drawHPBar(epx, epy, barW, barH, e.hp, 10, {0.9, 0.2, 0.2})
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("ENEMY " .. math.max(0, e.hp) .. " / 10", epx, epy + 22, barW, "right")
    end

    controls.draw()
end   -- <-- ЭТОТ END ЗАКРЫВАЕТ game.draw

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

return game   -- <-- КОНЕЦ ФАЙЛА

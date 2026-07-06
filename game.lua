function game.load()
    -- Определяем режим (онлайн или офлайн)
    isOnlineMode = (GameState.current == "online")

    -- Если одиночный режим – загружаем врага
    if not isOnlineMode then
        currentDifficulty = _G.difficulty or "normal"
        enemy.setDifficulty(currentDifficulty)
        enemy.reset()
    else
        -- В онлайн-режиме врага нет, но сбрасываем на всякий случай
        enemy.reset()
    end

    -- Загружаем скин из сохранения
    equippedSkin = SAVE_DATA.equippedSkin or "NONE"
    resurrectionUsed = false

    -- Сбрасываем способности
    laserCooldown = 0
    laserActive = false
    laserTimer = 0
    dashCooldown = 0
    dashTimer = 0
    isDashing = false

    -- Начальные координаты игрока
    cube.x, cube.y = 0, 0
    cube.angle = 0
    cube.hp = PLAYER_HP_MAX
    cube.hit = 0
    dead = false
    bullets = {}

    -- Камера (центрируем на игроке)
    cam.x, cam.y = -love.graphics.getWidth() / 2, -love.graphics.getHeight() / 2

    -- Загружаем текстуры (если ещё не загружены)
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

    -- Шрифт для HUD
    font = font or love.graphics.newFont("Fredoka-Bold.ttf", 18)

    -- Загружаем контролы и врага (для enemy.load() – даже если не используется, он просто инициализирует изображение)
    controls.load()
    enemy.load()
end

-- settings.lua – настройки (исправлен)
local settings = {}

local fontTitle, fontBtn, fontInput
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnMusic = { w = 220, h = 75, x = 0, y = 0 }
local btnSfx   = { w = 220, h = 75, x = 0, y = 0 }

local nickname = ""
local inputActive = false
local inputField = { x = 0, y = 0, w = 250, h = 50 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
local hoverBtn = nil
local animTime = 0

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

local function drawSpacedText(text, x, y, w, align, font, alpha)
    alpha = alpha or 1
    love.graphics.setFont(font)
    local tw = font:getWidth(text)
    local startX = x
    if align == "center" then
        startX = x + (w - tw) / 2
    elseif align == "right" then
        startX = x + (w - tw)
    end
    local shadow = 2
    love.graphics.setColor(0, 0, 0, alpha * 0.8)
    love.graphics.print(text, startX + shadow, y + shadow)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, startX, y)
end

function settings.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 80 * scale

    btnMusic.w = 220 * scale
    btnMusic.h = 75 * scale
    btnSfx.w = 220 * scale
    btnSfx.h = 75 * scale

    btnMusic.x = (w - btnMusic.w) / 2
    btnMusic.y = h/2 - 140 * scale

    btnSfx.x = (w - btnSfx.w) / 2
    btnSfx.y = h/2 - 40 * scale

    inputField.w = 280 * scale
    inputField.h = 55 * scale
    inputField.x = (w - inputField.w) / 2
    inputField.y = h/2 + 50 * scale

    nickname = SAVE_DATA.nickname or "Player"

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    local inputSize = math.max(22, 30 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
    fontInput = love.graphics.newFont("Fredoka-Bold.ttf", inputSize)
end

function settings.resize()
    settings.load()
end

function settings.update(dt)
    animTime = animTime + dt
end

function settings.draw()
    love.graphics.setColor(0.02, 0.05, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("SETTINGS", 0, 80*scale, w, "center", fontTitle, 1)

    -- Отрисовка кнопок с эффектом наведения
    local function drawButton(btn, text, color, isHover)
        local r, g, b = color[1], color[2], color[3]
        if isHover then
            r = math.min(1, r + 0.15)
            g = math.min(1, g + 0.15)
            b = math.min(1, b + 0.15)
        end
        
        local shadowOffset = isHover and 4 or 5
        love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
        love.graphics.rectangle("fill", btn.x + shadowOffset * scale, btn.y + (shadowOffset + 1) * scale, btn.w, btn.h, 16*scale, 16*scale)
        
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4 * scale)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 16*scale, 16*scale)
        
        if isHover then
            love.graphics.setColor(0.6, 0.8, 1, 0.3 + 0.3 * math.sin(animTime * 3))
            love.graphics.setLineWidth(2 * scale)
            love.graphics.rectangle("line", btn.x + 2*scale, btn.y + 2*scale, btn.w - 4*scale, btn.h - 4*scale, 14*scale, 14*scale)
        end
        
        drawSpacedText(text, btn.x, btn.y + 22*scale, btn.w, "center", fontBtn, 1)
    end

    local musicText = musicOn and "MUSIC: ON" or "MUSIC: OFF"
    local musicColor = musicOn and {0.2, 0.5, 0.9} or {0.5, 0.5, 0.5}
    drawButton(btnMusic, musicText, musicColor, hoverBtn == "music")

    local sfxText = sfxOn and "SOUNDS: ON" or "SOUNDS: OFF"
    local sfxColor = sfxOn and {0.2, 0.5, 0.9} or {0.5, 0.5, 0.5}
    drawButton(btnSfx, sfxText, sfxColor, hoverBtn == "sfx")

    -- Поле ввода никнейма
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", inputField.x + 3*scale, inputField.y + 3*scale, inputField.w, inputField.h, 8*scale, 8*scale)
    love.graphics.setColor(0.1, 0.1, 0.1, 1)
    love.graphics.rectangle("fill", inputField.x, inputField.y, inputField.w, inputField.h, 8*scale, 8*scale)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2.4 * scale)
    if inputActive then
        love.graphics.setColor(1, 1, 1, 1)
    else
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
    end
    love.graphics.rectangle("line", inputField.x, inputField.y, inputField.w, inputField.h, 8*scale, 8*scale)

    local displayName = nickname
    if inputActive and love.timer.getTime() % 1 < 0.5 then
        displayName = displayName .. "_"
    end
    love.graphics.setFont(fontInput)
    love.graphics.setColor(1, 1, 1, 1)
    local th = fontInput:getHeight()
    love.graphics.print(displayName, inputField.x + 15*scale, inputField.y + (inputField.h - th)/2)

    love.graphics.setFont(fontBtn)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("NICKNAME", inputField.x, inputField.y - 35*scale, inputField.w, "center")

    drawButton(btnBack, "BACK", {0.2, 0.5, 0.9}, hoverBtn == "back")
end

function settings.mousemoved(x, y)
    if isMobile then return end
    
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnMusic) then
        hoverBtn = "music"
    elseif isInside(btnSfx) then
        hoverBtn = "sfx"
    elseif isInside(btnBack) then
        hoverBtn = "back"
    else
        hoverBtn = nil
    end
end

function settings.touchpressed(id, x, y)
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btnBack) then
        playButtonSound()
        GameState.current = "lobby"
        SAVE_DATA.nickname = nickname
        SAVE_SAVE()
        return
    end

    if isInside(btnMusic) then
        playButtonSound()
        toggleMusic()
        SAVE_SAVE()
        return
    end

    if isInside(btnSfx) then
        playButtonSound()
        toggleSfx()
        SAVE_SAVE()
        return
    end

    if x >= inputField.x and x <= inputField.x + inputField.w and
       y >= inputField.y and y <= inputField.y + inputField.h then
        inputActive = not inputActive
        if inputActive then
            love.keyboard.setTextInput(true)
            love.keyboard.setKeyRepeat(true)
        else
            love.keyboard.setTextInput(false)
            love.keyboard.setKeyRepeat(false)
            SAVE_DATA.nickname = nickname
            SAVE_SAVE()
        end
    end
end

function settings.touchmoved(id, x, y)
    if isMobile then
        local function isInside(btn)
            return x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h
        end
        
        if isInside(btnMusic) then
            hoverBtn = "music"
        elseif isInside(btnSfx) then
            hoverBtn = "sfx"
        elseif isInside(btnBack) then
            hoverBtn = "back"
        else
            hoverBtn = nil
        end
    end
end

function settings.touchreleased(id, x, y)
    if isMobile then
        hoverBtn = nil
    end
end

function settings.keypressed(key)
    if not inputActive then return
    if key == "return" or key == "kpenter" then
        inputActive = false
        love.keyboard.setTextInput(false)
        love.keyboard.setKeyRepeat(false)
        SAVE_DATA.nickname = nickname
        SAVE_SAVE()
        return
    end
    if key == "backspace" then
        nickname = nickname:sub(1, -2)
        SAVE_DATA.nickname = nickname
        SAVE_SAVE()
        return
    end
end

function settings.textinput(t)
    if inputActive then
        local filtered = ""
        for i = 1, #t do
            local b = t:byte(i)
            if b >= 32 and b <= 126 then
                filtered = filtered .. string.char(b)
            end
        end
        nickname = nickname .. filtered
        if #nickname > 20 then nickname = nickname:sub(1, 20) end
        SAVE_DATA.nickname = nickname
        SAVE_SAVE()
    end
end

return settings

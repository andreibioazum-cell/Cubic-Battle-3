local settings = {}

local fontTitle, fontBtn, fontInput
local btnBack = { w = 140, h = 55, x = 0, y = 30 }
local btnMusic = { w = 220, h = 75, x = 0, y = 0 }
local btnSfx   = { w = 220, h = 75, x = 0, y = 0 }

local nickname = ""
local inputActive = false
local inputField = { x = 0, y = 0, w = 250, h = 50 }

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

local function drawSpacedText(text, x, y, w, align, font, spacing, alpha)
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

function settings.draw()
    love.graphics.setColor(0.02, 0.05, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("SETTINGS", 0, 80*scale, w, "center", fontTitle, nil, 1)

    -- Music button
    local musicText = musicOn and "MUSIC: ON" or "MUSIC: OFF"
    local musicColor = musicOn and {0.2, 0.5, 0.9} or {0.5, 0.5, 0.5}
    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnMusic.x + 5*scale, btnMusic.y + 6*scale, btnMusic.w, btnMusic.h, 16*scale, 16*scale)
    love.graphics.setColor(musicColor[1], musicColor[2], musicColor[3], 1)
    love.graphics.rectangle("fill", btnMusic.x, btnMusic.y, btnMusic.w, btnMusic.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnMusic.x, btnMusic.y, btnMusic.w, btnMusic.h, 16*scale, 16*scale)
    drawSpacedText(musicText, btnMusic.x, btnMusic.y + 22*scale, btnMusic.w, "center", fontBtn, nil, 1)

    -- SFX button
    local sfxText = sfxOn and "SOUNDS: ON" or "SOUNDS: OFF"
    local sfxColor = sfxOn and {0.2, 0.5, 0.9} or {0.5, 0.5, 0.5}
    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnSfx.x + 5*scale, btnSfx.y + 6*scale, btnSfx.w, btnSfx.h, 16*scale, 16*scale)
    love.graphics.setColor(sfxColor[1], sfxColor[2], sfxColor[3], 1)
    love.graphics.rectangle("fill", btnSfx.x, btnSfx.y, btnSfx.w, btnSfx.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnSfx.x, btnSfx.y, btnSfx.w, btnSfx.h, 16*scale, 16*scale)
    drawSpacedText(sfxText, btnSfx.x, btnSfx.y + 22*scale, btnSfx.w, "center", fontBtn, nil, 1)

    -- Nickname input field
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
    local tw = fontInput:getWidth(displayName)
    local th = fontInput:getHeight()
    love.graphics.print(displayName, inputField.x + 15*scale, inputField.y + (inputField.h - th)/2)

    -- Label above the field
    love.graphics.setFont(fontBtn)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf("NICKNAME", inputField.x, inputField.y - 35*scale, inputField.w, "center")

    -- Back button
    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.2, 0.5, 0.9, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("BACK", btnBack.x, btnBack.y + 14*scale, btnBack.w, "center", fontBtn, nil, 1)
end

function settings.touchpressed(id, x, y)
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        playButtonSound()
        GameState.current = "lobby"
        SAVE_DATA.nickname = nickname
        SAVE_SAVE()
        return
    end

    if x >= btnMusic.x and x <= btnMusic.x + btnMusic.w and y >= btnMusic.y and y <= btnMusic.y + btnMusic.h then
        playButtonSound()
        toggleMusic()
        SAVE_SAVE()
        return
    end

    if x >= btnSfx.x and x <= btnSfx.x + btnSfx.w and y >= btnSfx.y and y <= btnSfx.y + btnSfx.h then
        playButtonSound()
        toggleSfx()
        SAVE_SAVE()
        return
    end

    if x >= inputField.x and x <= inputField.x + inputField.w and y >= inputField.y and y <= inputField.y + inputField.h then
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

function settings.touchmoved() end
function settings.touchreleased() end

function settings.keypressed(key)
    if not inputActive then return end
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
        return
    end
    -- allow only printable ASCII (32-126)
    if key and #key == 1 and key:byte() >= 32 and key:byte() <= 126 then
        nickname = nickname .. key
        if #nickname > 20 then nickname = nickname:sub(1, 20) end
    end
end

function settings.textinput(t)
    if inputActive then
        -- filter only printable ASCII
        local filtered = ""
        for i = 1, #t do
            local b = t:byte(i)
            if b >= 32 and b <= 126 then
                filtered = filtered .. string.char(b)
            end
        end
        nickname = nickname .. filtered
        if #nickname > 20 then nickname = nickname:sub(1, 20) end
    end
end

return settings

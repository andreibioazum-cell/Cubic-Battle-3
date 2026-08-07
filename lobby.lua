-- lobby.lua – главное меню (с эффектом наведения)
local lobby = {}

local btns = {
    play = { w = 220, h = 75, x = 0, y = 0 },
    shop = { w = 220, h = 75, x = 0, y = 0 },
    settings = { w = 220, h = 75, x = 0, y = 0 },
    credits = { w = 220, h = 75, x = 0, y = 0 }
}
local fontTitle, fontSub, fontBtn
local backgroundImage
local snowflakes = {}

local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
local hoverBtn = nil
local animTime = 0

local function getScale()
    local w, h = love.graphics.getDimensions()
    local base = 1000
    if isMobile then base = 600 end
    return math.min(w, h) / base
end

local function place()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()
    local gap = 20 * scale
    local btnW = 220 * scale
    local btnH = 75 * scale

    for _, b in pairs(btns) do
        b.w = btnW
        b.h = btnH
    end

    btns.play.x = w/2 - btnW - gap/2
    btns.play.y = h/2 + 80 * scale
    btns.shop.x = w/2 + gap/2
    btns.shop.y = h/2 + 80 * scale

    btns.settings.x = w/2 - btnW - gap/2
    btns.settings.y = h/2 + 80 * scale + btnH + gap
    btns.credits.x = w/2 + gap/2
    btns.credits.y = h/2 + 80 * scale + btnH + gap
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
    local o = math.max(1.5, math.floor(2 * (scale or 1)))
    love.graphics.setColor(0, 0, 0, alpha)
    love.graphics.print(text, startX - o, y)
    love.graphics.print(text, startX + o, y)
    love.graphics.print(text, startX, y - o)
    love.graphics.print(text, startX, y + o)
    love.graphics.print(text, startX - o, y - o)
    love.graphics.print(text, startX + o, y - o)
    love.graphics.print(text, startX - o, y + o)
    love.graphics.print(text, startX + o, y + o)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.print(text, startX, y)
end

local function drawRealSnowflake(x, y, size, alpha, rotation, twinkle)
    size = size or 3
    alpha = alpha or 1
    rotation = rotation or 0
    twinkle = twinkle or 1
    
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
        love.graphics.circle("fill", size * 3, 0, size * 0.6)
        love.graphics.pop()
    end
    
    love.graphics.circle("fill", 0, 0, size * 0.8)
    love.graphics.pop()
end

local function generateSnowflakes(w, h)
    snowflakes = {}
    for i = 1, 100 do
        table.insert(snowflakes, {
            x = math.random(w),
            y = math.random(h),
            size = 2 + math.random(4),
            speed = 20 + math.random(60),
            wobble = math.random() * 2 - 1,
            phase = math.random() * 2 * math.pi,
            rotSpeed = (math.random() - 0.5) * 1.5,
            rotation = math.random() * 2 * math.pi,
            alpha = 0.6 + math.random() * 0.4,
        })
    end
end

function lobby.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    backgroundImage = love.graphics.newImage("Lobby_Snow.png")

    local titleSize = math.max(36, 72 * scale)
    local subSize   = math.max(18, 26 * scale)
    local btnSize   = math.max(22, 34 * scale)

    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontSub   = love.graphics.newFont("Fredoka-Bold.ttf", subSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)

    generateSnowflakes(w, h)
    place()
end

function lobby.resize(w, h)
    generateSnowflakes(w, h)
    place()
    local scale = getScale()
    local titleSize = math.max(36, 72 * scale)
    local subSize   = math.max(18, 26 * scale)
    local btnSize   = math.max(22, 34 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontSub   = love.graphics.newFont("Fredoka-Bold.ttf", subSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
end

function lobby.update(dt)
    animTime = animTime + dt
    local w, h = love.graphics.getDimensions()
    for _, s in ipairs(snowflakes) do
        s.y = s.y + s.speed * dt
        s.x = s.x + math.sin(s.phase + love.timer.getTime() * 0.5) * 20 * dt
        s.rotation = s.rotation + s.rotSpeed * dt
        if s.y > h + 20 then
            s.y = -20
            s.x = math.random(w)
            s.rotation = math.random() * 2 * math.pi
        end
    end
end

function lobby.draw()
    if backgroundImage then
        local w, h = love.graphics.getDimensions()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(backgroundImage, 0, 0, 0, w / backgroundImage:getWidth(), h / backgroundImage:getHeight())
    end

    for _, s in ipairs(snowflakes) do
        local twinkle = 0.7 + 0.3 * math.sin(s.phase + love.timer.getTime() * 1.5)
        drawRealSnowflake(s.x, s.y, s.size, s.alpha, s.rotation, twinkle)
    end

    local w = love.graphics.getWidth()
    local scale = getScale()

    drawSpacedText("Cubic Battle", 0, love.graphics.getHeight()/2 - 180*scale, w, "center", fontTitle)
    drawSpacedText("Touch & Dodge", 0, love.graphics.getHeight()/2 - 80*scale, w, "center", fontSub)

    local function drawButton(btn, label, isHover)
        local r, g, b = 0.25, 0.72, 0.68
        if isHover then
            r, g, b = 0.30, 0.78, 0.74
        end
        
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(math.max(3, 4 * scale))
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        
        drawSpacedText(label, btn.x, btn.y + 22*scale, btn.w, "center", fontBtn)
    end

    drawButton(btns.play, "PLAY", hoverBtn == "play")
    drawButton(btns.shop, "SHOP", hoverBtn == "shop")
    drawButton(btns.settings, "SETTINGS", hoverBtn == "settings")
    drawButton(btns.credits, "CREDITS", hoverBtn == "credits")
end

function lobby.mousemoved(x, y)
    if isMobile then return end
    
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    for name, btn in pairs(btns) do
        if isInside(btn) then
            hoverBtn = name
            return
        end
    end
    hoverBtn = nil
end

function lobby.touchpressed(id, x, y)
    local function isInside(btn)
        return x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h
    end
    
    if isInside(btns.play) then
        playButtonSound()
        GameState.current = "mode_select"
    elseif isInside(btns.shop) then
        playButtonSound()
        GameState.current = "shop"
    elseif isInside(btns.settings) then
        playButtonSound()
        GameState.current = "settings"
    elseif isInside(btns.credits) then
        playButtonSound()
        GameState.current = "credits"
    end
end

function lobby.touchmoved(id, x, y)
    if isMobile then
        local function isInside(btn)
            return x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h
        end
        
        for name, btn in pairs(btns) do
            if isInside(btn) then
                hoverBtn = name
                return
            end
        end
        hoverBtn = nil
    end
end

function lobby.touchreleased(id, x, y)
    if isMobile then
        hoverBtn = nil
    end
end

return lobby

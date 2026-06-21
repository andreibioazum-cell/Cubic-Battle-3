local lobby = {}

local btn = { w=220, h=75, x=0, y=0 }
local fontTitle, fontSub, fontBtn
local spaceCanvas -- Канвас для космоса (отрисовывается 1 раз)
local stars = {} -- Таблица для анимации звезд

local function mkGrad(w, h)
    -- Глубокие космические синие оттенки
    return love.graphics.newMesh({
        {0,0, 0,0, 0.02,0.00,0.10,1},
        {w,0, 1,0, 0.00,0.05,0.25,1},
        {w,h, 1,1, 0.10,0.15,0.45,1},
        {0,h, 0,1, 0.05,0.10,0.35,1},
    }, "fan", "static")
end

local function generateStars(w, h)
    stars = {}
    for i=1, 150 do
        table.insert(stars, {
            x = math.random(w),
            y = math.random(h),
            size = math.random(1, 3),
            alpha = math.random(50, 100) / 100,
            speed = 40 + math.random(80) -- Скорость полета звезды
        })
    end
end

local function generateSpace(w, h)
    spaceCanvas = love.graphics.newCanvas(w, h)
    love.graphics.setCanvas(spaceCanvas)
    
    -- Рисуем статичный градиент на канвас
    love.graphics.draw(mkGrad(w, h), 0, 0)
    
    love.graphics.setCanvas()
end

local function place()
    local w, h = love.graphics.getDimensions()
    btn.x = w/2 - btn.w/2
    btn.y = h/2 + 50
end

local function drawSpacedText(text, x, y, w, align, font, spacing)
    spacing = spacing or 0
    love.graphics.setFont(font)

    local totalW = 0
    local widths = {}
    for i=1, #text do
        local ch = text:sub(i,i)
        local cw = font:getWidth(ch)
        widths[i] = cw
        totalW = totalW + cw
    end
    totalW = totalW + spacing * (#text - 1)

    local startX = x
    if align == "center" then
        startX = x + (w - totalW)/2
    elseif align == "right" then
        startX = x + (w - totalW)
    end

    local outline = math.floor(2 * 0.85 + 0.5)

    love.graphics.setColor(0,0,0,1)
    local cx = startX
    for i=1, #text do
        local ch = text:sub(i,i)
        for dx=-outline, outline, outline do
            for dy=-outline, outline, outline do
                if dx ~= 0 or dy ~= 0 then
                    love.graphics.print(ch, cx+dx, y+dy)
                end
            end
        end
        cx = cx + widths[i] + spacing
    end

    love.graphics.setColor(1,1,1,1)
    cx = startX
    for i=1, #text do
        local ch = text:sub(i,i)
        love.graphics.print(ch, cx, y)
        cx = cx + widths[i] + spacing
    end
end

function lobby.load()
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", 64)
    fontSub   = love.graphics.newFont("Fredoka-Bold.ttf", 22)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", 30)
    
    local w, h = love.graphics.getDimensions()
    generateSpace(w, h)
    generateStars(w, h)
    
    place()
end

function lobby.resize(w, h)
    generateSpace(w, h)
    generateStars(w, h)
    place()
end

function lobby.update(dt)
    local w, h = love.graphics.getDimensions()
    -- Двигаем звезды из левого верхнего угла в правый нижний
    for _, s in ipairs(stars) do
        s.x = s.x + s.speed * dt
        s.y = s.y + s.speed * dt
        
        -- Если звезда улетела за экран, респавним её сверху или слева
        if s.x > w or s.y > h then
            if math.random() > 0.5 then
                s.x = math.random(-50, 0)
                s.y = math.random(0, h)
            else
                s.x = math.random(0, w)
                s.y = math.random(-50, 0)
            end
        end
    end
end

function lobby.draw()
    -- Отрисовываем готовый космос (градиент)
    love.graphics.setColor(1,1,1,1)
    if spaceCanvas then
        love.graphics.draw(spaceCanvas, 0, 0)
    end

    -- Отрисовываем анимированные звезды
    for _, s in ipairs(stars) do
        love.graphics.setColor(1, 1, 1, s.alpha)
        love.graphics.rectangle("fill", s.x, s.y, s.size, s.size)
    end

    drawSpacedText("Cubic Battle", 0, love.graphics.getHeight()/2 - 150, love.graphics.getWidth(), "center", fontTitle, fontTitle:getWidth("A")*0.05)
    drawSpacedText("Touch & Dodge", 0, love.graphics.getHeight()/2 - 60, love.graphics.getWidth(), "center", fontSub, fontSub:getWidth("A")*0.05)

    -- ИСПРАВЛЕНО: Темнее и фиолетовее
    love.graphics.setColor(0.1, 0.0, 0.2, 0.5)
    love.graphics.rectangle("fill", btn.x+5, btn.y+6, btn.w, btn.h, 16, 16)

    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 16, 16)

    love.graphics.setColor(0,0,0,1)
    love.graphics.setLineWidth(3.4)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 16, 16)

    drawSpacedText("Play", btn.x, btn.y + 20, btn.w, "center", fontBtn, fontBtn:getWidth("A")*0.05)
end

function lobby.touchpressed(id, x, y)
    if x>=btn.x and x<=btn.x+btn.w and
       y>=btn.y and y<=btn.y+btn.h then
        GameState.current = "game"
    end
end

function lobby.touchmoved() end
function lobby.touchreleased() end

return lobby

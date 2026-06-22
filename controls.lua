local controls = {}

local joy  = { id = nil, cx = 0, cy = 0, sx = 0, sy = 0, r = 45, sr = 18 }
local atk  = { id = nil, x = 0, y = 0, r = 52, hold = false, press = 0 }
local back = { x = 20, y = 20, w = 140, h = 55 }
local ability = { id = nil, x = 0, y = 0, r = 40, press = 0, triggered = false }

local keys = { w = false, a = false, s = false, d = false, space = false, e = false }
local font
local aimDx, aimDy = 0, -1
local isMobile = (love.system.getOS() == "Android" or love.system.getOS() == "iOS")
local spaceJustPressed = false
local abilityJustPressed = false

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

local function place()
    local w, h = love.graphics.getDimensions()
    joy.cx, joy.cy = 80, h - 80
    if not joy.id then joy.sx, joy.sy = joy.cx, joy.cy end
    atk.x, atk.y = w - 80, h - 80
    ability.x, ability.y = atk.x - 70, atk.y
    back.x, back.y = (w - back.w) / 2, 30
end

function controls.load()
    font = love.graphics.newFont("Fredoka-Bold.ttf", 24)
    place()
end

function controls.resize() place() end

function controls.update(dt)
    local target = atk.hold and 1 or 0
    atk.press = atk.press + (target - atk.press) * math.min(dt * 12, 1)
    ability.press = ability.press * 0.9
end

function controls.getMove()
    local dx, dy = 0, 0
    if keys.w then dy = dy - 1 end
    if keys.s then dy = dy + 1 end
    if keys.a then dx = dx - 1 end
    if keys.d then dx = dx + 1 end

    if joy.id then
        local jdx, jdy = joy.sx - joy.cx, joy.sy - joy.cy
        local len = math.sqrt(jdx * jdx + jdy * jdy)
        if len > 0 then
            if dx == 0 and dy == 0 then
                dx, dy = jdx / len, jdy / len
                aimDx, aimDy = dx, dy
            end
        end
    end

    if dx ~= 0 or dy ~= 0 then
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0 then
            dx, dy = dx / len, dy / len
            aimDx, aimDy = dx, dy
        end
    end
    return dx, dy
end

function controls.isAiming() return atk.hold or keys.space end
function controls.getAim() return aimDx, aimDy end

function controls.touchpressed(id, x, y)
    if x >= back.x and x <= back.x + back.w and y >= back.y and y <= back.y + back.h then
        GameState.current = "lobby"
        return
    end

    local dx, dy = x - joy.cx, y - joy.cy
    if dx * dx + dy * dy <= joy.r * joy.r then
        joy.id, joy.sx, joy.sy = id, x, y
        return
    end

    local ax, ay = x - atk.x, y - atk.y
    if ax * ax + ay * ay <= atk.r * atk.r then
        atk.id, atk.hold = id, true
        return
    end

    local abx, aby = x - ability.x, y - ability.y
    if abx * abx + aby * aby <= ability.r * ability.r then
        ability.id, ability.press, ability.triggered = id, 1, true
    end
end

function controls.touchmoved(id, x, y)
    if joy.id == id then
        local dx, dy = x - joy.cx, y - joy.cy
        local len = math.sqrt(dx * dx + dy * dy)
        if len > joy.r then
            dx, dy = dx / len * joy.r, dy / len * joy.r
        end
        joy.sx, joy.sy = joy.cx + dx, joy.cy + dy
    end
end

function controls.touchreleased(id)
    if joy.id == id then
        joy.id = nil
        joy.sx, joy.sy = joy.cx, joy.cy
    end
    if atk.id == id then
        atk.id, atk.hold = nil, false
        return true, aimDx, aimDy
    end
    if ability.id == id then
        ability.id = nil
    end
    return false, aimDx, aimDy
end

function controls.keypressed(key)
    if key == "w" then keys.w = true end
    if key == "a" then keys.a = true end
    if key == "s" then keys.s = true end
    if key == "d" then keys.d = true end
    if key == "space" then keys.space = true; spaceJustPressed = true end
    if key == "e" then keys.e = true; abilityJustPressed = true end
end

function controls.keyreleased(key)
    if key == "w" then keys.w = false end
    if key == "a" then keys.a = false end
    if key == "s" then keys.s = false end
    if key == "d" then keys.d = false end
    if key == "space" then keys.space = false end
    if key == "e" then keys.e = false end
end

function controls.getShot()
    if spaceJustPressed then
        spaceJustPressed = false
        return true, aimDx, aimDy
    end
    return false, aimDx, aimDy
end

function controls.getAbilityTrigger()
    if abilityJustPressed then
        abilityJustPressed = false
        return true
    end
    if ability.triggered then
        ability.triggered = false
        return true
    end
    return false
end

function controls.draw()
    if isMobile then
        love.graphics.setLineWidth(2.55)

        love.graphics.setColor(0, 0, 0, 0.20)
        love.graphics.circle("fill", joy.cx, joy.cy, joy.r)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("line", joy.cx, joy.cy, joy.r)
        love.graphics.circle("fill", joy.sx, joy.sy, joy.sr)

        local scale = 1 - atk.press * 0.12
        local r = atk.r * scale
        local textScale = 1 - atk.press * 0.18
        local textAlpha = 1 - atk.press * 0.45

        love.graphics.setColor(0.55 - atk.press * 0.2, 0.20, 0.85 - atk.press * 0.3, 1)
        love.graphics.circle("fill", atk.x, atk.y, r)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4)
        love.graphics.circle("line", atk.x, atk.y, r)

        love.graphics.push()
        love.graphics.translate(atk.x, atk.y)
        love.graphics.scale(textScale, textScale)
        drawSpacedText("Shot", -atk.r, -14, atk.r * 2, "center", font, nil, textAlpha)
        love.graphics.pop()

        local abScale = 1 - ability.press * 0.12
        local abR = ability.r * abScale
        love.graphics.setColor(0.8, 0.2, 0.9, 1)
        love.graphics.circle("fill", ability.x, ability.y, abR)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.setLineWidth(3.4)
        love.graphics.circle("line", ability.x, ability.y, abR)

        love.graphics.setFont(font)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf("R", ability.x - abR / 2, ability.y - 14, abR * 2, "center")
    end

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", back.x + 4, back.y + 5, back.w, back.h, 14, 14)
    love.graphics.setColor(0.35, 0.15, 0.75, 1)
    love.graphics.rectangle("fill", back.x, back.y, back.w, back.h, 14, 14)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4)
    love.graphics.rectangle("line", back.x, back.y, back.w, back.h, 14, 14)
    drawSpacedText("Back", back.x, back.y + 14, back.w, "center", font, nil, 1)

    love.graphics.setColor(1, 1, 1, 1)
end

return controls

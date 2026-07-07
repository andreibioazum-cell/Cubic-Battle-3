-- room.lua – room creation/joining UI
local room = {}

local online = require("online")
local fontTitle, fontBtn, fontInput
local inputText = ""
local inputActive = false
local inputField = { x = 0, y = 0, w = 300, h = 50 }
local btnCreate = { w = 220, h = 60, x = 0, y = 0 }
local btnJoin = { w = 220, h = 60, x = 0, y = 0 }
local btnBack = { w = 140, h = 55, x = 0, y = 0 }

local mode = "create"
local statusMessage = ""
local statusType = "idle"

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

function room.load()
    local w, h = love.graphics.getDimensions()
    local scale = getScale()

    inputField.w = 300 * scale
    inputField.h = 50 * scale
    inputField.x = (w - inputField.w) / 2
    inputField.y = h/2 - 20 * scale

    btnCreate.w = 220 * scale
    btnCreate.h = 60 * scale
    btnCreate.x = (w - btnCreate.w) / 2 - 120 * scale
    btnCreate.y = h/2 + 80 * scale

    btnJoin.w = 220 * scale
    btnJoin.h = 60 * scale
    btnJoin.x = (w - btnJoin.w) / 2 + 120 * scale
    btnJoin.y = h/2 + 80 * scale

    btnBack.w = 140 * scale
    btnBack.h = 55 * scale
    btnBack.x = (w - btnBack.w) / 2
    btnBack.y = h - 100 * scale

    inputText = ""
    inputActive = false
    statusMessage = ""
    statusType = "idle"

    local titleSize = math.max(32, 48 * scale)
    local btnSize   = math.max(20, 28 * scale)
    local inputSize = math.max(22, 30 * scale)
    fontTitle = love.graphics.newFont("Fredoka-Bold.ttf", titleSize)
    fontBtn   = love.graphics.newFont("Fredoka-Bold.ttf", btnSize)
    fontInput = love.graphics.newFont("Fredoka-Bold.ttf", inputSize)
end

function room.draw()
    love.graphics.setColor(0.02, 0.05, 0.2, 1)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    local w = love.graphics.getWidth()
    local h = love.graphics.getHeight()
    local scale = getScale()

    drawSpacedText("MULTIPLAYER ROOM", 0, 80*scale, w, "center", fontTitle)

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

    local displayText = inputText
    if inputActive and love.timer.getTime() % 1 < 0.5 then
        displayText = displayText .. "_"
    end
    love.graphics.setFont(fontInput)
    love.graphics.setColor(1, 1, 1, 1)
    local th = fontInput:getHeight()
    love.graphics.print(displayText, inputField.x + 15*scale, inputField.y + (inputField.h - th)/2)

    local label = (mode == "create") and "Enter room code (or leave empty for auto)" or "Enter room code"
    love.graphics.setFont(fontBtn)
    love.graphics.setColor(0.8, 0.8, 0.8, 1)
    love.graphics.printf(label, inputField.x, inputField.y - 35*scale, inputField.w, "center")

    local colorCreate = (mode == "create") and {0.2, 0.7, 0.2} or {0.3, 0.3, 0.3}
    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnCreate.x + 5*scale, btnCreate.y + 6*scale, btnCreate.w, btnCreate.h, 16*scale, 16*scale)
    love.graphics.setColor(colorCreate[1], colorCreate[2], colorCreate[3], 1)
    love.graphics.rectangle("fill", btnCreate.x, btnCreate.y, btnCreate.w, btnCreate.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnCreate.x, btnCreate.y, btnCreate.w, btnCreate.h, 16*scale, 16*scale)
    drawSpacedText("CREATE", btnCreate.x, btnCreate.y + 18*scale, btnCreate.w, "center", fontBtn, nil, 1)

    local colorJoin = (mode == "join") and {0.2, 0.5, 0.9} or {0.3, 0.3, 0.3}
    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnJoin.x + 5*scale, btnJoin.y + 6*scale, btnJoin.w, btnJoin.h, 16*scale, 16*scale)
    love.graphics.setColor(colorJoin[1], colorJoin[2], colorJoin[3], 1)
    love.graphics.rectangle("fill", btnJoin.x, btnJoin.y, btnJoin.w, btnJoin.h, 16*scale, 16*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnJoin.x, btnJoin.y, btnJoin.w, btnJoin.h, 16*scale, 16*scale)
    drawSpacedText("JOIN", btnJoin.x, btnJoin.y + 18*scale, btnJoin.w, "center", fontBtn, nil, 1)

    if statusMessage ~= "" then
        local color = (statusType == "success") and {0.2, 0.8, 0.2} or {0.9, 0.2, 0.2}
        love.graphics.setColor(color[1], color[2], color[3], 1)
        love.graphics.setFont(fontBtn)
        love.graphics.printf(statusMessage, 0, h/2 + 150*scale, w, "center")
    end

    love.graphics.setColor(0.0, 0.1, 0.3, 0.5)
    love.graphics.rectangle("fill", btnBack.x + 4*scale, btnBack.y + 5*scale, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0.2, 0.5, 0.9, 1)
    love.graphics.rectangle("fill", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.setLineWidth(3.4 * scale)
    love.graphics.rectangle("line", btnBack.x, btnBack.y, btnBack.w, btnBack.h, 14*scale, 14*scale)
    drawSpacedText("BACK", btnBack.x, btnBack.y + 14*scale, btnBack.w, "center", fontBtn, nil, 1)
end

function room.touchpressed(id, x, y)
    if x >= btnBack.x and x <= btnBack.x + btnBack.w and y >= btnBack.y and y <= btnBack.y + btnBack.h then
        playButtonSound()
        GameState.current = "lobby"
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
        end
        return
    end

    if x >= btnCreate.x and x <= btnCreate.x + btnCreate.w and y >= btnCreate.y and y <= btnCreate.y + btnCreate.h then
        playButtonSound()
        mode = "create"
        local code = inputText
        if code == "" then
            code = online.generateRoomCode()
        end
        local nickname = SAVE_DATA.nickname or "Player"
        online.createRoom(code, nickname, function(success, msg)
            if success then
                statusMessage = "Room created! Code: " .. code
                statusType = "success"
                _G.roomCode = code
                GameState.current = "game"
            else
                statusMessage = "Failed: " .. (msg or "unknown error")
                statusType = "error"
            end
        end)
        return
    end

    if x >= btnJoin.x and x <= btnJoin.x + btnJoin.w and y >= btnJoin.y and y <= btnJoin.y + btnJoin.h then
        playButtonSound()
        mode = "join"
        local code = inputText
        if code == "" then
            statusMessage = "Enter room code first"
            statusType = "error"
            return
        end
        local nickname = SAVE_DATA.nickname or "Player"
        online.joinRoom(code, nickname, function(success, msg)
            if success then
                statusMessage = "Joined room " .. code
                statusType = "success"
                _G.roomCode = code
                GameState.current = "game"
            else
                statusMessage = "Failed: " .. (msg or "unknown error")
                statusType = "error"
            end
        end)
        return
    end
end

function room.touchmoved() end
function room.touchreleased() end

function room.keypressed(key)
    if not inputActive then return end
    if key == "return" or key == "kpenter" then
        inputActive = false
        love.keyboard.setTextInput(false)
        love.keyboard.setKeyRepeat(false)
        return
    end
    if key == "backspace" then
        inputText = inputText:sub(1, -2)
        return
    end
    if #inputText < 10 then
        inputText = inputText .. key
    end
end

function room.textinput(t)
    if inputActive and #inputText < 10 then
        inputText = inputText .. t
    end
end

return room

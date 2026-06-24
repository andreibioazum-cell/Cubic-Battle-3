local multiplayer = {}

local json = require("json")
local controls = require("controls")

local socket_ok, socket = pcall(require, "socket")

local SERVER_HOST = "127.0.0.1"
local SERVER_PORT = 12345

local tcp = nil
local connected = false
local playerId = nil
local players = {}
local localPlayer = { x = 400, y = 300, dx = 0, dy = 0, hp = 5, skin = "NONE", nick = "Player" }
local sendTimer = 0
local SEND_INTERVAL = 0.05
local errorMessage = nil

function multiplayer.startServer()
    local os = love.system.getOS()
    if os == "Windows" then
        -- Если есть server.exe (скомпилированный) – используем его
        local exe = love.filesystem.getInfo("server.exe") and "server.exe" or "python server.py"
        os.execute("start /B " .. exe)
    elseif os == "Linux" or os == "macOS" then
        os.execute("python server.py &")
    else
        errorMessage = "Cannot start server on this OS"
        return false
    end
    return true
end

function multiplayer.connect(host, port)
    if connected then return true end
    if not socket_ok then
        errorMessage = "LuaSocket not installed!\nPlease install luasocket for multiplayer."
        return false
    end
    host = host or SERVER_HOST
    port = port or SERVER_PORT
    tcp = socket.tcp()
    tcp:settimeout(0.1)
    local ok, err = tcp:connect(host, port)
    if not ok then
        errorMessage = "Cannot connect to server.\nMake sure server is running."
        return false
    end
    connected = true
    errorMessage = nil
    print("Connected to server")
    return true
end

function multiplayer.load(mode)
    -- mode: "host" или "client"
    local skin = SAVE_DATA and SAVE_DATA.equippedSkin or "NONE"
    local nick = SAVE_DATA and SAVE_DATA.nickname or "Player"
    localPlayer.skin = skin
    localPlayer.nick = nick

    if mode == "host" then
        if not multiplayer.startServer() then
            GameState.current = "lobby"
            return
        end
        love.timer.sleep(0.5) -- даём серверу время запуститься
    end

    if not multiplayer.connect() then
        love.timer.sleep(0.5)
        GameState.current = "lobby"
    end
end

-- ... остальной код (update, draw, keypressed и т.д.) такой же, как в предыдущем ответе

local installer = {}

function installer.checkLuasocket()
    local ok, _ = pcall(require, "socket")
    return ok
end

function installer.isMobile()
    local os = love.system.getOS()
    return (os == "Android" or os == "iOS")
end

function installer.getInstructions()
    local os = love.system.getOS()
    if installer.isMobile() then
        return "Multiplayer is not supported on mobile devices.\nPlease play Singleplayer."
    end
    local msg = "MULTIPLAYER REQUIRES LUASOCKET\n\n"
    if os == "Windows" then
        msg = msg .. "1. Download luasocket from:\nhttps://github.com/lunarmodules/luasocket/releases\n"
        msg = msg .. "2. Extract and copy folders 'socket' and 'mime' into the game folder.\n"
        msg = msg .. "3. Also copy .dll files (socket.dll, mime.dll, core.dll) next to love.exe\n"
        msg = msg .. "4. Restart the game."
    elseif os == "Linux" then
        msg = msg .. "Install luarocks and run:\nluarocks install luasocket\n"
        msg = msg .. "Or copy 'socket' and 'mime' folders into the game directory."
    else -- macOS
        msg = msg .. "Luasocket is not available on this platform.\n"
        msg = msg .. "Multiplayer is only supported on Windows/Linux."
    end
    return msg
end

return installer

-- ============================================================
-- MODULE: mod_system.lua
-- Full mod management system for Cubic Battle 3
-- ============================================================

local modSystem = {}

-- ========== CONFIGURATION ==========
local CONFIG = {
    modsFolder = "mods/",
    tempFolder = "temp/",
    maxMods = 50,
    allowedExtensions = {".lua", ".zip"}
}

-- ========== VARIABLES ==========
local loadedMods = {}
local modCallbacks = {
    onLoad = {},
    onUpdate = {},
    onDraw = {},
    onShoot = {},
    onHit = {},
    onDeath = {},
    onEnemySpawn = {},
    onEnemyDeath = {}
}
local modData = {}
local isInitialized = false

function modSystem.init()
    if isInitialized then return true end
    
    local folders = {CONFIG.modsFolder, CONFIG.tempFolder}
    for _, folder in ipairs(folders) do
        if not love.filesystem.getInfo(folder) then
            love.filesystem.createDirectory(folder)
        end
    end
    
    modSystem.loadAllMods()
    
    isInitialized = true
    return true
end

function modSystem.loadAllMods()
    local files = love.filesystem.getDirectoryItems(CONFIG.modsFolder)
    local loaded = 0
    
    for _, file in ipairs(files) do
        if file:match("%.lua$") then
            local success = modSystem.loadMod(file)
            if success then loaded = loaded + 1 end
        end
    end
    
    return loaded
end

function modSystem.loadMod(filename)
    local path = CONFIG.modsFolder .. filename
    
    if not love.filesystem.getInfo(path) then
        return false
    end
    
    local chunk, err = love.filesystem.load(path)
    if not chunk then
        return false
    end
    
    local success, mod = pcall(chunk)
    if not success then
        return false
    end
    
    if type(mod) ~= "table" then
        return false
    end
    
    loadedMods[filename] = mod
    modSystem.registerCallbacks(filename, mod)
    
    if mod.onLoad then
        pcall(mod.onLoad, modSystem)
    end
    
    return true
end

function modSystem.registerCallbacks(filename, mod)
    local callbacks = {
        onLoad = "onLoad",
        onUpdate = "onUpdate", 
        onDraw = "onDraw",
        onShoot = "onShoot",
        onHit = "onHit",
        onDeath = "onDeath",
        onEnemySpawn = "onEnemySpawn",
        onEnemyDeath = "onEnemyDeath"
    }
    
    for key, cbName in pairs(callbacks) do
        if mod[cbName] and type(mod[cbName]) == "function" then
            table.insert(modCallbacks[key], {
                mod = mod,
                func = mod[cbName],
                name = filename
            })
        end
    end
end

function modSystem.installFromZIP(zipData, zipName)
    local count = 0
    for _ in pairs(loadedMods) do count = count + 1 end
    if count >= CONFIG.maxMods then
        return false, "Max mods reached"
    end
    
    local tempPath = CONFIG.tempFolder .. zipName
    love.filesystem.write(tempPath, zipData)
    
    local luaName = zipName:gsub("%.zip$", ".lua")
    local luaPath = CONFIG.modsFolder .. luaName
    
    local success, content = pcall(function()
        return love.filesystem.read(tempPath)
    end)
    
    if not success or not content then
        return false, "Failed to read file"
    end
    
    love.filesystem.write(luaPath, content)
    love.filesystem.remove(tempPath)
    
    local loaded = modSystem.loadMod(luaName)
    if loaded then
        return true, "Mod installed successfully!"
    else
        love.filesystem.remove(luaPath)
        return false, "Failed to load mod"
    end
end

function modSystem.uninstallMod(filename)
    local path = CONFIG.modsFolder .. filename
    
    loadedMods[filename] = nil
    
    for key, list in pairs(modCallbacks) do
        for i = #list, 1, -1 do
            if list[i].name == filename then
                table.remove(list, i)
            end
        end
    end
    
    if love.filesystem.getInfo(path) then
        love.filesystem.remove(path)
        return true
    end
    
    return false
end

function modSystem.trigger(callbackName, ...)
    local list = modCallbacks[callbackName] or {}
    local results = {}
    
    for _, cb in ipairs(list) do
        local success, result = pcall(cb.func, cb.mod, ...)
        if success then
            table.insert(results, result)
        end
    end
    
    return results
end

function modSystem.getModData(modName)
    if not modData[modName] then
        modData[modName] = {}
    end
    return modData[modName]
end

function modSystem.getLoadedMods()
    local list = {}
    for name, mod in pairs(loadedMods) do
        table.insert(list, {
            name = name,
            title = mod.title or name,
            author = mod.author or "Unknown",
            version = mod.version or "1.0",
            description = mod.description or "No description"
        })
    end
    return list
end

function modSystem.isModLoaded(name)
    return loadedMods[name] ~= nil
end

function modSystem.reloadMod(filename)
    modSystem.uninstallMod(filename)
    return modSystem.loadMod(filename)
end

function modSystem.getModInfo(filename)
    local mod = loadedMods[filename]
    if not mod then return nil end
    
    return {
        name = filename,
        title = mod.title or filename,
        author = mod.author or "Unknown",
        version = mod.version or "1.0",
        description = mod.description or "No description",
        requires = mod.requires or {},
        dependencies = mod.dependencies or {}
    }
end

function modSystem.saveModState()
    local state = {
        mods = {},
        data = modData
    }
    
    for name in pairs(loadedMods) do
        table.insert(state.mods, name)
    end
    
    love.filesystem.write("mod_state.json", love.data.encode("json", state))
end

function modSystem.loadModState()
    local content = love.filesystem.read("mod_state.json")
    if content then
        local state = love.data.decode("json", content)
        if state and state.mods then
            for _, name in ipairs(state.mods) do
                modSystem.loadMod(name)
            end
        end
        if state and state.data then
            modData = state.data
        end
    end
end

function modSystem.createExampleMod()
    local example = [[
-- ============================================================
-- EXAMPLE MOD
-- Copy this code to example.lua and put in mods folder
-- ============================================================

local mod = {}

mod.title = "Example Mod"
mod.author = "CubicBattle3"
mod.version = "1.0"
mod.description = "Shows how to create mods"

function mod.onLoad()
end

function mod.onUpdate(dt)
end

function mod.onDraw()
    local w, h = love.graphics.getDimensions()
    love.graphics.setColor(1, 1, 0, 0.5)
    love.graphics.print("Mod active!", 10, 30)
end

function mod.onShoot(x, y, dx, dy)
    return { x = x, y = y, dx = dx * 2, dy = dy * 2 }
end

function mod.onHit(target, damage)
end

function mod.onDeath()
end

return mod
]]
    
    love.filesystem.write(CONFIG.modsFolder .. "example_mod.lua", example)
end

function modSystem.gameLoad()
    modSystem.trigger("onLoad")
end

function modSystem.gameUpdate(dt)
    modSystem.trigger("onUpdate", dt)
end

function modSystem.gameDraw()
    modSystem.trigger("onDraw")
end

function modSystem.gameShoot(x, y, dx, dy)
    local results = modSystem.trigger("onShoot", x, y, dx, dy)
    for _, result in ipairs(results) do
        if result and type(result) == "table" then
            return result
        end
    end
    return { x = x, y = y, dx = dx, dy = dy }
end

function modSystem.gameHit(target, damage)
    modSystem.trigger("onHit", target, damage)
end

function modSystem.gameDeath()
    modSystem.trigger("onDeath")
end

function modSystem.fixPlaySound()
    _G.playSound = function(name)
        if _G.sounds and _G.sounds[name] then
            local source = _G.sounds[name]
            if source and source.clone then
                local clone = source:clone()
                if clone then
                    clone:setVolume(source:getVolume() or 0.5)
                    clone:setLooping(false)
                    clone:play()
                    love.timer.after(0.5, function()
                        if clone then clone:stop() end
                    end)
                end
            end
        end
    end
end

function modSystem.autoInit()
    modSystem.init()
    modSystem.fixPlaySound()
    
    local files = love.filesystem.getDirectoryItems(CONFIG.modsFolder)
    if #files == 0 then
        modSystem.createExampleMod()
        modSystem.loadMod("example_mod.lua")
    end
end

return modSystem

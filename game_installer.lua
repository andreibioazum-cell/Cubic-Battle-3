-- ============================================================
-- MODULE: game_installer.lua
-- Full game replacement system through mods
-- ============================================================

local gameInstaller = {}

-- ========== CONFIGURATION ==========
local CONFIG = {
    gameFolder = "game/",
    backupFolder = "backup/",
    modsFolder = "mods/",
    tempFolder = "temp_install/",
    protectedFiles = {
        "conf.lua",
        "save.txt",
        "mods/",
        "backup/",
        "temp_install/",
        "installed_mod.json",
        "pending_install.json",
        "restart.flag",
        "safe_mode.flag",
        "install_log.txt"
    }
}

-- ========== VARIABLES ==========
local installQueue = {}
local isInstalling = false
local backupFiles = {}
local installLog = {}
local isInitialized = false

function gameInstaller.init()
    if isInitialized then return true end
    
    local folders = {
        CONFIG.backupFolder,
        CONFIG.tempFolder,
        CONFIG.modsFolder
    }
    
    for _, folder in ipairs(folders) do
        if not love.filesystem.getInfo(folder) then
            love.filesystem.createDirectory(folder)
        end
    end
    
    gameInstaller.checkInstallQueue()
    
    if gameInstaller.checkForRestart() then
        gameInstaller.log("Game restarted", "INFO")
    end
    
    if gameInstaller.checkSafeMode() then
        gameInstaller.log("Safe mode activated", "WARNING")
    end
    
    isInitialized = true
    return true
end

function gameInstaller.installModFromZIP(zipData, zipName, modInfo)
    if isInstalling then
        gameInstaller.log("Attempted install during another install", "WARNING")
        return false
    end
    
    isInstalling = true
    gameInstaller.log("Starting install: " .. zipName, "INFO")
    
    local tempPath = CONFIG.tempFolder .. zipName
    love.filesystem.write(tempPath, zipData)
    
    local success, files = pcall(function()
        return gameInstaller.unzip(tempPath)
    end)
    
    if not success or not files then
        gameInstaller.log("Failed to unzip", "ERROR")
        isInstalling = false
        return false
    end
    
    local hasGame = false
    for filename, _ in pairs(files) do
        if filename:match("main%.lua$") or 
           filename:match("game%.lua$") or
           filename:match("conf%.lua$") then
            hasGame = true
            break
        end
    end
    
    if not hasGame then
        gameInstaller.log("Mod missing main game files", "ERROR")
        isInstalling = false
        return false
    end
    
    gameInstaller.createBackup()
    
    success = gameInstaller.installFiles(files, modInfo)
    
    if success then
        gameInstaller.log("Mod installed: " .. zipName, "SUCCESS")
        isInstalling = false
        gameInstaller.saveInstallInfo(zipName, modInfo)
        gameInstaller.restartGame()
        return true
    else
        gameInstaller.log("Install failed, restoring", "ERROR")
        gameInstaller.restoreBackup()
        isInstalling = false
        return false
    end
end

function gameInstaller.createBackup()
    backupFiles = {}
    
    local files = love.filesystem.getDirectoryItems(".")
    
    for _, file in ipairs(files) do
        local info = love.filesystem.getInfo(file)
        if info and info.type == "file" then
            local content = love.filesystem.read(file)
            if content then
                backupFiles[file] = content
            end
        end
    end
    
    local backupData = love.data.encode("json", backupFiles)
    local backupName = "backup_" .. os.time() .. ".json"
    love.filesystem.write(CONFIG.backupFolder .. backupName, backupData)
    
    gameInstaller.log("Backup created: " .. gameInstaller.tableLength(backupFiles) .. " files", "INFO")
    return backupName
end

function gameInstaller.restoreBackup()
    gameInstaller.log("Starting restore from backup", "INFO")
    
    local backupFilesList = love.filesystem.getDirectoryItems(CONFIG.backupFolder)
    local latestBackup = nil
    local latestTime = 0
    
    for _, file in ipairs(backupFilesList) do
        if file:match("backup_%d+%.json") then
            local time = tonumber(file:match("backup_(%d+)%.json"))
            if time and time > latestTime then
                latestTime = time
                latestBackup = file
            end
        end
    end
    
    if latestBackup then
        local data = love.filesystem.read(CONFIG.backupFolder .. latestBackup)
        if data then
            backupFiles = love.data.decode("json", data)
        end
    end
    
    local files = love.filesystem.getDirectoryItems(".")
    local deleted = 0
    
    for _, file in ipairs(files) do
        local isProtected = false
        for _, p in ipairs(CONFIG.protectedFiles) do
            if file:match(p) or file:find(p) or file == p then
                isProtected = true
                break
            end
        end
        
        if not isProtected then
            local info = love.filesystem.getInfo(file)
            if info and info.type == "file" then
                love.filesystem.remove(file)
                deleted = deleted + 1
            elseif info and info.type == "directory" then
                gameInstaller.removeDirectory(file)
                deleted = deleted + 1
            end
        end
    end
    
    local restored = 0
    for filename, content in pairs(backupFiles) do
        love.filesystem.write(filename, content)
        restored = restored + 1
    end
    
    gameInstaller.log("Restored files: " .. restored, "INFO")
end

function gameInstaller.removeDirectory(dir)
    local files = love.filesystem.getDirectoryItems(dir)
    for _, file in ipairs(files) do
        local path = dir .. "/" .. file
        local info = love.filesystem.getInfo(path)
        if info and info.type == "directory" then
            gameInstaller.removeDirectory(path)
        else
            love.filesystem.remove(path)
        end
    end
    love.filesystem.remove(dir)
end

function gameInstaller.installFiles(files, modInfo)
    local installed = 0
    local skipped = 0
    
    for filename, content in pairs(files) do
        local isProtected = false
        for _, p in ipairs(CONFIG.protectedFiles) do
            if filename:match(p) or filename:find(p) or filename == p then
                isProtected = true
                break
            end
        end
        
        if not isProtected then
            local pathParts = {}
            for part in filename:gmatch("[^/]+") do
                table.insert(pathParts, part)
            end
            
            if #pathParts > 1 then
                local currentPath = ""
                for i = 1, #pathParts - 1 do
                    currentPath = currentPath .. pathParts[i] .. "/"
                    if not love.filesystem.getInfo(currentPath) then
                        love.filesystem.createDirectory(currentPath)
                    end
                end
            end
            
            love.filesystem.write(filename, content)
            installed = installed + 1
        else
            skipped = skipped + 1
        end
    end
    
    gameInstaller.log("Installed: " .. installed .. ", skipped: " .. skipped, "INFO")
    return true
end

function gameInstaller.unzip(zipPath)
    local files = {}
    local content = love.filesystem.read(zipPath)
    
    if not content then
        return false, nil
    end
    
    local pos = 1
    local fileCount = 0
    local maxPos = #content
    
    while pos < maxPos and pos > 0 do
        local sig = content:sub(pos, pos+3)
        
        if sig == "PK\3\4" then
            local nameLen = string.byte(content, pos+26) or 0
            local extraLen = string.byte(content, pos+28) or 0
            local fileName = content:sub(pos+30, pos+30+nameLen-1)
            
            local dataPos = pos + 30 + nameLen + extraLen
            local dataLen = string.byte(content, pos+18) or 0
            dataLen = dataLen + string.byte(content, pos+19) * 256
            
            if dataLen > 0 and fileName ~= "" and not fileName:match("/$") then
                local fileData = content:sub(dataPos, dataPos+dataLen-1)
                if fileData and #fileData > 0 then
                    files[fileName] = fileData
                    fileCount = fileCount + 1
                end
            end
            
            pos = dataPos + dataLen
        else
            pos = pos + 1
        end
        
        if pos > maxPos then break end
        if pos < 1 then break end
    end
    
    love.filesystem.remove(zipPath)
    
    return true, files
end

function gameInstaller.checkInstallQueue()
    local installFile = "pending_install.json"
    local data = love.filesystem.read(installFile)
    
    if data then
        local installData = love.data.decode("json", data)
        
        if installData and installData.modId then
            gameInstaller.log("Found mod in queue: " .. installData.title, "INFO")
            
            local success = gameInstaller.installModFromZIP(
                installData.zipData,
                installData.zipName or "mod.zip",
                installData
            )
            
            if success then
                love.filesystem.remove(installFile)
                gameInstaller.log("Mod installed from queue", "SUCCESS")
            else
                gameInstaller.log("Failed to install from queue", "ERROR")
            end
        else
            love.filesystem.remove(installFile)
        end
    end
end

function gameInstaller.restartGame()
    gameInstaller.log("Restarting game", "INFO")
    
    love.filesystem.write("restart.flag", "true")
    love.event.quit("restart")
end

function gameInstaller.checkForRestart()
    local flag = love.filesystem.read("restart.flag")
    if flag == "true" then
        love.filesystem.remove("restart.flag")
        return true
    end
    return false
end

function gameInstaller.saveInstallInfo(zipName, modInfo)
    local info = {
        modName = zipName,
        title = modInfo and modInfo.title or "Unknown mod",
        author = modInfo and modInfo.author or "Unknown",
        version = modInfo and modInfo.version or "1.0",
        installed = os.time(),
        date = os.date("%Y-%m-%d %H:%M:%S"),
        isGameReplacement = true
    }
    
    local json = love.data.encode("json", info)
    love.filesystem.write("installed_mod.json", json)
    
    gameInstaller.log("Saved mod info: " .. info.title, "INFO")
end

function gameInstaller.getInstalledMod()
    local data = love.filesystem.read("installed_mod.json")
    if data then
        return love.data.decode("json", data)
    end
    return nil
end

function gameInstaller.uninstallMod()
    local modInfo = gameInstaller.getInstalledMod()
    if not modInfo then
        gameInstaller.log("Attempted uninstall but no mod", "WARNING")
        return false
    end
    
    gameInstaller.log("Uninstalling mod: " .. modInfo.title, "INFO")
    
    gameInstaller.restoreBackup()
    love.filesystem.remove("installed_mod.json")
    
    gameInstaller.log("Mod uninstalled", "INFO")
    return true
end

function gameInstaller.getInstalledMods()
    local mods = {}
    
    local current = gameInstaller.getInstalledMod()
    if current then
        table.insert(mods, current)
    end
    
    local files = love.filesystem.getDirectoryItems(CONFIG.backupFolder)
    for _, file in ipairs(files) do
        if file:match("backup_.*%.json") then
            local data = love.filesystem.read(CONFIG.backupFolder .. file)
            if data then
                local backupInfo = {
                    file = file,
                    date = file:match("backup_(%d+)%.json")
                }
                table.insert(mods, backupInfo)
            end
        end
    end
    
    return mods
end

function gameInstaller.enterSafeMode()
    gameInstaller.log("Entering safe mode", "WARNING")
    
    gameInstaller.createBackup()
    
    local mods = love.filesystem.getDirectoryItems(CONFIG.modsFolder)
    for _, mod in ipairs(mods) do
        love.filesystem.remove(CONFIG.modsFolder .. mod)
    end
    
    love.filesystem.write("safe_mode.flag", "true")
    
    gameInstaller.log("Safe mode activated", "INFO")
    gameInstaller.restartGame()
end

function gameInstaller.checkSafeMode()
    local flag = love.filesystem.read("safe_mode.flag")
    if flag == "true" then
        love.filesystem.remove("safe_mode.flag")
        return true
    end
    return false
end

function gameInstaller.log(message, level)
    level = level or "INFO"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = string.format("[%s] [%s] %s\n", timestamp, level, message)
    
    table.insert(installLog, logEntry)
    love.filesystem.append("install_log.txt", logEntry)
end

function gameInstaller.getLog()
    return installLog
end

function gameInstaller.clearLog()
    installLog = {}
    love.filesystem.remove("install_log.txt")
end

function gameInstaller.tableLength(t)
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

function gameInstaller.fileExists(filename)
    local info = love.filesystem.getInfo(filename)
    return info and info.type == "file"
end

function gameInstaller.directoryExists(dirname)
    local info = love.filesystem.getInfo(dirname)
    return info and info.type == "directory"
end

function gameInstaller.getFileSize(filename)
    local info = love.filesystem.getInfo(filename)
    if info then
        return info.size
    end
    return 0
end

function gameInstaller.installFromURL(url)
    gameInstaller.log("Downloading mod: " .. url, "INFO")
    love.system.openURL(url)
end

function gameInstaller.getInstallStatus()
    return {
        isInstalling = isInstalling,
        hasBackup = gameInstaller.tableLength(backupFiles) > 0,
        installedMod = gameInstaller.getInstalledMod(),
        logSize = #installLog,
        isInitialized = isInitialized
    }
end

function gameInstaller.exportBackup()
    if gameInstaller.tableLength(backupFiles) == 0 then
        return nil
    end
    
    local backupData = love.data.encode("json", backupFiles)
    local filename = "backup_export_" .. os.time() .. ".json"
    love.filesystem.write(filename, backupData)
    
    gameInstaller.log("Backup exported: " .. filename, "INFO")
    return filename
end

function gameInstaller.importBackup(filename)
    local data = love.filesystem.read(filename)
    if not data then
        return false
    end
    
    local backupData = love.data.decode("json", data)
    if not backupData then
        return false
    end
    
    backupFiles = backupData
    gameInstaller.log("Backup imported: " .. gameInstaller.tableLength(backupFiles) .. " files", "INFO")
    return true
end

function gameInstaller.diagnose()
    return {
        initialized = isInitialized,
        installing = isInstalling,
        backupCount = gameInstaller.tableLength(backupFiles),
        logSize = #installLog,
        installedMod = gameInstaller.getInstalledMod()
    }
end

gameInstaller.init()

return gameInstaller

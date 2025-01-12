--[[
    Menu Library Demo
    Shows proper usage of the improved menu library
]]

-- Import the menu library
local menuLib = require("menu")

-- Create our windows
local mainWindow
local settingsWindow
local logWindow

-- Track demo state
local demoState = {
    logMessages = {},
    maxLogs = 100,
    settings = {
        value1 = 50,
        value2 = true,
        value3 = "option1"
    },
    lastKeyState = false
}

-- Helper function to add log message
local function addLog(message)
    table.insert(demoState.logMessages, {
        time = os.date("%H:%M:%S"),
        text = message
    })
    
    -- Keep log size in check
    while #demoState.logMessages > demoState.maxLogs do
        table.remove(demoState.logMessages, 1)
    end
end

-- Update settings window content
local function updateSettingsWindow()
    if not settingsWindow then return end
    
    settingsWindow:clearItems()
    
    -- Add settings items with descriptions
    settingsWindow:addItem({
        text = string.format("Value: %d", demoState.settings.value1),
        extraText = " - Click to increase by 10"
    })
    settingsWindow:addItem({
        text = string.format("Toggle: %s", demoState.settings.value2 and "On" or "Off"),
        extraText = " - Click to toggle"
    })
    settingsWindow:addItem({
        text = string.format("Option: %s", demoState.settings.value3),
        extraText = " - Click to cycle"
    })
end

-- Update log window content
local function updateLogWindow()
    if not logWindow then return end
    
    logWindow:clearItems()
    
    -- Add latest logs as items (most recent first)
    for i = #demoState.logMessages, math.max(1, #demoState.logMessages - 30), -1 do
        local log = demoState.logMessages[i]
        if log then
            logWindow:addItem({
                text = string.format("[%s] %s", log.time, log.text),
                extraText = " - Log Entry"  -- Show on hover
            })
        end
    end
end

-- Initialize windows
local function createWindows()
    -- Main menu window
    mainWindow = menuLib.createWindow("Menu Demo", {
        x = 100,
        y = 100,
        width = 300,
        desiredItems = 5,
        onClose = function()
            -- Close child windows
            settingsWindow.isOpen = false
            logWindow.isOpen = false
            addLog("Closed all windows")
        end,
        onItemClick = function(index)
            if index == 1 then
                settingsWindow.isOpen = not settingsWindow.isOpen
                addLog("Toggled settings window")
            elseif index == 2 then
                logWindow.isOpen = not logWindow.isOpen
                addLog("Toggled log window")
            elseif index == 3 then
                -- Reset window positions
                mainWindow.x = 100
                mainWindow.y = 100
                settingsWindow.x = 420
                settingsWindow.y = 100
                logWindow.x = 420
                logWindow.y = 420
                addLog("Reset window positions")
            end
        end
    })

    -- Add main menu items
    mainWindow:addItem({
        text = "Settings",
        extraText = " - Configure options"
    })
    mainWindow:addItem({
        text = "Show Logs",
        extraText = " - View message history"
    })
    mainWindow:addItem({
        text = "Reset Windows",
        extraText = " - Reset window positions"
    })

    -- Settings window
    settingsWindow = menuLib.createWindow("Settings", {
        x = 420,
        y = 100,
        width = 400,
        desiredItems = 8,
        onItemClick = function(index)
            -- Handle settings changes
            if index == 1 then
                demoState.settings.value1 = (demoState.settings.value1 + 10) % 100
            elseif index == 2 then
                demoState.settings.value2 = not demoState.settings.value2
            elseif index == 3 then
                local options = {"option1", "option2", "option3"}
                for i, opt in ipairs(options) do
                    if opt == demoState.settings.value3 then
                        demoState.settings.value3 = options[i % #options + 1]
                        break
                    end
                end
            end
            addLog("Changed setting " .. index)
            updateSettingsWindow()  -- Refresh settings display
        end
    })

    -- Log window
    logWindow = menuLib.createWindow("Message Log", {
        x = 420,
        y = 420,
        width = 400,
        desiredItems = 15
    })
    
    -- Initial updates
    updateSettingsWindow()
    updateLogWindow()
end

-- Menu toggle handling
local function handleToggleMenu()
    local currentKeyState = input.IsButtonDown(KEY_DELETE)
    
    -- Only toggle on key press, not hold
    if currentKeyState and not demoState.lastKeyState then
        -- Toggle main window
        mainWindow.isOpen = not mainWindow.isOpen
        
        if mainWindow.isOpen then
            -- Refresh content when opening
            addLog("Opened menu")
            updateSettingsWindow()
            updateLogWindow()
        else
            -- Close child windows when closing main
            settingsWindow.isOpen = false
            logWindow.isOpen = false
            addLog("Closed menu")
        end
    end
    
    demoState.lastKeyState = currentKeyState
end

-- Main draw callback
callbacks.Register("Draw", function()
    -- Handle menu toggle
    handleToggleMenu()
    
    -- Update log window if it's open
    if logWindow and logWindow.isOpen then
        updateLogWindow()
    end
end)

-- Initialize
createWindows()
addLog("Menu demo initialized")

print("Menu demo loaded! Press DELETE to open/close menu")
print("Hover over items to see descriptions")

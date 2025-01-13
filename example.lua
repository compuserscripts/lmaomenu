--[[
    Menu Library Demo
    Showcases all features of the menu library
]]

-- Import the menu library
local menu = require("menu")

-- Create our windows
local mainWindow
local widgetsWindow
local settingsWindow
local logWindow
local tabbedWindow  -- New tabbed window

-- Track demo state
local demoState = {
    logMessages = {},
    maxLogs = 100,
    settings = {
        sliderValue = 50,
        checkboxState = false,  -- Start with checkbox unchecked
        selectedOption = 1,
        progressValue = 0,
        progressDirection = 1,
        listItems = {
            {text = "Draggable Windows", extraText = " - Try dragging window titles"},
            {text = "Scrollable Content", extraText = " - Use mousewheel to scroll"},
            {text = "Hover Information", extraText = " - Like this tooltip!"},
            {text = "Item 4", extraText = " - Extra info"},
            {text = "Item 5", extraText = " - More info"},
            {text = "Item 6", extraText = " - Click me"},
            {text = "Item 7", extraText = " - Another item"},
            {text = "Item 8", extraText = " - And another"},
            {text = "Item 9", extraText = " - Keep scrolling"},
            {text = "Item 10", extraText = " - Last one"}
        }
    },
    lastKeyState = false,
    lastUpdateTime = 0,
    updateInterval = 1/30  -- 30fps update rate for animations
}

-- Forward declare functions
local updateWindows
local updateLogWindow
local updateTabbedWindow  -- New function for tabbed window

-- Helper function to add log message
local function addLog(message)
    if not message then return end
    
    table.insert(demoState.logMessages, {
        time = os.date("%H:%M:%S"),
        text = tostring(message)
    })
    
    -- Keep log size under control
    while #demoState.logMessages > demoState.maxLogs do
        table.remove(demoState.logMessages, 1)
    end
    
    -- Update log window if it's open
    if logWindow and logWindow.isOpen then
        updateLogWindow()
    end
end

-- Update log window content
function updateLogWindow()
    if not logWindow then return end
    logWindow:clearWidgets()
    
    -- Convert log messages to list format
    local listItems = {}
    for _, log in ipairs(demoState.logMessages) do
        table.insert(listItems, {
            text = string.format("[%s] %s", log.time, log.text),
            extraText = " - Log Entry"
        })
    end
    
    -- Add latest logs to list widget
    logWindow:createList(listItems, function(index, item)
        addLog("Clicked log entry: " .. item.text)
    end)
    
    -- Add clear button
    logWindow:createButton("Clear Logs", function()
        demoState.logMessages = {}
        updateLogWindow()
        logWindow.height = logWindow:calculateHeight()
        addLog("Cleared logs")
    end)
end

function updateTabbedWindow()
    if not tabbedWindow or not tabbedWindow.isOpen then return end
    
    -- Initialize tab states if they don't exist
    if not tabbedWindow.tabStates then
        tabbedWindow.tabStates = {
            Controls = {
                checkboxState = false,
                sliderValue = 50
            },
            Visuals = {
                dropdownSelected = 1
            }
        }
    end
    
    -- Get tab panel without clearing widgets first
    local tabPanel = tabbedWindow:renderTabPanel()
    
    -- Only add tabs if they haven't been added yet
    if #tabPanel.tabOrder == 0 then
        tabPanel:addTab("Controls", function()
            tabbedWindow.widgets = {}
            local states = tabbedWindow.tabStates.Controls
            tabbedWindow:createButton("Tab 1 Button", function()
                addLog("Button clicked in Controls tab")
            end)
            tabbedWindow:createCheckbox("Tab 1 Checkbox", states.checkboxState, function(checked)
                states.checkboxState = checked
                addLog("Controls tab checkbox: " .. tostring(checked))
            end)
            tabbedWindow:createSlider("Tab 1 Slider", states.sliderValue, 0, 100, function(value)
                states.sliderValue = value
                addLog("Controls tab slider: " .. tostring(value))
            end)
        end)

        tabPanel:addTab("Visuals", function()
            -- Clear active dropdown when switching to this tab
            menu._mouseState.activeDropdown = nil
            
            tabbedWindow.widgets = {}
            local states = tabbedWindow.tabStates.Visuals
            tabbedWindow:createProgressBar("Tab 2 Progress", 75, 0, 100)
            
            -- Create combo box and store reference
            local combo = tabbedWindow:createComboBox("Tab 2 Dropdown", 
                {"Item 1", "Item 2", "Item 3"}, 
                states.dropdownSelected,
                function(index, value)
                    states.dropdownSelected = index
                    addLog("Selected " .. value .. " in Visuals tab")
                end
            )
            
            -- Store combo box reference for this tab
            tabbedWindow.tabStates.Visuals.comboWidget = combo
        end)

        tabPanel:addTab("List", function()
            -- Clear active dropdown when switching to this tab
            menu._mouseState.activeDropdown = nil
            
            tabbedWindow.widgets = {}
            local items = {
                {text = "List Item 1", extraText = " - Tab 3"},
                {text = "List Item 2", extraText = " - Click Me"},
                {text = "List Item 3", extraText = " - In Tab 3"}
            }
            tabbedWindow:createList(items, function(index, item)
                addLog("Clicked " .. item.text .. " in List tab")
            end)
        end)
        
        -- Override tab panel's selectTab to handle dropdown state
        local originalSelectTab = tabPanel.selectTab
        tabPanel.selectTab = function(self, name)
            -- Clear any active dropdown before switching
            menu._mouseState.activeDropdown = nil
            if originalSelectTab then
                originalSelectTab(self, name)
            end
        end
    end
end

-- Update all windows content
function updateWindows()
    -- Update widgets showcase window
    if widgetsWindow and widgetsWindow.isOpen then
        widgetsWindow:clearWidgets()
        
        widgetsWindow:createButton("Standard Button", function()
            addLog("Clicked standard button")
        end)

        widgetsWindow:createCheckbox("Demo Checkbox", demoState.settings.checkboxState, function(checked)
            demoState.settings.checkboxState = checked
            addLog("Checkbox toggled: " .. tostring(checked))
        end)

        widgetsWindow:createSlider("Demo Slider", demoState.settings.sliderValue, 0, 100, function(value)
            demoState.settings.sliderValue = math.floor(value * 10) / 10
            addLog("Slider changed: " .. string.format("%.1f", value))
        end)

        widgetsWindow:createProgressBar("Demo Progress", 
            math.floor(demoState.settings.progressValue), 0, 100)

        widgetsWindow:createComboBox("Demo Dropdown", 
            {"Option 1", "Option 2", "Option 3", "Option 4"}, 
            demoState.settings.selectedOption,
            function(index, value)
                demoState.settings.selectedOption = index
                addLog("Selected option: " .. value)
            end
        )

        widgetsWindow:createList(demoState.settings.listItems, function(index, item)
            addLog("Clicked list item: " .. item.text)
        end)
    end

    -- Update settings window
    if settingsWindow and settingsWindow.isOpen then
        settingsWindow:clearWidgets()
        
        settingsWindow:createSlider("Animation Speed", demoState.settings.sliderValue, 0, 100, function(value)
            demoState.settings.sliderValue = math.floor(value * 10) / 10
            addLog("Changed animation speed: " .. string.format("%.1f", value))
        end)

        settingsWindow:createCheckbox("Enable Effects", demoState.settings.checkboxState, function(checked)
            demoState.settings.checkboxState = checked
            addLog("Toggled effects: " .. tostring(checked))
        end)

        settingsWindow:createComboBox("Theme", 
            {"Default", "Dark", "Light", "Custom"}, 
            demoState.settings.selectedOption,
            function(index, value)
                demoState.settings.selectedOption = index
                addLog("Changed theme to: " .. value)
            end
        )
    end

    -- Update log window
    if logWindow and logWindow.isOpen then
        updateLogWindow()
    end
    
    -- Update tabbed window - but don't clear widgets here
    if tabbedWindow and tabbedWindow.isOpen then
        updateTabbedWindow()
    end
end

-- Initialize windows
local function createWindows()
    -- Main menu window
    mainWindow = menu.createWindow("Enhanced Menu Demo", {
        x = 100,
        y = 100,
        width = 300,
        desiredItems = 6,  -- Increased for new button
        onClose = function()
            menu.closeAll()
            addLog("Closed all windows")
        end
    })

    -- Add main menu widgets
    mainWindow:createButton("Widget Showcase", function()
        if not widgetsWindow.isOpen then
            widgetsWindow:focus()
            updateWindows()
            addLog("Opened widgets window")
        else
            widgetsWindow:unfocus()
            addLog("Closed widgets window")
        end
    end)

    mainWindow:createButton("Settings", function()
        if not settingsWindow.isOpen then
            settingsWindow:focus()
            updateWindows()
            addLog("Opened settings window")
        else
            settingsWindow:unfocus()
            addLog("Closed settings window")
        end
    end)

    mainWindow:createButton("Show Logs", function()
        if not logWindow.isOpen then
            logWindow:focus()
            updateWindows()
            addLog("Opened log window")
        else
            logWindow:unfocus()
            addLog("Closed log window")
        end
    end)

    -- Add new tabbed window button
    mainWindow:createButton("Tab Demo", function()
        if not tabbedWindow.isOpen then
            tabbedWindow:focus()
            updateWindows()
            addLog("Opened tabbed window")
        else
            tabbedWindow:unfocus()
            addLog("Closed tabbed window")
        end
    end)

    mainWindow:createButton("Reset Windows", function()
        mainWindow.x = 100
        mainWindow.y = 100
        widgetsWindow.x = 420
        widgetsWindow.y = 100
        settingsWindow.x = 420
        settingsWindow.y = 300
        logWindow.x = 420
        logWindow.y = 500
        tabbedWindow.x = 420
        tabbedWindow.y = 200
        addLog("Reset window positions")
    end)

    -- Widgets showcase window
    widgetsWindow = menu.createWindow("Widget Showcase", {
        x = 420,
        y = 100,
        width = 400,
        desiredItems = 12
    })

    -- Settings window
    settingsWindow = menu.createWindow("Settings", {
        x = 420,
        y = 300,
        width = 400,
        desiredItems = 8
    })

    -- Log window
    logWindow = menu.createWindow("Message Log", {
        x = 420,
        y = 500,
        width = 400,
        desiredItems = 15
    })

    -- Tabbed window
    tabbedWindow = menu.createWindow("Tabbed Window Demo", {
        x = 420,
        y = 200,
        width = 400,
        desiredItems = 10
    })

    -- Initialize windows content
    updateWindows()
end

-- Menu toggle handling
local function handleToggleMenu()
    local currentKeyState = input.IsButtonDown(KEY_DELETE)
    
    if currentKeyState and not demoState.lastKeyState then
        if not mainWindow.isOpen then
            mainWindow:focus()
            updateWindows()
            addLog("Opened menu")
        else
            menu.closeAll()
            addLog("Closed menu")
        end
    end
    
    demoState.lastKeyState = currentKeyState
end

-- Animate progress bar
local function updateProgressBar()
    local currentTime = globals.RealTime()
    if currentTime - demoState.lastUpdateTime >= demoState.updateInterval then
        if demoState.settings.checkboxState then
            demoState.settings.progressValue = demoState.settings.progressValue + 
                (demoState.settings.progressDirection * (demoState.settings.sliderValue / 50))
            
            if demoState.settings.progressValue >= 100 then
                demoState.settings.progressValue = 100
                demoState.settings.progressDirection = -1
            elseif demoState.settings.progressValue <= 0 then
                demoState.settings.progressValue = 0
                demoState.settings.progressDirection = 1
            end
            
            demoState.settings.progressValue = math.floor(demoState.settings.progressValue)
            
            if widgetsWindow and widgetsWindow.isOpen then
                for _, widget in ipairs(widgetsWindow.widgets) do
                    if widget.type == 'progress' then
                        widget.state.value = demoState.settings.progressValue
                        break
                    end
                end
            end
        end
        demoState.lastUpdateTime = currentTime
    end
end

-- Main draw callback
callbacks.Register("Draw", function()
    handleToggleMenu()
    updateProgressBar()
end)

-- Add unload callback at the end of the file
callbacks.Register("Unload", function()
    -- Close all windows 
    menu.closeAll()
    
    -- Clear our window references
    mainWindow = nil
    widgetsWindow = nil 
    settingsWindow = nil
    logWindow = nil
    tabbedWindow = nil
    
    -- Clear state
    demoState = nil
    
    print("Menu demo unloaded")
end)

-- Initialize
createWindows()
addLog("Enhanced menu demo initialized")

print("Enhanced menu demo loaded! Press DELETE to open/close menu")
print("Click 'Tab Demo' to see the tabbed window example!")
print("Hover over items to see descriptions")

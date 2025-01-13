--[[
    LmaoMenu - A flexible menu library for Lmaobox Lua 5.1 scripts
]]

local menu = {
    -- Constants
    SCROLL_DELAY = 0.1,
    CHECK_INTERVAL = 5,

    -- Global mouse state
    _mouseState = {
        lastState = false,
        released = false,
        isDragging = false,
        dragOffsetX = 0,
        dragOffsetY = 0,
        isDraggingScrollbar = false,
        wasScrollbarDragging = false,
        hasSeenMousePress = false,
        lastScrollTime = 0,
        activeDropdown = nil,
        eventHandled = false
    },

    -- Global menu state
    _state = {
        windows = {},
        activeWindow = nil,
        menuFont = nil,
        lastFontSetting = nil,
        wasConsoleOpen = false,
        activeWidget = nil,
        windowStack = {},
        lastInteractedWidget = nil,
        CurrentID = 1
    },

    -- Theme colors
    colors = {
        windowBg = {20, 20, 20, 255},
        titleBarBg = {30, 30, 30, 255},
        titleText = {255, 255, 255, 255},
        border = {50, 50, 50, 255},
        itemBg = {25, 25, 25, 255},
        itemHoverBg = {40, 40, 40, 255},
        itemActiveBg = {60, 60, 60, 255},
        close = {255, 255, 255, 255},
        closeHover = {255, 100, 100, 255},
        scrollbarBg = {40, 40, 40, 255},
        scrollbarHoverBg = {50, 50, 50, 255},
        scrollbarThumb = {80, 80, 80, 255},
        scrollbarThumbHover = {100, 100, 100, 255},
        scrollbarThumbActive = {120, 120, 120, 255},
        checkmark = {255, 255, 255, 255},
        sliderBar = {55, 100, 215, 255},
        progressBar = {55, 100, 215, 255},
        dropdownBg = {30, 30, 30, 255},
        dropdownBorder = {50, 50, 50, 255},
        dropdownText = {255, 255, 255, 255},
        tabBg = {25, 25, 25, 255},
        tabHoverBg = {40, 40, 40, 255},
        tabActiveBg = {60, 60, 60, 255},
        tabText = {255, 255, 255, 255},
        tabBar = {40, 40, 40, 255},  -- Background color for tab bar
        tab = {50, 50, 50, 255},     -- Normal tab color
        tabHover = {60, 60, 60, 255}, -- Tab hover color
        tabActive = {70, 70, 70, 255}, -- Selected tab color
    }
}

-- Helper functions
local function getMousePos()
    local mousePos = input.GetMousePos()
    return math.floor(tonumber(mousePos[1]) or 0), math.floor(tonumber(mousePos[2]) or 0)
end

local function setColor(color)
    if type(color) == "table" and #color >= 4 then
        draw.Color(color[1], color[2], color[3], color[4])
    end
end

local function isInBounds(pX, pY, pX2, pY2)
    local mX, mY = getMousePos()
    return (mX >= pX and mX <= pX2 and mY >= pY and mY <= pY2)
end

local function truncateText(text, maxWidth, hasScrollbar, isHovered, extraText)
    local padding = 20
    local scrollbarWidth = hasScrollbar and 16 or 0
    local actualMaxWidth = math.floor(maxWidth - padding - scrollbarWidth)
    
    if isHovered and extraText then
        local extraWidth = draw.GetTextSize(extraText)
        actualMaxWidth = math.floor(actualMaxWidth - extraWidth - 5)
    end
    
    local fullWidth = draw.GetTextSize(text)
    if fullWidth <= actualMaxWidth then
        return text
    end
    
    -- Binary search for the right length
    local left, right = 1, #text
    while left <= right do
        local mid = math.floor((left + right) / 2)
        local truncated = text:sub(1, mid) .. "..."
        local width = draw.GetTextSize(truncated)
        
        if width == actualMaxWidth then
            return truncated
        elseif width < actualMaxWidth then
            left = mid + 1
        else
            right = mid - 1
        end
    end
    
    return text:sub(1, right) .. "..."
end

-- Widget class
local Widget = {}
Widget.__index = Widget

function Widget.new(type, config, window)
    local self = setmetatable({}, Widget)
    self.type = type
    self.config = config or {}
    self.window = window  -- Store reference to parent window
    self.state = {
        isHovered = false,
        isActive = false,
        lastInteraction = 0,
        value = config.initialValue,
        checked = config.initialState,
        selected = config.initialSelected or 1,
        isOpen = false,
        scrollOffset = 0
    }
    return self
end

-- TabPanel class
local TabPanel = {}
TabPanel.__index = TabPanel

function TabPanel.new(config, window)
    local self = setmetatable({}, TabPanel)
    self.type = 'tabpanel'
    self.config = config or {}
    self.window = window
    self.tabs = {}
    self.tabOrder = {}
    self.currentTab = nil
    self.itemHeight = 30  -- Fixed tab height
    self.state = {
        isHovered = false,
        isActive = false
    }
    self.initialized = false  -- Add this flag
    -- Set config defaults
    self.config.height = self.config.height or self.itemHeight
    return self
end

function TabPanel:addTab(name, contentFunc)
    if type(name) == "string" then
        self.tabs[name] = contentFunc
        table.insert(self.tabOrder, name)
        if self.currentTab == nil then
            self.currentTab = name
            -- Call the content function for the first tab
            if contentFunc then
                contentFunc()
            end
        end
    end
end

function TabPanel:selectTab(name)
    if self.tabs[name] and name ~= self.currentTab then
        self.currentTab = name
        -- Clear any active dropdown
        menu._mouseState.activeDropdown = nil
        -- Clear existing widgets
        self.window.widgets = {}
        -- Call content function for new tab
        if self.tabs[name] then
            self.tabs[name]()
        end
    end
end

function TabPanel:render(menu, x, y)
    local tabCount = #self.tabOrder
    if tabCount == 0 then return self.itemHeight end

    local tabWidth = math.floor(self.window.width / tabCount)
    local remainingPixels = self.window.width - (tabWidth * tabCount)
    local currentX = 0
    
    -- Draw tab bar background
    setColor(menu.colors.titleBarBg)
    draw.FilledRect(x, y, x + self.window.width, y + self.itemHeight)
    
    -- Draw tabs
    for i, name in ipairs(self.tabOrder) do
        local tabX = math.floor(x + currentX)
        local currentTabWidth = i == tabCount and (tabWidth + remainingPixels) or tabWidth
        local tabRight = math.floor(tabX + currentTabWidth)
        local tabBottom = math.floor(y + self.itemHeight)
        
        -- Check if mouse is over this tab
        local isHovered = isInBounds(tabX, y, tabRight, tabBottom)
        
        -- Set colors based on state
        if name == self.currentTab then
            setColor(menu.colors.itemActiveBg)
        elseif isHovered then
            setColor(menu.colors.itemHoverBg)
            if menu._mouseState.released then
                self:selectTab(name)
            end
        else
            setColor(menu.colors.itemBg)
        end
        
        -- Draw tab background
        draw.FilledRect(tabX, y, tabRight, tabBottom)
        
        -- Draw tab text
        setColor(menu.colors.titleText)
        local textWidth = draw.GetTextSize(name)
        draw.Text(
            math.floor(tabX + (currentTabWidth/2) - (textWidth/2)), 
            math.floor(y + (self.itemHeight/2) - 8), 
            name
        )
        
        currentX = currentX + currentTabWidth
    end
    
    return self.itemHeight
end

-- Window class
local Window = {}
Window.__index = Window

function Window.new(title, config)
    local self = setmetatable({}, Window)
    
    -- Window properties
    self.title = title or "Window"
    self.x = math.floor(tonumber(config.x) or 100)
    self.y = math.floor(tonumber(config.y) or 100)
    self.width = math.floor(tonumber(config.width) or 400)
    self.desiredItems = math.floor(tonumber(config.desiredItems) or 10)
    self.titleBarHeight = math.floor(tonumber(config.titleBarHeight) or 30)
    self.itemHeight = math.floor(tonumber(config.itemHeight) or 25)
    self.footerHeight = math.floor(tonumber(config.footerHeight) or 30)
    
    -- State
    self.isOpen = false
    self.widgets = {}
    self.scrollOffset = 0
    self.interactionState = 'none'
    self.clickStartedInWindow = false
    self.clickStartedInTitleBar = false
    self.clickStartedInScrollbar = false
    self.clickStartRegion = nil
    self.clickStartX = 0
    self.clickStartY = 0
    self.zIndex = #menu._state.windows + 1
    self.previousWindow = nil
    
    -- Content
    self.height = self:calculateHeight()
    
    -- Callbacks
    self.onClose = config.onClose
    
    table.insert(menu._state.windows, self)
    
    return self
end

function Window:focus()
    local prevActive = menu._state.activeWindow
    
    if prevActive and prevActive ~= self then
        self.previousWindow = prevActive
        prevActive.isOpen = false
    end
    
    menu._state.activeWindow = self
    self.isOpen = true
    self.zIndex = #menu._state.windows + 1
    
    -- Sort windows by z-index
    table.sort(menu._state.windows, function(a, b)
        return a.zIndex < b.zIndex
    end)
end

function Window:unfocus()
    self.isOpen = false
    menu._state.activeWindow = self.previousWindow
    
    if self.previousWindow then
        self.previousWindow.isOpen = true
        self.previousWindow = nil
    end
end

-- Widget creation methods
function Window:createButton(text, onClick)
    local widget = Widget.new('button', {
        text = text,
        onClick = onClick,
        width = 200,
        height = self.itemHeight
    }, self)  -- Pass window reference
    table.insert(self.widgets, widget)
    return widget
end


function Window:createCheckbox(text, initialState, onChange)
    local widget = Widget.new('checkbox', {
        text = text,
        onChange = onChange,
        width = 200,
        height = self.itemHeight,
        initialState = initialState
    }, self)  -- Pass window reference
    table.insert(self.widgets, widget)
    return widget
end

function Window:createSlider(text, initialValue, min, max, onChange)
    local widget = Widget.new('slider', {
        text = text,
        min = min,
        max = max,
        onChange = onChange,
        width = 200,
        height = self.itemHeight,
        initialValue = initialValue
    }, self)  -- Pass window reference
    table.insert(self.widgets, widget)
    return widget
end

function Window:createProgressBar(text, initialValue, min, max)
    local widget = Widget.new('progress', {
        text = text,
        min = min,
        max = max,
        width = 200,
        height = math.floor(self.itemHeight / 2),  -- Floor this division
        initialValue = initialValue
    }, self)  -- Pass window reference
    table.insert(self.widgets, widget)
    return widget
end

function Window:createComboBox(text, options, initialSelected, onChange)
    local widget = Widget.new('combo', {
        text = text,
        options = options,
        onChange = onChange,
        width = 200,
        height = self.itemHeight,
        initialSelected = initialSelected
    }, self)  -- Pass window reference
    table.insert(self.widgets, widget)
    return widget
end

function Window:createList(items, onItemClick)
    local widget = Widget.new('list', {
        items = items or {},
        onItemClick = onItemClick,
        width = math.floor(self.width - 20),  -- Floor this subtraction
        itemHeight = self.itemHeight,
        visibleItems = self.desiredItems
    }, self)  -- Pass window reference
    table.insert(self.widgets, widget)
    return widget
end

function Window:calculateHeight()
    local contentHeight = 0
    
    -- Add tab panel height if exists
    if self._tabPanel then
        contentHeight = contentHeight + self._tabPanel.itemHeight
    end
    
    for _, widget in ipairs(self.widgets) do
        if widget.type == 'list' then
            local minVisibleItems = 3
            local visibleItems = math.max(minVisibleItems, math.min(#widget.config.items, widget.config.visibleItems))
            contentHeight = contentHeight + (visibleItems * widget.config.itemHeight)
        else
            contentHeight = contentHeight + widget.config.height
        end
        
        if widget.type == 'combo' and widget.state.isOpen then
            contentHeight = contentHeight + (#widget.config.options * self.itemHeight)
        end
        
        contentHeight = contentHeight + 5  -- Spacing between widgets
    end
    
    return math.floor(self.titleBarHeight + contentHeight + self.footerHeight)
end

function Window:clearWidgets()
    self.widgets = {}
    self.scrollOffset = 0
    self.height = self:calculateHeight()
end

function Window:_updateMouseState()
    local mouseState = input.IsButtonDown(MOUSE_LEFT)
    
    if mouseState and not menu._mouseState.lastState then
        menu._mouseState.hasSeenPress = true
        menu._mouseState.eventHandled = false
        
        local mX, mY = getMousePos()
        
        if isInBounds(self.x, self.y, self.x + self.width, self.y + self.height) then
            self:focus()
            self.clickStartedInWindow = true
            menu._state.activeWindow = self
            
            if isInBounds(self.x, self.y, self.x + self.width, self.y + self.titleBarHeight) then
                self.clickStartedInTitleBar = true
                self.interactionState = 'dragging'
                self.clickStartRegion = 'titlebar'
                menu._mouseState.dragOffsetX = mX - self.x
                menu._mouseState.dragOffsetY = mY - self.y
            else
                self.interactionState = 'clicking'
                self.clickStartRegion = 'content'
            end
            
            -- Clear active dropdown when clicking in a different window
            if menu._mouseState.activeDropdown and 
               menu._mouseState.activeDropdown.window ~= self then
                menu._mouseState.activeDropdown.state.isOpen = false
                menu._mouseState.activeDropdown = nil
            end
        end
    end
    
    menu._mouseState.released = menu._mouseState.lastState and not mouseState
    menu._mouseState.lastState = mouseState
    
    if menu._mouseState.released then
        if menu._mouseState.isDraggingScrollbar then
            menu._mouseState.isDraggingScrollbar = false
            menu._state.activeWidget = nil
            return true
        end
        
        menu._mouseState.isDragging = false
        self.clickStartedInTitleBar = false
        self.interactionState = 'none'
        self.clickStartRegion = nil
    end
    
    return false
end

function Window:_handleCloseButton()
    local closeText = "×"
    local closeWidth = draw.GetTextSize(closeText)
    local closeX = math.floor(self.x + self.width - closeWidth - 10)
    local closeY = math.floor(self.y + 8)
    local closeButtonBounds = isInBounds(closeX - 5, closeY - 5, closeX + closeWidth + 5, closeY + 15)

    if closeButtonBounds and self.interactionState ~= 'dragging' then
        setColor(menu.colors.closeHover)
        if menu._mouseState.released and self.clickStartedInWindow and 
           (self.clickStartRegion == 'titlebar' or self.clickStartRegion == nil) then
            self:unfocus()
            if self.onClose then self.onClose() end
            menu._mouseState.eventHandled = true
            return true
        end
    else
        setColor(menu.colors.close)
    end
    draw.Text(closeX, closeY, closeText)
    return false
end

function Window:renderButton(widget, x, y)
    local config = widget.config
    local isHovered = isInBounds(x, y, x + config.width, y + config.height)
    local isActive = menu._state.activeWidget == widget
    
    if isActive then
        setColor(menu.colors.itemActiveBg)
    elseif isHovered then
        setColor(menu.colors.itemHoverBg)
    else
        setColor(menu.colors.itemBg)
    end
    
    -- Ensure all coordinates are integers
    x = math.floor(x)
    y = math.floor(y)
    local x2 = math.floor(x + config.width)
    local y2 = math.floor(y + config.height)
    
    draw.FilledRect(x, y, x2, y2)
    
    setColor(menu.colors.titleText)
    local textWidth = draw.GetTextSize(config.text)
    local textX = math.floor(x + (config.width - textWidth) / 2)
    local textY = math.floor(y + (config.height - 14) / 2)
    draw.Text(textX, textY, config.text)
    
    if isHovered and menu._mouseState.released and not menu._mouseState.eventHandled then
        if config.onClick then
            config.onClick()
        end
        menu._mouseState.eventHandled = true
    end
    
    return config.height
end

function Window:renderCheckbox(widget, x, y)
    local config = widget.config
    local boxSize = math.floor(config.height - 6)
    local isHovered = isInBounds(x, y, x + config.width, y + config.height)
    
    -- Ensure all coordinates are integers
    x = math.floor(x)
    y = math.floor(y)
    
    -- Pre-calculate all coordinates for FilledRect
    local boxEndX = math.floor(x + boxSize)
    local boxEndY = math.floor(y + boxSize)
    
    if isHovered then
        setColor(menu.colors.itemHoverBg)
    else
        setColor(menu.colors.itemBg)
    end
    
    -- Draw checkbox background
    draw.FilledRect(x, y, boxEndX, boxEndY)
    
    -- Draw checkmark if checked
    if widget.state.checked then
        setColor(menu.colors.checkmark)
        local innerX1 = math.floor(x + 3)
        local innerY1 = math.floor(y + 3)
        local innerX2 = math.floor(x + boxSize - 3)
        local innerY2 = math.floor(y + boxSize - 3)
        draw.FilledRect(innerX1, innerY1, innerX2, innerY2)
    end
    
    -- Draw text
    setColor(menu.colors.titleText)
    local textX = math.floor(x + boxSize + 6)
    local textY = math.floor(y + (config.height - 14) / 2)
    draw.Text(textX, textY, config.text)
    
    -- Handle interaction
    if isHovered and menu._mouseState.released and not menu._mouseState.eventHandled then
        widget.state.checked = not widget.state.checked
        if config.onChange then
            config.onChange(widget.state.checked)
        end
        menu._mouseState.eventHandled = true
    end
    
    return config.height
end

function Window:renderSlider(widget, x, y)
    local config = widget.config
    local isHovered = isInBounds(x, y, x + config.width, y + config.height)
    local isActive = menu._state.activeWidget == widget
    
    if isHovered or isActive then
        setColor(menu.colors.itemHoverBg)
    else
        setColor(menu.colors.itemBg)
    end
    
    x, y = math.floor(x), math.floor(y)
    draw.FilledRect(x, y, x + config.width, y + config.height)
    
    local range = config.max - config.min
    local percentage = (widget.state.value - config.min) / range
    local sliderWidth = math.floor(config.width * percentage)
    
    setColor(menu.colors.sliderBar)
    draw.FilledRect(x, y, x + sliderWidth, y + config.height)
    
    setColor(menu.colors.titleText)
    local text = string.format("%s: %.1f", config.text, widget.state.value)
    local textWidth = draw.GetTextSize(text)
    local textX = math.floor(x + (config.width - textWidth) / 2)
    local textY = math.floor(y + (config.height - 14) / 2)
    draw.Text(textX, textY, text)
    
    if isHovered and input.IsButtonDown(MOUSE_LEFT) and not menu._mouseState.eventHandled then
        menu._state.activeWidget = widget
        local mouseX = getMousePos()
        local newPercentage = math.max(0, math.min(1, (mouseX - x) / config.width))
        local newValue = config.min + (range * newPercentage)
        widget.state.value = math.floor(newValue * 10) / 10  -- Round to 1 decimal place
        if config.onChange then
            config.onChange(widget.state.value)
        end
        menu._mouseState.eventHandled = true
    elseif not input.IsButtonDown(MOUSE_LEFT) and menu._state.activeWidget == widget then
        menu._state.activeWidget = nil
    end
    
    return config.height
end

function Window:renderProgressBar(widget, x, y)
    local config = widget.config
    
    x, y = math.floor(x), math.floor(y)
    setColor(menu.colors.itemBg)
    draw.FilledRect(x, y, x + config.width, y + config.height)
    
    local range = config.max - config.min
    local percentage = (widget.state.value - config.min) / range
    local progressWidth = math.floor(config.width * percentage)
    
    setColor(menu.colors.progressBar)
    draw.FilledRect(x, y, x + progressWidth, y + config.height)
    
    return config.height
end

function Window:renderComboBox(widget, x, y)
    local config = widget.config
    local isHovered = isInBounds(x, y, x + config.width, y + config.height)
    local totalHeight = config.height
    
    -- Ensure all coordinates are integers
    x = math.floor(x)
    y = math.floor(y)
    local endX = math.floor(x + config.width)
    local endY = math.floor(y + config.height)
    
    if isHovered then
        setColor(menu.colors.itemHoverBg)
    else
        setColor(menu.colors.itemBg)
    end
    draw.FilledRect(x, y, endX, endY)
    
    setColor(menu.colors.titleText)
    local selectedText = string.format("%s: %s", config.text, config.options[widget.state.selected])
    local textY = math.floor(y + (config.height - 14) / 2)
    draw.Text(x + 5, textY, selectedText)
    
    -- Draw dropdown arrow
    local arrowX = math.floor(x + config.width - 15)
    local arrowY = math.floor(y + (config.height - 8) / 2)
    setColor(menu.colors.titleText)
    if widget.state.isOpen then
        draw.Line(arrowX, arrowY + 4, arrowX + 4, arrowY)
        draw.Line(arrowX + 8, arrowY + 4, arrowX + 4, arrowY)
    else
        draw.Line(arrowX, arrowY, arrowX + 4, arrowY + 4)
        draw.Line(arrowX + 8, arrowY, arrowX + 4, arrowY + 4)
    end
    
    if isHovered and menu._mouseState.released and not menu._mouseState.eventHandled then
        widget.state.isOpen = not widget.state.isOpen
        menu._mouseState.activeDropdown = widget.state.isOpen and widget or nil
        menu._mouseState.eventHandled = true
    end
    
    if widget.state.isOpen and menu._mouseState.activeDropdown == widget then
        local dropdownY = math.floor(y + config.height)
        local dropdownHeight = math.floor(#config.options * config.height)
        
        setColor(menu.colors.dropdownBg)
        draw.FilledRect(x, dropdownY, endX, math.floor(dropdownY + dropdownHeight))
        
        for i, option in ipairs(config.options) do
            local optionY = math.floor(dropdownY + (i-1) * config.height)
            local isOptionHovered = isInBounds(x, optionY, endX, math.floor(optionY + config.height))
            
            if isOptionHovered then
                setColor(menu.colors.itemHoverBg)
                draw.FilledRect(x, optionY, endX, math.floor(optionY + config.height))
                
                if menu._mouseState.released and not menu._mouseState.eventHandled then
                    widget.state.selected = i
                    widget.state.isOpen = false
                    menu._mouseState.activeDropdown = nil
                    if config.onChange then
                        config.onChange(i, option)
                    end
                    menu._mouseState.eventHandled = true
                end
            end
            
            setColor(menu.colors.dropdownText)
            local optTextY = math.floor(optionY + (config.height - 14) / 2)
            draw.Text(x + 5, optTextY, option)
        end
        
        totalHeight = totalHeight + dropdownHeight
    end
    
    return totalHeight
end

function Window:renderList(widget, x, y)
    local config = widget.config
    
    -- Ensure all coordinates are integers
    x = math.floor(x)
    y = math.floor(y)
    
    -- Calculate minimum height - ensure list takes up at least 3 item slots even when empty
    local minVisibleItems = 3  -- You can adjust this number as needed
    local visibleItems = math.max(minVisibleItems, math.min(#config.items, config.visibleItems))
    local visibleHeight = math.floor(visibleItems * config.itemHeight)
    
    local hasScrollbar = #config.items > config.visibleItems
    local width = math.floor(config.width - (hasScrollbar and 16 or 0))
    
    -- Handle scrolling with rate limiting
    if isInBounds(x, y, x + width + (hasScrollbar and 16 or 0), y + visibleHeight) then
        local currentTime = globals.RealTime()
        if currentTime - menu._mouseState.lastScrollTime >= menu.SCROLL_DELAY then
            if input.IsButtonPressed(MOUSE_WHEEL_UP) and widget.state.scrollOffset > 0 then
                widget.state.scrollOffset = widget.state.scrollOffset - 1
                menu._mouseState.lastScrollTime = currentTime
            elseif input.IsButtonPressed(MOUSE_WHEEL_DOWN) and 
                   widget.state.scrollOffset < #config.items - config.visibleItems then
                widget.state.scrollOffset = widget.state.scrollOffset + 1
                menu._mouseState.lastScrollTime = currentTime
            end
        end
    end
    
    -- Draw background for minimum height
    setColor(menu.colors.itemBg)
    draw.FilledRect(x, y, x + width + (hasScrollbar and 16 or 0), y + visibleHeight)
    
    -- Draw visible items
    for i = 1, math.min(#config.items, visibleItems) do
        local itemIndex = i + widget.state.scrollOffset
        local item = config.items[itemIndex]
        if item then
            local itemY = math.floor(y + (i-1) * config.itemHeight)
            local itemEndY = math.floor(itemY + config.itemHeight)
            
            local isHovered = isInBounds(x, itemY, x + width, itemEndY)
            
            if isHovered then
                setColor(menu.colors.itemHoverBg)
                draw.FilledRect(x, itemY, x + width, itemEndY)
            end
            
            setColor(menu.colors.titleText)
            local text = truncateText(item.text, width, hasScrollbar, isHovered, item.extraText)
            local textY = math.floor(itemY + (config.itemHeight - 14) / 2)
            draw.Text(x + 5, textY, text)
            
            if isHovered and item.extraText then
                local textWidth = draw.GetTextSize(text)
                draw.Text(x + 10 + textWidth, textY, item.extraText)
            end
            
            if isHovered and menu._mouseState.released and not menu._mouseState.eventHandled then
                if config.onItemClick then
                    config.onItemClick(itemIndex, item)
                    menu._mouseState.eventHandled = true
                end
            end
        end
    end
    
    -- Draw and handle scrollbar
    if hasScrollbar then
        local scrollbarX = math.floor(x + width)
        local scrollbarWidth = 16
        local contentHeight = #config.items * config.itemHeight
        local thumbHeight = math.max(20, math.floor((visibleHeight / contentHeight) * visibleHeight))
        local maxOffset = #config.items - config.visibleItems
        local scrollRatio = widget.state.scrollOffset / maxOffset
        local thumbY = math.floor(y + scrollRatio * (visibleHeight - thumbHeight))
        
        -- Draw scrollbar background
        setColor(menu.colors.scrollbarBg)
        draw.FilledRect(scrollbarX, y, scrollbarX + scrollbarWidth, y + visibleHeight)
        
        -- Draw thumb
        if menu._mouseState.isDraggingScrollbar and menu._state.activeWidget == widget then
            setColor(menu.colors.scrollbarThumbActive)
        elseif isInBounds(scrollbarX, thumbY, scrollbarX + scrollbarWidth, thumbY + thumbHeight) then
            setColor(menu.colors.scrollbarThumbHover)
        else
            setColor(menu.colors.scrollbarThumb)
        end
        draw.FilledRect(scrollbarX, thumbY, scrollbarX + scrollbarWidth, math.floor(thumbY + thumbHeight))
        
        -- Handle scrollbar interaction
        if input.IsButtonDown(MOUSE_LEFT) then
            local isOverScrollbar = isInBounds(scrollbarX, y, scrollbarX + scrollbarWidth, y + visibleHeight)
            local mouseY = select(2, getMousePos())
            
            if isOverScrollbar and not menu._mouseState.isDraggingScrollbar then
                menu._state.activeWidget = widget
                menu._mouseState.isDraggingScrollbar = true
                menu._mouseState.eventHandled = true
            end
            
            if menu._mouseState.isDraggingScrollbar and menu._state.activeWidget == widget then
                -- Calculate new scroll position based on mouse position
                local relativeY = math.max(0, math.min(mouseY - y, visibleHeight))
                local newScrollRatio = relativeY / visibleHeight
                widget.state.scrollOffset = math.floor(newScrollRatio * maxOffset)
                -- Clamp the scroll offset
                widget.state.scrollOffset = math.max(0, math.min(widget.state.scrollOffset, maxOffset))
            end
        elseif menu._mouseState.isDraggingScrollbar and menu._state.activeWidget == widget then
            menu._mouseState.isDraggingScrollbar = false
            menu._state.activeWidget = nil
        end
    end
    
    return visibleHeight
end

-- Add TabPanel creation method to Window
function Window:renderTabPanel()
    if not self._tabPanel then
        self._tabPanel = TabPanel.new({}, self)
    end
    return self._tabPanel
end

function Window:render()
    if not self.isOpen then return end
    
    self.height = math.floor(self:calculateHeight())
    
    local skipProcessing = self:_updateMouseState()
    if skipProcessing then return end

    if menu._mouseState.isDragging then
        if input.IsButtonDown(MOUSE_LEFT) and self.clickStartedInTitleBar then
            local mouseX, mouseY = getMousePos()
            self.x = math.floor(mouseX - menu._mouseState.dragOffsetX)
            self.y = math.floor(mouseY - menu._mouseState.dragOffsetY)
        else
            menu._mouseState.isDragging = false
            self.interactionState = 'none'
            self.clickStartedInTitleBar = false
        end
    elseif self.clickStartedInTitleBar and not menu._mouseState.isDragging and 
           input.IsButtonDown(MOUSE_LEFT) then
        local mouseX, mouseY = getMousePos()
        menu._mouseState.dragOffsetX = math.floor(mouseX - self.x)
        menu._mouseState.dragOffsetY = math.floor(mouseY - self.y)
        menu._mouseState.isDragging = true
        self.interactionState = 'dragging'
    end

    -- Draw window frame
    setColor(menu.colors.border)
    draw.OutlinedRect(
        math.floor(self.x - 1),
        math.floor(self.y - 1),
        math.floor(self.x + self.width + 1),
        math.floor(self.y + self.height + 1)
    )
    
    setColor(menu.colors.windowBg)
    draw.FilledRect(
        math.floor(self.x),
        math.floor(self.y),
        math.floor(self.x + self.width),
        math.floor(self.y + self.height)
    )
    
    -- Draw title bar
    setColor(menu.colors.titleBarBg)
    draw.FilledRect(
        math.floor(self.x),
        math.floor(self.y),
        math.floor(self.x + self.width),
        math.floor(self.y + self.titleBarHeight)
    )
    
    setColor(menu.colors.titleText)
    draw.Text(
        math.floor(self.x + 10),
        math.floor(self.y + 8),
        self.title
    )
    
    if self:_handleCloseButton() then return end
    
    local currentY = math.floor(self.y + self.titleBarHeight)
    
    -- Render tab panel if exists
    if self._tabPanel and #self._tabPanel.tabOrder > 0 then
        currentY = currentY + self._tabPanel:render(menu, self.x, currentY)
    end
    
    -- Initialize first tab if not done yet
    if self._tabPanel and not self._tabPanel.initialized and self._tabPanel.currentTab then
        self._tabPanel.initialized = true
        if self._tabPanel.tabs[self._tabPanel.currentTab] then
            self._tabPanel.tabs[self._tabPanel.currentTab]()
        end
    end
    
    -- Render widgets
    for _, widget in ipairs(self.widgets) do
        local baseX = math.floor(self.x + 10)
        if widget.type == 'button' then
            currentY = currentY + self:renderButton(widget, baseX, currentY)
        elseif widget.type == 'checkbox' then
            currentY = currentY + self:renderCheckbox(widget, baseX, currentY)
        elseif widget.type == 'slider' then
            currentY = currentY + self:renderSlider(widget, baseX, currentY)
        elseif widget.type == 'progress' then
            currentY = currentY + self:renderProgressBar(widget, baseX, currentY)
        elseif widget.type == 'combo' then
            currentY = currentY + self:renderComboBox(widget, baseX, currentY)
        elseif widget.type == 'list' then
            currentY = currentY + self:renderList(widget, baseX, currentY)
        end
        currentY = math.floor(currentY + 5)
    end
end

-- Public API functions
function menu.createWindow(title, config)
    if type(config) ~= "table" then config = {} end
    return Window.new(title, config)
end

function menu.closeAll()
    for _, window in ipairs(menu._state.windows) do
        if window.isOpen then
            window.isOpen = false
            if window.onClose then window.onClose() end
        end
    end
    menu._state.activeWindow = nil
    menu._state.activeWidget = nil
    menu._mouseState.activeDropdown = nil
end

function menu.isAnyWindowOpen()
    for _, window in ipairs(menu._state.windows) do
        if window.isOpen then return true end
    end
    return false
end

-- Font management
local function updateFont()
    local currentFont = gui.GetValue("font")
    if currentFont ~= menu._state.lastFontSetting then
        menu._state.menuFont = draw.CreateFont(currentFont, 14, 400)
        menu._state.lastFontSetting = currentFont
    end
    draw.SetFont(menu._state.menuFont)
end

-- Handle UI Scale
local originalScaleFactor = client.GetConVar("vgui_ui_scale_factor")
if originalScaleFactor ~= 1 then
    client.SetConVar("vgui_ui_scale_factor", "1")
end

-- Main draw callback
callbacks.Register("Draw", function()
    updateFont()

    -- Store current UI state
    local isGameUIVisible = engine.IsGameUIVisible()
    local isConsoleVisible = engine.Con_IsVisible()
    
    -- Check if any window is open
    local anyWindowOpen = menu.isAnyWindowOpen()
    
    if anyWindowOpen then
        -- Block game input when menu is open
        input.SetMouseInputEnabled("false")
        
        -- Handle console visibility
        if isConsoleVisible then
            menu._state.wasConsoleOpen = true
            client.Command("hideconsole", true)
        end
    else
        -- Restore console if it was previously open and enable input
        input.SetMouseInputEnabled()

        if menu._state.wasConsoleOpen and isGameUIVisible then
            client.Command("showconsole", true)
            menu._state.wasConsoleOpen = false
        end
    end
    
    -- Only render if we have windows open
    if anyWindowOpen then
        -- Reset event handled state at the start of each frame
        menu._mouseState.eventHandled = false
        
        -- Sort windows by z-index before rendering
        table.sort(menu._state.windows, function(a, b)
            return a.zIndex < b.zIndex
        end)
        
        -- Render windows from back to front
        for i = #menu._state.windows, 1, -1 do
            local window = menu._state.windows[i]
            if window.isOpen then
                window:render()
            end
        end
    end
end)

-- Cleanup on unload
callbacks.Register("Unload", function()
    input.SetMouseInputEnabled()
    
    if originalScaleFactor ~= 1 then
        client.SetConVar("vgui_ui_scale_factor", tostring(originalScaleFactor))
    end
    
    menu.closeAll()
    menu._state.windows = {}
end)

return menu

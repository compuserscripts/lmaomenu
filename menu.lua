--[[
    LmaoMenu - A flexible menu library for Lmaobox Lua scripts
    Based on Config Browser by n0x
]]

local menu = {
    -- Constants
    SCROLL_DELAY = 0.08,
    CHECK_INTERVAL = 5,

    -- Global mouse state (crucial for proper interaction)
    _mouseState = {
        lastState = false,
        released = false,
        isDragging = false,
        dragOffsetX = 0,
        dragOffsetY = 0,
        isDraggingScrollbar = false,
        wasScrollbarDragging = false,
        hasSeenMousePress = false,
        lastScrollTime = 0
    },

    -- Global menu state
    _state = {
        windows = {},
        activeWindow = nil,
        menuFont = nil,
        lastFontSetting = nil,
        wasConsoleOpen = false
    },

    -- Theme colors
    colors = {
        windowBg = {20, 20, 20, 255},
        titleBarBg = {30, 30, 30, 255},
        titleText = {255, 255, 255, 255},
        border = {50, 50, 50, 255},
        itemBg = {25, 25, 25, 255},
        itemHoverBg = {40, 40, 40, 255},
        close = {255, 255, 255, 255},
        closeHover = {255, 100, 100, 255},
        scrollbarBg = {40, 40, 40, 255},
        scrollbarHoverBg = {50, 50, 50, 255},
        scrollbarThumb = {80, 80, 80, 255},
        scrollbarThumbHover = {100, 100, 100, 255},
        scrollbarThumbActive = {120, 120, 120, 255}
    }
}

-- Helper functions
local function getMousePos()
    local mousePos = input.GetMousePos()
    return tonumber(mousePos[1]) or 0, tonumber(mousePos[2]) or 0
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
    local padding = 20 -- 10px padding on each side
    local scrollbarWidth = hasScrollbar and 16 or 0
    local actualMaxWidth = maxWidth - padding - scrollbarWidth
    
    if isHovered and extraText then
        local extraWidth = draw.GetTextSize(extraText)
        actualMaxWidth = actualMaxWidth - extraWidth
    end
    
    local fullWidth = draw.GetTextSize(text)
    if fullWidth <= actualMaxWidth then
        return text
    end
    
    -- Binary search for truncation point
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

-- Window class
local Window = {}
Window.__index = Window

function Window.new(title, config)
    local self = setmetatable({}, Window)
    
    -- Window properties
    self.title = title or "Window"
    self.x = tonumber(config.x) or 100
    self.y = tonumber(config.y) or 100
    self.width = tonumber(config.width) or 400
    self.desiredItems = tonumber(config.desiredItems) or 10
    self.titleBarHeight = tonumber(config.titleBarHeight) or 30
    self.itemHeight = tonumber(config.itemHeight) or 25
    self.footerHeight = tonumber(config.footerHeight) or 30
    
    -- State
    self.isOpen = false
    self.items = {}
    self.scrollOffset = 0
    self.interactionState = 'none'  -- none, dragging, scrolling, clicking
    self.clickStartedInWindow = false
    self.clickStartedInTitleBar = false
    self.clickStartedInScrollbar = false
    self.clickStartRegion = nil
    self.clickStartX = 0
    self.clickStartY = 0
    
    -- Content
    self.height = self:calculateHeight()
    
    -- Callbacks
    self.onClose = config.onClose
    self.onItemClick = config.onItemClick
    
    -- Add to global window list
    table.insert(menu._state.windows, self)
    
    return self
end

function Window:calculateHeight()
    local actualItems = math.min(self.desiredItems, #self.items)
    actualItems = math.max(actualItems, 1) -- Show at least one row
    return self.titleBarHeight + (actualItems * self.itemHeight) + self.footerHeight
end

function Window:addItem(item)
    if type(item) == "table" then
        table.insert(self.items, item)
        self.height = self:calculateHeight()
    end
end

function Window:clearItems()
    self.items = {}
    self.scrollOffset = 0
    self.height = self:calculateHeight()
end

function Window:_updateMouseState()
    local mouseState = input.IsButtonDown(MOUSE_LEFT)
    
    -- Handle new click
    if mouseState and not menu._mouseState.lastState then
        menu._mouseState.hasSeenPress = true
        
        -- Reset all states on new click
        self.clickStartedInWindow = false
        self.clickStartedInTitleBar = false
        self.clickStartedInScrollbar = false
        self.interactionState = 'none'
        
        local mX, mY = getMousePos()
        self.clickStartX = mX
        self.clickStartY = mY
        
        -- Check if click started in window
        if isInBounds(self.x, self.y, self.x + self.width, self.y + self.height) then
            self.clickStartedInWindow = true
            menu._state.activeWindow = self
            
            -- Track where click started
            if isInBounds(self.x, self.y, self.x + self.width, self.y + self.titleBarHeight) then
                self.clickStartedInTitleBar = true
                self.interactionState = 'dragging'
                self.clickStartRegion = 'titlebar'
                menu._mouseState.dragOffsetX = mX - self.x
                menu._mouseState.dragOffsetY = mY - self.y
            elseif isInBounds(self.x, self.y + self.height - self.footerHeight, 
                            self.x + self.width, self.y + self.height) then
                self.clickStartRegion = 'footer'
            elseif #self.items > 0 and isInBounds(
                self.x + self.width - 16,
                self.y + self.titleBarHeight,
                self.x + self.width,
                self.y + self.height - self.footerHeight
            ) then
                self.clickStartedInScrollbar = true
                self.interactionState = 'scrolling'
                self.clickStartRegion = 'scrollbar'
                menu._mouseState.isDraggingScrollbar = true
            else
                self.interactionState = 'clicking'
                self.clickStartRegion = 'content'
            end
        end
    end
    
    -- Update release state
    menu._mouseState.released = (menu._mouseState.lastState and not mouseState)
    menu._mouseState.lastState = mouseState
    
    -- Reset states on release
    if menu._mouseState.released then
        if menu._mouseState.isDraggingScrollbar then
            menu._mouseState.wasScrollbarDragging = false
            menu._mouseState.isDraggingScrollbar = false
            self.interactionState = 'none'
            self.clickStartRegion = nil
            return true
        end
        
        -- Important: Reset interaction state when releasing mouse
        menu._mouseState.isDragging = false
        self.clickStartedInTitleBar = false
        self.interactionState = 'none'
        self.clickStartRegion = nil
        menu._state.activeWindow = nil
    end
    
    return false
end

function Window:_handleCloseButton()
    local closeText = "×"
    local closeWidth = draw.GetTextSize(closeText)
    local closeX = self.x + self.width - closeWidth - 10
    local closeY = self.y + 8
    local closeButtonBounds = isInBounds(closeX - 5, closeY - 5, closeX + closeWidth + 5, closeY + 15)

    if closeButtonBounds and self.interactionState ~= 'dragging' then
        setColor(menu.colors.closeHover)
        if menu._mouseState.released and self.clickStartedInWindow and 
           (self.clickStartRegion == 'titlebar' or self.clickStartRegion == nil) then
            self.isOpen = false
            if self.onClose then self.onClose() end
            return true
        end
    else
        setColor(menu.colors.close)
    end
    draw.Text(closeX, closeY, closeText)
    return false
end

function Window:render()
    if not self.isOpen then return end
    
    -- Update window height based on content
    self.height = self:calculateHeight()
    
    -- Update mouse state and check if we should skip processing
    local skipProcessing = self:_updateMouseState()
    if skipProcessing then return end

    -- Handle dragging
    if menu._mouseState.isDragging then
        if input.IsButtonDown(MOUSE_LEFT) and self.clickStartedInTitleBar then
            local mouseX, mouseY = getMousePos()
            self.x = mouseX - menu._mouseState.dragOffsetX
            self.y = mouseY - menu._mouseState.dragOffsetY
        else
            menu._mouseState.isDragging = false
            self.interactionState = 'none'
            self.clickStartedInTitleBar = false
        end
    elseif self.clickStartedInTitleBar and not menu._mouseState.isDragging and 
           input.IsButtonDown(MOUSE_LEFT) then
        local mouseX, mouseY = getMousePos()
        menu._mouseState.dragOffsetX = mouseX - self.x
        menu._mouseState.dragOffsetY = mouseY - self.y
        menu._mouseState.isDragging = true
        self.interactionState = 'dragging'
    end

    -- Draw window frame
    setColor(menu.colors.border)
    draw.OutlinedRect(self.x - 1, self.y - 1, self.x + self.width + 1, self.y + self.height + 1)
    
    -- Draw background
    setColor(menu.colors.windowBg)
    draw.FilledRect(self.x, self.y, self.x + self.width, self.y + self.height)
    
    -- Draw title bar
    setColor(menu.colors.titleBarBg)
    draw.FilledRect(self.x, self.y, self.x + self.width, self.y + self.titleBarHeight)
    
    -- Draw title
    setColor(menu.colors.titleText)
    draw.Text(self.x + 10, self.y + 8, self.title)
    
    -- Handle close button
    if self:_handleCloseButton() then return end
    
    -- Calculate content area
    local contentY = self.y + self.titleBarHeight
    local contentEnd = self.y + self.height - self.footerHeight
    local contentHeight = contentEnd - contentY
    local visibleItems = math.floor(contentHeight / self.itemHeight)
    local maxScroll = math.max(0, #self.items - visibleItems)
    self.scrollOffset = math.min(self.scrollOffset, maxScroll)
    
    -- Handle scrolling
    if self.interactionState ~= 'dragging' and isInBounds(
        self.x, contentY,
        self.x + self.width, contentEnd
    ) then
        local currentTime = globals.RealTime()
        if currentTime - menu._mouseState.lastScrollTime >= menu.SCROLL_DELAY then
            if input.IsButtonPressed(MOUSE_WHEEL_UP) and self.scrollOffset > 0 then
                self.scrollOffset = self.scrollOffset - 1
                menu._mouseState.lastScrollTime = currentTime
            elseif input.IsButtonPressed(MOUSE_WHEEL_DOWN) and self.scrollOffset < maxScroll then
                self.scrollOffset = self.scrollOffset + 1
                menu._mouseState.lastScrollTime = currentTime
            end
        end
    end
    
    -- Draw items
    local hasScrollbar = #self.items > visibleItems
    for i = 1, visibleItems do
        local itemIndex = i + self.scrollOffset
        local item = self.items[itemIndex]
        if item then
            local itemY = contentY + (i-1) * self.itemHeight
            
            -- Only render if not overlapping footer
            if itemY + self.itemHeight <= contentEnd then
                -- Item hover check
                local isHovered = isInBounds(
                    self.x, itemY,
                    self.x + self.width - (hasScrollbar and 16 or 0),
                    itemY + self.itemHeight
                ) and self.interactionState ~= 'dragging' and
                    self.interactionState ~= 'scrolling'
                
                -- Draw background
                if isHovered then
                    setColor(menu.colors.itemHoverBg)
                else
                    setColor(menu.colors.itemBg)
                end
                draw.FilledRect(self.x, itemY,
                              self.x + self.width - (hasScrollbar and 16 or 0),
                              itemY + self.itemHeight)
                
                -- Draw text
                setColor(menu.colors.titleText)
                local extraText = isHovered and (item.extraText or "") or nil
                local text = truncateText(item.text, self.width, hasScrollbar, isHovered, extraText)
                draw.Text(self.x + 10, itemY + 5, text)
                
                -- Draw extra text on hover
                if isHovered and item.extraText then
                    local textWidth = draw.GetTextSize(text)
                    draw.Text(self.x + 10 + textWidth, itemY + 5, item.extraText)
                end
                
                -- Handle clicks
                if isHovered and menu._mouseState.released and 
                   self.clickStartedInWindow and self.clickStartRegion == 'content' then
                    if self.onItemClick then
                        self.onItemClick(itemIndex)
                    end
                end
            end
        end
    end
    
    -- Draw scrollbar if needed
    if hasScrollbar then
        local thumbHeight = math.max(20, (visibleItems / #self.items) * contentHeight)
        local thumbPos = contentY + (self.scrollOffset / (#self.items - visibleItems)) * 
                        (contentHeight - thumbHeight)
        
        -- Draw scrollbar background
        setColor(menu.colors.scrollbarBg)
        draw.FilledRect(
            self.x + self.width - 16,
            contentY,
            self.x + self.width,
            contentEnd
        )
        
        -- Draw thumb
        if menu._mouseState.isDraggingScrollbar then
            setColor(menu.colors.scrollbarThumbActive)
        elseif isInBounds(
            self.x + self.width - 16,
            thumbPos,
            self.x + self.width,
            thumbPos + thumbHeight
        ) then
            setColor(menu.colors.scrollbarThumbHover)
        else
            setColor(menu.colors.scrollbarThumb)
        end
        
        draw.FilledRect(
            self.x + self.width - 16,
            thumbPos,
            self.x + self.width,
            thumbPos + thumbHeight
        )
        
        -- Handle scrollbar dragging
        if self.interactionState == 'scrolling' then
            if input.IsButtonDown(MOUSE_LEFT) then
                local mouseY = getMousePos()[2]
                local scrollableHeight = contentHeight - thumbHeight
                local relativeY = math.max(0, math.min(mouseY - contentY - thumbHeight/2, scrollableHeight))
                self.scrollOffset = math.floor((relativeY / scrollableHeight) * (#self.items - visibleItems))
                menu._mouseState.isDraggingScrollbar = true
                menu._mouseState.wasScrollbarDragging = true
            else
                menu._mouseState.isDraggingScrollbar = false
                self.interactionState = 'none'
                menu._mouseState.released = false
            end
        elseif self.clickStartedInScrollbar and not menu._mouseState.isDraggingScrollbar and 
               input.IsButtonDown(MOUSE_LEFT) then
            menu._mouseState.isDraggingScrollbar = true
            self.interactionState = 'scrolling'
            menu._mouseState.wasScrollbarDragging = true
        end
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
    -- Update font
    updateFont()
    
    -- Handle mouse input and console state
    local anyWindowOpen = menu.isAnyWindowOpen()
    
    if anyWindowOpen then
        -- Disable mouse input for game
        input.SetMouseInputEnabled(false)
        
        -- Hide console if it's open
        if engine.Con_IsVisible() then
            menu._state.wasConsoleOpen = true
            client.Command("hideconsole", true)
        end
    else
        -- Enable mouse input for game
        input.SetMouseInputEnabled(true)
        
        -- Restore console if needed
        if menu._state.wasConsoleOpen and engine.IsGameUIVisible() then
            client.Command("showconsole", true)
            menu._state.wasConsoleOpen = false
        end
    end
    
    -- Render all windows in reverse order (for proper z-order)
    if anyWindowOpen then
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
    -- Re-enable mouse input
    input.SetMouseInputEnabled(true)
    
    -- Restore UI scale if needed
    if originalScaleFactor ~= 1 then
        client.SetConVar("vgui_ui_scale_factor", tostring(originalScaleFactor))
    end
    
    -- Close all windows
    menu.closeAll()
    
    -- Clear window list
    menu._state.windows = {}
end)

return menu

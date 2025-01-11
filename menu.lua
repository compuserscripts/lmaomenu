--[[
    LmaoMenu - A flexible menu library for Lmaobox Lua scripts
    Based on Config Browser by n0x
]]

-- Menu library main table
local menu = {
    -- Constants
    SCROLL_DELAY = 0.08,
    CHECK_INTERVAL = 5,

    -- Private state
    _state = {
        windows = {},  -- Table to hold all window instances
        mouseState = {
            lastState = false,
            released = false,
            isDragging = false,
            dragOffsetX = 0,
            dragOffsetY = 0,
            isDraggingScrollbar = false,
            wasScrollbarDragging = false,
            hasSeenMousePress = false,
            lastKeyState = false,
            lastScrollTime = 0
        },
        menuFont = nil,
        lastFontSetting = nil,
        originalScaleFactor = client.GetConVar("vgui_ui_scale_factor"),
    },

    -- Colors
    colors = {
        windowBg = {20, 20, 20, 255},
        titleBarBg = {30, 30, 30, 255},
        titleText = {255, 255, 255, 255},
        border = {50, 50, 50, 255},
        itemBg = {25, 25, 25, 255},
        itemHoverBg = {40, 40, 40, 255},
        scrollbarBg = {40, 40, 40, 255},
        scrollbarHoverBg = {50, 50, 50, 255},
        scrollbarThumb = {80, 80, 80, 255},
        scrollbarThumbHover = {100, 100, 100, 255},
        scrollbarThumbActive = {120, 120, 120, 255},
        close = {255, 255, 255, 255},
        closeHover = {255, 100, 100, 255}
    }
}

-- Helper functions
local function setColor(color)
    if type(color) == "table" and #color >= 4 then
        draw.Color(color[1], color[2], color[3], color[4])
    end
end

local function getMousePosition()
    local mousePosX, mousePosY = input.GetMousePos()
    mousePosX = tonumber(mousePosX) or 0
    mousePosY = tonumber(mousePosY) or 0
    return mousePosX, mousePosY
end

-- Window class
local Window = {}
Window.__index = Window

function Window.new(title, config)
    local self = setmetatable({}, Window)
    
    -- Window properties with defaults
    self.title = tostring(title or "Window")
    self.x = tonumber(config.x) or 100
    self.y = tonumber(config.y) or 100
    self.width = tonumber(config.width) or 400
    self.height = tonumber(config.height) or 300
    self.minWidth = tonumber(config.minWidth) or 200
    self.minHeight = tonumber(config.minHeight) or 100
    self.titleBarHeight = tonumber(config.titleBarHeight) or 30
    self.itemHeight = tonumber(config.itemHeight) or 25
    self.footerHeight = tonumber(config.footerHeight) or 30
    
    -- State
    self.isOpen = false
    self.items = {}
    self.scrollOffset = 0
    self.interactionState = 'none'
    self.clickStartRegion = nil
    self.clickStartedInMenu = false
    self.clickStartedInTitleBar = false
    self.clickStartedInScrollbar = false
    self.visibleItemCount = 0

    -- Callbacks
    self.onClose = type(config.onClose) == "function" and config.onClose or nil
    self.onItemClick = type(config.onItemClick) == "function" and config.onItemClick or nil
    
    return self
end

function Window:addItem(item)
    if type(item) == "table" then
        table.insert(self.items, item)
    end
end

function Window:clearItems()
    self.items = {}
    self.scrollOffset = 0
end

function Window:_isPointInRegion(x, y, left, top, right, bottom)
    if type(x) ~= "number" or type(y) ~= "number" then return false end
    if type(left) ~= "number" or type(top) ~= "number" or 
       type(right) ~= "number" or type(bottom) ~= "number" then return false end
       
    return x >= left and x <= right and y >= top and y <= bottom
end

function Window:_isPointInWindow(x, y)
    return self:_isPointInRegion(x, y, self.x, self.y, self.x + self.width, self.y + self.height)
end

function Window:_isPointInTitleBar(x, y)
    return self:_isPointInRegion(x, y, self.x, self.y, self.x + self.width, self.y + self.titleBarHeight)
end

function Window:_isPointInFooter(x, y)
    return self:_isPointInRegion(x, y, self.x, self.y + self.height - self.footerHeight, 
                                self.x + self.width, self.y + self.height)
end

function Window:_isPointInScrollbar(x, y)
    if not self.items or type(self.items) ~= "table" then return false end
    
    local visItemCount = self:_getVisibleItemCount()
    if visItemCount >= #self.items then return false end
    
    return self:_isPointInRegion(x, y, self.x + self.width - 16, self.y + self.titleBarHeight,
                                self.x + self.width, self.y + self.height - self.footerHeight)
end

function Window:_isPointInItemBounds(itemIndex)
    local mouseX, mouseY = input.GetMousePos()
    if type(mouseX) ~= "number" or type(mouseY) ~= "number" then return false end
    if type(itemIndex) ~= "number" then return false end

    -- Calculate item position
    local itemStartY = self.y + self.titleBarHeight + ((itemIndex - self.scrollOffset - 1) * self.itemHeight)
    local itemEndY = itemStartY + self.itemHeight

    local visItemCount = self:_getVisibleItemCount()
    local hasScrollbar = self.items and type(self.items) == "table" and #self.items > visItemCount
    
    -- Check if point is within item bounds
    return mouseX >= self.x and 
           mouseX <= self.x + self.width - (hasScrollbar and 16 or 0) and
           mouseY >= itemStartY and 
           mouseY < itemEndY
end

function Window:_getVisibleItemCount()
    local contentHeight = self.height - self.titleBarHeight - self.footerHeight
    self.visibleItemCount = math.floor(contentHeight / self.itemHeight)
    return self.visibleItemCount
end

function Window:_updateMouseState()
    local mouseState = input.IsButtonDown(MOUSE_LEFT)
    
    -- Handle new click
    if mouseState and not menu._state.mouseState.lastState then
        menu._state.mouseState.hasSeenMousePress = true
        
        -- Reset all states on new click
        self.clickStartedInMenu = false
        self.clickStartedInTitleBar = false
        self.clickStartedInScrollbar = false
        self.interactionState = 'none'
        
        local mouseX, mouseY = input.GetMousePos()
        self.clickStartX = mouseX
        self.clickStartY = mouseY
        
        -- Check if click started in menu
        if self:_isPointInWindow(mouseX, mouseY) then
            self.clickStartedInMenu = true
            
            -- Track where click started
            if self:_isPointInTitleBar(mouseX, mouseY) then
                self.clickStartedInTitleBar = true
                self.interactionState = 'dragging'
                self.clickStartRegion = 'titlebar'
            elseif self:_isPointInFooter(mouseX, mouseY) then
                self.clickStartRegion = 'footer'
            elseif self:_isPointInScrollbar(mouseX, mouseY) then
                self.clickStartedInScrollbar = true
                menu._state.mouseState.isDraggingScrollbar = true
                self.interactionState = 'scrolling'
                self.clickStartRegion = 'scrollbar'
            else
                -- Check for item click
                local relativeY = mouseY - (self.y + self.titleBarHeight)
                local clickedIndex = math.floor(relativeY / self.itemHeight) + self.scrollOffset + 1
                
                if clickedIndex > 0 and clickedIndex <= #self.items then
                    self.interactionState = 'clicking'
                    self.clickStartRegion = 'list'
                    self.clickedItemIndex = clickedIndex
                end
            end
        end
    end
    
    -- Update release state
    menu._state.mouseState.released = (menu._state.mouseState.lastState and not mouseState)
    menu._state.mouseState.lastState = mouseState
    
    -- Handle mouse release
    if menu._state.mouseState.released then
        -- Handle item click
        if self.interactionState == 'clicking' and self.clickedItemIndex and
           self.onItemClick and self:_isPointInItemBounds(self.clickedItemIndex) then
            self.onItemClick(self.clickedItemIndex)
        end

        -- Reset states
        if menu._state.mouseState.isDraggingScrollbar then
            menu._state.mouseState.wasScrollbarDragging = false
            menu._state.mouseState.isDraggingScrollbar = false
        end
        
        menu._state.mouseState.isDragging = false
        self.clickStartedInTitleBar = false
        self.interactionState = 'none'
        self.clickStartRegion = nil
        self.clickedItemIndex = nil
    end
end

function Window:_handleDragging()
    if menu._state.mouseState.isDragging then
        if input.IsButtonDown(MOUSE_LEFT) and self.clickStartedInTitleBar then
            local mousePosX, mousePosY = getMousePosition()
            self.x = mousePosX - menu._state.mouseState.dragOffsetX
            self.y = mousePosY - menu._state.mouseState.dragOffsetY
        else
            menu._state.mouseState.isDragging = false
            self.interactionState = 'none'
            self.clickStartedInTitleBar = false
        end
    elseif self.clickStartedInTitleBar and not menu._state.mouseState.isDragging and 
           input.IsButtonDown(MOUSE_LEFT) then
        local mousePosX, mousePosY = getMousePosition()
        menu._state.mouseState.dragOffsetX = mousePosX - self.x
        menu._state.mouseState.dragOffsetY = mousePosY - self.y
        menu._state.mouseState.isDragging = true
        self.interactionState = 'dragging'
    end
end

function Window:_handleScrolling()
    if menu._state.mouseState.isDraggingScrollbar then
        local _, mousePosY = getMousePosition()
        local visibleItems = self:_getVisibleItemCount()
        local maxScroll = #self.items - visibleItems
        
        if maxScroll > 0 then
            local contentHeight = self.height - self.titleBarHeight - self.footerHeight
            local relativeY = math.max(0, math.min(contentHeight, mousePosY - (self.y + self.titleBarHeight)))
            local scrollProgress = relativeY / contentHeight
            self.scrollOffset = math.floor(scrollProgress * maxScroll + 0.5)
        end
    end
end

function Window:_drawTitleBar()
    -- Background
    setColor(menu.colors.titleBarBg)
    draw.FilledRect(self.x, self.y, self.x + self.width, self.y + self.titleBarHeight)
    
    -- Title
    setColor(menu.colors.titleText)
    draw.Text(self.x + 10, self.y + 8, self.title)
    
    -- Close button
    local closeText = "×"
    local closeWidth = draw.GetTextSize(closeText)
    local closeX = self.x + self.width - closeWidth - 10
    local closeY = self.y + 8
    
    local mousePosX, mousePosY = getMousePosition()
    if self:_isPointInRegion(mousePosX, mousePosY, closeX - 5, closeY - 5, 
                            closeX + closeWidth + 5, closeY + closeWidth + 5) and
       self.interactionState ~= 'dragging' and 
       self.interactionState ~= 'scrolling' then
        setColor(menu.colors.closeHover)
        
        -- Handle close button click
        if input.IsButtonPressed(MOUSE_LEFT) then
            self.isOpen = false
            if self.onClose then self.onClose() end
        end
    else
        setColor(menu.colors.close)
    end
    draw.Text(closeX, closeY, closeText)
end

function Window:_drawItems()
    if not self.items or type(self.items) ~= "table" then return end
    
    local visibleItems = self:_getVisibleItemCount()
    local contentStart = self.y + self.titleBarHeight
    
    for i = 1, visibleItems do
        local itemIndex = i + self.scrollOffset
        if itemIndex > 0 and itemIndex <= #self.items then
            local item = self.items[itemIndex]
            if item and type(item) == "table" then
                local itemY = contentStart + (i-1) * self.itemHeight
                local hasScrollbar = #self.items > visibleItems
                
                -- Background highlight for hover or clicked item
                if self.clickedItemIndex == itemIndex and self.interactionState == 'clicking' then
                    setColor(menu.colors.itemHoverBg)  -- Use hover color for clicked item
                elseif self:_isPointInItemBounds(itemIndex) then
                    setColor(menu.colors.itemHoverBg)
                else
                    setColor(menu.colors.itemBg)
                end
                
                -- Draw item background
                draw.FilledRect(self.x + 1, itemY, 
                              self.x + self.width - (hasScrollbar and 16 or 0) - 1, 
                              itemY + self.itemHeight - 1)
                
                -- Draw item text
                if type(item.text) == "string" then
                    setColor(menu.colors.titleText)
                    draw.Text(self.x + 10, itemY + 5, item.text)
                end
            end
        end
    end
end

function Window:_drawScrollbar()
    if not self.items or type(self.items) ~= "table" then return end
    
    local visItemCount = self:_getVisibleItemCount()
    if #self.items <= visItemCount then return end
    
    local contentHeight = self.height - self.titleBarHeight - self.footerHeight
    local scrollbarWidth = 16
    local thumbHeight = math.max(20, (visItemCount / #self.items) * contentHeight)
    
    -- Calculate thumb position
    local maxScroll = #self.items - visItemCount
    if maxScroll > 0 then
        local scrollProgress = self.scrollOffset / maxScroll
        local thumbPosition = scrollProgress * (contentHeight - thumbHeight)
        
        -- Draw track
        setColor(menu.colors.scrollbarBg)
        draw.FilledRect(
            self.x + self.width - scrollbarWidth,
            self.y + self.titleBarHeight,
            self.x + self.width,
            self.y + self.height - self.footerHeight
        )
        
        -- Draw thumb
        local mousePosX, mousePosY = getMousePosition()
        if menu._state.mouseState.isDraggingScrollbar then
            setColor(menu.colors.scrollbarThumbActive)
        elseif self:_isPointInScrollbar(mousePosX, mousePosY) then
            setColor(menu.colors.scrollbarThumbHover)
        else
            setColor(menu.colors.scrollbarThumb)
        end
        
        draw.FilledRect(
            self.x + self.width - scrollbarWidth,
            self.y + self.titleBarHeight + thumbPosition,
            self.x + self.width,
            self.y + self.titleBarHeight + thumbPosition + thumbHeight
        )
    end
end

function Window:render()
    if not self.isOpen then return end
    
    -- Update mouse state
    self:_updateMouseState()
    
    -- Handle dragging & scrolling
    self:_handleDragging()
    if menu._state.mouseState.isDraggingScrollbar then
        self:_handleScrolling()
    end
    
    -- Draw window frame
    setColor(menu.colors.border)
    draw.OutlinedRect(self.x - 1, self.y - 1, self.x + self.width + 1, self.y + self.height + 1)
    
    -- Draw window background
    setColor(menu.colors.windowBg)
    draw.FilledRect(self.x, self.y, self.x + self.width, self.y + self.height)
    
    -- Draw components
    self:_drawTitleBar()
    self:_drawItems()
    self:_drawScrollbar()
end

-- Public API
function menu.createWindow(title, config)
    if type(config) ~= "table" then config = {} end
    local window = Window.new(title, config)
    table.insert(menu._state.windows, window)
    return window
end

function menu.isAnyWindowOpen()
    for _, window in ipairs(menu._state.windows) do
        if window.isOpen then
            return true
        end
    end
    return false
end

-- Main draw callback handler
callbacks.Register("Draw", function()
    -- Update font if needed
    local currentFont = gui.GetValue("font")
    if currentFont ~= menu._state.lastFontSetting then
        menu._state.menuFont = draw.CreateFont(currentFont, 14, 400)
        menu._state.lastFontSetting = currentFont
    end
    draw.SetFont(menu._state.menuFont)
    
    -- Render all windows
    for _, window in ipairs(menu._state.windows) do
        if window.isOpen then
            window:render()
        end
    end
end)

-- Register cleanup for script unload
callbacks.Register("Unload", function()
    -- Restore original UI scale factor if it was changed
    if menu._state.originalScaleFactor ~= 1 then
        client.SetConVar("vgui_ui_scale_factor", tostring(menu._state.originalScaleFactor))
    end
    
    -- Clear all windows
    menu._state.windows = {}
end)

return menu

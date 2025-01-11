--[[
    LmaoMenu - A flexible menu library for Lmaobox Lua scripts
    Based on Config Browser by n0x
]]

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

-- Window class
local Window = {}
Window.__index = Window

function Window.new(title, config)
    local self = setmetatable({}, Window)
    
    -- Window properties with defaults
    self.title = title
    self.x = config.x or 100
    self.y = config.y or 100
    self.width = config.width or 400
    self.height = config.height or 300
    self.minWidth = config.minWidth or 200
    self.minHeight = config.minHeight or 100
    self.titleBarHeight = config.titleBarHeight or 30
    self.itemHeight = config.itemHeight or 25
    self.footerHeight = config.footerHeight or 30
    
    -- State
    self.isOpen = false
    self.items = {}
    self.scrollOffset = 0
    self.interactionState = 'none'
    self.clickStartRegion = nil
    self.clickStartedInMenu = false
    self.clickStartedInTitleBar = false
    self.clickStartedInScrollbar = false

    -- Callbacks
    self.onClose = config.onClose
    self.onItemClick = config.onItemClick
    
    return self
end

function Window:addItem(item)
    table.insert(self.items, item)
end

function Window:clearItems()
    self.items = {}
    self.scrollOffset = 0
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
        
        local mX, mY = input.GetMousePos()
        self.clickStartX = mX
        self.clickStartY = mY
        
        -- Check if click started in menu
        if self:_isPointInWindow(mX, mY) then
            self.clickStartedInMenu = true
            
            -- Track where click started
            if self:_isPointInTitleBar(mX, mY) then
                self.clickStartedInTitleBar = true
                self.interactionState = 'dragging'
                self.clickStartRegion = 'titlebar'
            elseif self:_isPointInFooter(mX, mY) then
                self.clickStartRegion = 'footer'
            elseif self:_isPointInScrollbar(mX, mY) then
                self.clickStartedInScrollbar = true
                self.interactionState = 'scrolling'
                self.clickStartRegion = 'scrollbar'
            else
                self.interactionState = 'clicking'
                self.clickStartRegion = 'list'
            end
        end
    end
    
    -- Update release state
    menu._state.mouseState.released = (menu._state.mouseState.lastState and not mouseState)
    menu._state.mouseState.lastState = mouseState
    
    -- Reset states on release
    if menu._state.mouseState.released then
        if menu._state.mouseState.isDraggingScrollbar then
            menu._state.mouseState.wasScrollbarDragging = false
            menu._state.mouseState.isDraggingScrollbar = false
            self.interactionState = 'none'
            self.clickStartRegion = nil
            return true
        end
        
        menu._state.mouseState.isDragging = false
        self.clickStartedInTitleBar = false
        self.interactionState = 'none'
    end
    
    return false
end

function Window:_isPointInWindow(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.height
end

function Window:_isPointInTitleBar(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y and y <= self.y + self.titleBarHeight
end

function Window:_isPointInFooter(x, y)
    return x >= self.x and x <= self.x + self.width and
           y >= self.y + self.height - self.footerHeight and y <= self.y + self.height
end

function Window:_isPointInScrollbar(x, y)
    local hasScrollbar = #self.items > self:_getVisibleItemCount()
    if not hasScrollbar then return false end
    
    return x >= self.x + self.width - 16 and x <= self.x + self.width and
           y >= self.y + self.titleBarHeight and y <= self.y + self.height - self.footerHeight
end

function Window:_getVisibleItemCount()
    local contentHeight = self.height - self.titleBarHeight - self.footerHeight
    return math.floor(contentHeight / self.itemHeight)
end

function Window:_handleDragging()
    if menu._state.mouseState.isDragging then
        if input.IsButtonDown(MOUSE_LEFT) and self.clickStartedInTitleBar then
            local mouseX, mouseY = input.GetMousePos()
            self.x = mouseX - menu._state.mouseState.dragOffsetX
            self.y = mouseY - menu._state.mouseState.dragOffsetY
        else
            menu._state.mouseState.isDragging = false
            self.interactionState = 'none'
            self.clickStartedInTitleBar = false
        end
    elseif self.clickStartedInTitleBar and not menu._state.mouseState.isDragging and input.IsButtonDown(MOUSE_LEFT) then
        local mouseX, mouseY = input.GetMousePos()
        menu._state.mouseState.dragOffsetX = mouseX - self.x
        menu._state.mouseState.dragOffsetY = mouseY - self.y
        menu._state.mouseState.isDragging = true
        self.interactionState = 'dragging'
    end
end

function Window:_drawTitleBar()
    -- Background
    draw.Color(unpack(menu.colors.titleBarBg))
    draw.FilledRect(self.x, self.y, self.x + self.width, self.y + self.titleBarHeight)
    
    -- Title
    draw.Color(unpack(menu.colors.titleText))
    draw.Text(self.x + 10, self.y + 8, self.title)
    
    -- Close button
    local closeText = "×"
    local closeWidth = draw.GetTextSize(closeText)
    local closeX = self.x + self.width - closeWidth - 10
    local closeY = self.y + 8
    
    if self:_isPointInWindow(input.GetMousePos()) and 
       self.interactionState ~= 'dragging' and 
       self.interactionState ~= 'scrolling' then
        draw.Color(unpack(menu.colors.closeHover))
    else
        draw.Color(unpack(menu.colors.close))
    end
    draw.Text(closeX, closeY, closeText)
end

function Window:_drawItems()
    local visibleItems = self:_getVisibleItemCount()
    local contentStart = self.y + self.titleBarHeight
    
    for i = 1, visibleItems do
        local itemIndex = i + self.scrollOffset
        local item = self.items[itemIndex]
        if item then
            local itemY = contentStart + (i-1) * self.itemHeight
            local hasScrollbar = #self.items > visibleItems
            
            -- Background
            if self:_isPointInItemBounds(itemIndex) then
                draw.Color(unpack(menu.colors.itemHoverBg))
            else
                draw.Color(unpack(menu.colors.itemBg))
            end
            draw.FilledRect(self.x + 1, itemY, 
                          self.x + self.width - (hasScrollbar and 16 or 0) - 1, 
                          itemY + self.itemHeight - 1)
            
            -- Text
            draw.Color(unpack(menu.colors.titleText))
            draw.Text(self.x + 10, itemY + 5, item.text)
        end
    end
end

function Window:_isPointInItemBounds(itemIndex)
    local mouseX, mouseY = input.GetMousePos()
    local itemY = self.y + self.titleBarHeight + ((itemIndex - self.scrollOffset - 1) * self.itemHeight)
    local hasScrollbar = #self.items > self:_getVisibleItemCount()
    
    return mouseX >= self.x and 
           mouseX <= self.x + self.width - (hasScrollbar and 16 or 0) and
           mouseY >= itemY and 
           mouseY < itemY + self.itemHeight
end

function Window:_drawScrollbar()
    if #self.items <= self:_getVisibleItemCount() then return end
    
    local contentHeight = self.height - self.titleBarHeight - self.footerHeight
    local scrollbarWidth = 16
    local thumbHeight = math.max(20, (self:_getVisibleItemCount() / #self.items) * contentHeight)
    local thumbPosition = (self.scrollOffset / (#self.items - self:_getVisibleItemCount())) * 
                         (contentHeight - thumbHeight)
    
    -- Draw track
    draw.Color(unpack(menu.colors.scrollbarBg))
    draw.FilledRect(
        self.x + self.width - scrollbarWidth,
        self.y + self.titleBarHeight,
        self.x + self.width,
        self.y + self.height - self.footerHeight
    )
    
    -- Draw thumb
    if menu._state.mouseState.isDraggingScrollbar then
        draw.Color(unpack(menu.colors.scrollbarThumbActive))
    elseif self:_isPointInScrollbar(input.GetMousePos()) then
        draw.Color(unpack(menu.colors.scrollbarThumbHover))
    else
        draw.Color(unpack(menu.colors.scrollbarThumb))
    end
    
    draw.FilledRect(
        self.x + self.width - scrollbarWidth,
        self.y + self.titleBarHeight + thumbPosition,
        self.x + self.width,
        self.y + self.titleBarHeight + thumbPosition + thumbHeight
    )
end

function Window:render()
    if not self.isOpen then return end
    
    -- Update mouse state
    self:_updateMouseState()
    
    -- Handle dragging
    self:_handleDragging()
    
    -- Draw window frame
    draw.Color(unpack(menu.colors.border))
    draw.OutlinedRect(self.x - 1, self.y - 1, self.x + self.width + 1, self.y + self.height + 1)
    
    -- Draw window background
    draw.Color(unpack(menu.colors.windowBg))
    draw.FilledRect(self.x, self.y, self.x + self.width, self.y + self.height)
    
    -- Draw components
    self:_drawTitleBar()
    self:_drawItems()
    self:_drawScrollbar()
end

-- Public API
function menu.createWindow(title, config)
    local window = Window.new(title, config)
    table.insert(menu._state.windows, window)
    return window
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

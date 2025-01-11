-- Example usage:
local menu = require("menu")

-- Create a window
local myWindow = menu.createWindow("My Window", {
    x = 100,
    y = 100,
    width = 400,
    height = 300,
    onClose = function()
        print("Window closed!")
    end,
    onItemClick = function(item)
        print("Clicked item:", item.text)
    end
})

-- Add items
myWindow:addItem({ text = "Item 1" })
myWindow:addItem({ text = "Item 2" })
myWindow:addItem({ text = "Item 3" })

-- Open/close the window
myWindow.isOpen = true  -- Show the window
-- myWindow.isOpen = false  -- Hide the window

-- Clear all items
myWindow:clearItems()

-- The window supports:
-- - Dragging by titlebar
-- - Scrolling with mousewheel
-- - Scrollbar for many items
-- - Close button
-- - Item hover effects
-- - Click handling

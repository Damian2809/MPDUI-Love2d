local controllerview = {}

function controllerview.drawControls(screenWidth, screenHeight, font)
    love.graphics.setFont(font)
    love.graphics.setColor(1, 1, 1) -- White text

    local controls = {
        { "A", "Play and Stop" },
        { "B", "Add song to Current Playlist" },
        { "X", "Force Play" },
        { "Y", "Clear Playlist" },
        { "R1", "Show Controls" }
    }

    local title = "Controller Mappings"
    local titleWidth = font:getWidth(title)
    local titleX = (screenWidth / 2) - (titleWidth / 2)
    local titleY = 50

    -- Draw the title
    love.graphics.print(title, titleX, titleY)

    -- Draw the controls
    local startY = titleY + 40
    for i, control in ipairs(controls) do
        local button = control[1]
        local description = control[2]
        local text = button .. " = " .. description
        local textWidth = font:getWidth(text)
        local textX = (screenWidth / 2) - (textWidth / 2)
        local textY = startY + (i - 1) * 30
        love.graphics.print(text, textX, textY)
    end
end

return controllerview
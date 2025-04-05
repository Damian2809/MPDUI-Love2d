local socket = require("socket")
local push = require "push"
local controllerview = require("controllerview") 

love.graphics.setDefaultFilter("nearest", "nearest")
local gameWidth, gameHeight = 640, 480 -- Fixed game resolution
local windowWidth, windowHeight = love.window.getDesktopDimensions()
push:setupScreen(gameWidth, gameHeight, windowWidth, windowHeight, {fullscreen = false})

local mpd_host = "192.168.178.175"
--local mpd_host = "localhost"
local mpd_port = 6970
local mpd_client
local songs = {}
local selected_index = 1
local metadata = {}
local screenWidth, screenHeight = 640, 480
local scroll_offset = 0
local max_visible_songs = 15 -- Number of songs visible at a time

local current_time = 0
local total_time = 0

local font = love.graphics.newFont("assets/font/Monocraft.ttf", 16) 
local bigfont = love.graphics.newFont("assets/font/Monocraft.ttf", 40)  
love.graphics.setFont(font)

local key_hold = { up = false, down = false } -- Track key states
local key_hold_timer = 0 -- Timer for controlling scrolling speed
local key_hold_interval = 0.1 -- Interval between scrolls when holding a key

local is_playing = false -- Shared variable to track playback state
local show_controls = false -- Track whether to show the controls


function love.update(dt)
    -- Periodically update playback info
    update_playback_info()

    -- Handle key holding for scrolling
    key_hold_timer = key_hold_timer + dt
    if key_hold_timer >= key_hold_interval then
        if key_hold.down and selected_index < #songs then
            selected_index = selected_index + 1
            if selected_index > scroll_offset + max_visible_songs then
                scroll_offset = scroll_offset + 1
            end
        elseif key_hold.up and selected_index > 1 then
            selected_index = selected_index - 1
            if selected_index <= scroll_offset then
                scroll_offset = scroll_offset - 1
            end
        end
        key_hold_timer = 0 -- Reset the timer
    end
end



function love.load()
    reload_mpd()
    connect_mpd()
end



function love.draw()
    push:start()
    love.graphics.clear(0.82, 0.71, 0.55)

    if show_controls then
        -- Show the controls view
        controllerview.drawControls(screenWidth, screenHeight, font)
    else
        -- Existing drawing logic
        love.graphics.setFont(bigfont)

        -- Calculate the position to center the title
        local title = "MPD Player"
        local titleWidth = bigfont:getWidth(title)
        local titleX = (screenWidth / 2) - (titleWidth / 2)
        local titleY = (screenHeight / 160) -- Barely at the top

        -- Draw the title
        love.graphics.print(title, titleX, titleY)

        love.graphics.setFont(font)


        
        -- Display only the visible songs based on scroll_offset
        for i = 1, max_visible_songs do
            local song_index = i + scroll_offset
            if song_index > #songs then break end -- Stop if we exceed the song list

            local song = songs[song_index]
            local songWidth = love.graphics.getFont():getWidth(song) -- Get text width
            local x = (screenWidth / 2) - (songWidth / 2) -- Centering formula

            if song_index == selected_index then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)
            end
            love.graphics.print(song, x, 30 + i * 20)
        end

        -- Draw the rounded progress bar
        if total_time > 0 then
            local progress = current_time / total_time -- Calculate progress percentage
            local bar_width = screenWidth * 0.8 -- 80% of the screen width
            local bar_height = 20
            local bar_x = (screenWidth - bar_width) / 2
            local bar_y = screenHeight - 100 -- Position near the bottom
            local corner_radius = bar_height / 2 -- Radius for rounded corners

            -- Draw the border of the progress bar
            love.graphics.setColor(1, 1, 1) -- White color for the border
            love.graphics.rectangle("line", bar_x, bar_y, bar_width, bar_height, corner_radius, corner_radius)

            -- Draw the filled portion of the progress bar
            love.graphics.setColor(255, 255, 255) -- Green color for the progress
            love.graphics.rectangle("fill", bar_x, bar_y, bar_width * progress, bar_height, corner_radius, corner_radius)

            -- Draw the remaining time as text
            local remaining_time = total_time - current_time
            local minutes = math.floor(remaining_time / 60)
            local seconds = remaining_time % 60
            local time_text = string.format("Time Left: %02d:%02d", minutes, seconds)
            local time_text_width = font:getWidth(time_text)
            local time_text_x = (screenWidth / 2) - (time_text_width / 2)
            local time_text_y = bar_y + bar_height + 10 -- Position below the progress bar

            love.graphics.setColor(1, 1, 1) -- Reset color to white for text
            love.graphics.print(time_text, time_text_x, time_text_y)
        end
    end

    love.graphics.setColor(1, 1, 1)
    push:finish()
end

function love.keypressed(key)
    if key == "down" then
        key_hold.down = true 
    elseif key == "up" then
        key_hold.up = true 
    elseif key == "x" then
        send_command("clear")
        local song = songs[selected_index]
        print("Adding song to playlist: " .. song) 
        send_command('add "' .. song .. '"')
        send_command("play")
    elseif key == "a" then
        if is_playing then
            send_command("pause")
            print("Music stopped.")
        else
            send_command("pause 0")
            print("Music started.")
        end
    elseif key == "y" then
        send_command("clear")
        print("Playlist cleared.")
    elseif key == "b" then
        local song = songs[selected_index]
        print("Adding song to playlist: " .. song)
        send_command('add "' .. song .. '"')
    elseif key == "r" then
        show_controls = not show_controls 
    elseif key == "l" then
        send_command("shuffle")
        print("Playlist shuffled.")
    elseif key == "return" then
        send_command("clear")
        local song = songs[selected_index]
        print("Adding song to playlist: " .. song) 
        send_command('add "' .. song .. '"') 
        send_command("play")
    end
end

function love.keyreleased(key)
    if key == "down" then
        key_hold.down = false
    elseif key == "up" then
        key_hold.up = false
    end
end


------ MPD FUNCTIONS ------

function update_playback_info()
    local response = send_command("status")
    for _, line in ipairs(response) do
        if line:find("time:") then
            local current, total = line:match("time: (%d+):(%d+)")
            if current and total then
                current_time = tonumber(current)
                total_time = tonumber(total)
            else
                current_time = 0
                total_time = 0
            end
        end
    end

    -- Update the global is_playing variable
    is_playing = false
    for _, line in ipairs(response) do
        if line:find("state: play") then
            is_playing = true
            break
        end
    end

    -- Like why cant you just see its not set and always give it 0
    -- This is a workaround to avoid nil values because lua is shit
    if not current_time or not total_time then
        current_time = 0
        total_time = 0
    end
end


function send_command(cmd)
    if not mpd_client then
        print("Connecting to MPD...")
        connect_mpd()
    end
    
    -- print("Sending command: " .. cmd)  -- Debugging the command being sent to MPD
    mpd_client:send(cmd .. "\n")
    
    local response = {}
    
    -- Receive the response from MPD
    while true do
        local line, err = mpd_client:receive("*l")
        if not line then
            print("Error receiving response: " .. err)
            break
        end
        
        -- Print all lines of the response for debugging
        -- print("MPD Response Line: " .. line)

        if line:find("OK") or line:find("ACK") then
            break
        end

        table.insert(response, line)
    end


    return response
end

function connect_mpd()
    -- Create the TCP socket
    mpd_client = assert(socket.tcp(), "Failed to create TCP socket.")
    
    -- Try to connect to MPD
    local success, err = pcall(function()
        mpd_client:connect(mpd_host, mpd_port)
        mpd_client:settimeout(0.5)
        mpd_client:receive("*l") -- Consume MPD welcome message
    end)

    -- Check if the connection was successful
    if success then
        print("Connected to MPD!")
        print("Reloading DB")
        send_command("update")
    else
        print("Failed to connect to MPD:", err)
    end
end

function reload_mpd()
    songs = {}
    local response = send_command("listall")
    
    for _, line in ipairs(response) do
        -- Only insert lines that contain the file path
        if line:find("file:") then
            local song = line:gsub("file: ", "")
            if song and song ~= "" then
                table.insert(songs, song) -- Insert only valid song paths
            end
        end
    end
    
    -- Debug output for songs
    print("Songs List:")
    for _, song in ipairs(songs) do
        print(song)  -- This will show all the songs found, log is getting crazy
    end

    -- Set the selected index and load metadata for the first song if we have any
    if #songs > 0 then
        selected_index = 1
    end
end

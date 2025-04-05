local socket = require("socket")

local mpd = {}

local mpd_host = "localhost"
local mpd_port = 6970
local mpd_client
local current_time = 0
local total_time = 0
local is_playing = false

function mpd.update_playback_info()
    local response = mpd.send_command("status")
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

    is_playing = false
    for _, line in ipairs(response) do
        if line:find("state: play") then
            is_playing = true
            break
        end
    end

    if not current_time or not total_time then
        current_time = 0
        total_time = 0
    end
end

function mpd.send_command(cmd)
    if not mpd_client then
        print("Connecting to MPD...")
        mpd.connect_mpd()
    end

    mpd_client:send(cmd .. "\n")
    local response = {}

    while true do
        local line, err = mpd_client:receive("*l")
        if not line then
            print("Error receiving response: " .. err)
            break
        end

        if line:find("OK") or line:find("ACK") then
            break
        end

        table.insert(response, line)
    end

    return response
end

function mpd.connect_mpd()
    mpd_client = assert(socket.tcp(), "Failed to create TCP socket.")
    local success, err = pcall(function()
        mpd_client:connect(mpd_host, mpd_port)
        mpd_client:settimeout(0.5)
        mpd_client:receive("*l")
    end)

    if success then
        print("Connected to MPD!")
        print("Reloading DB")
        mpd.send_command("update")
    else
        print("Failed to connect to MPD:", err)
    end
end

function mpd.reload_mpd()
    local songs = {}
    local response = mpd.send_command("listall")

    for _, line in ipairs(response) do
        if line:find("file:") then
            local song = line:gsub("file: ", "")
            if song and song ~= "" then
                table.insert(songs, song)
            end
        end
    end

    print("Songs List:")
    for _, song in ipairs(songs) do
        print(song)
    end

    return songs
end

return mpd
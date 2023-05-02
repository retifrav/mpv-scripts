-- A script to generate a FFmpeg command for cutting a video fragment

utils = require 'mp.utils'

excerpt_begin = 0.0
excerpt_end = mp.get_property_native("length")
if excerpt_end == nil or excerpt_end == "none" then
    excerpt_end = 0.0
end

mp.set_property("hr-seek-framedrop","no")
mp.set_property("options/keep-open","always")

-- alas, the following setting seems to not take effect - needs
-- to be specified on the command line of mpv, instead:
-- mp.set_property("options/script-opts","osc-layout=bottombar,osc-hidetimeout=120000")

function excerpt_on_eof()
    -- pause upon reaching the end of the file
    mp.msg.log("info", "playback reached end of file")
    mp.set_property("pause","yes")
    mp.commandv("seek", 100, "absolute-percent", "exact")
end
mp.register_event("eof-reached", excerpt_on_eof)

-- range marking

function excerpt_rangemessage()
    local duration = excerpt_end - excerpt_begin
    local message = ""
    message = message .. "begin=" .. string.format("%4.3f", excerpt_begin) .. "s "
    message = message .. "end=" .. string.format("%4.3f", excerpt_end) .. "s "
    message = message .. "duration=" .. string.format("% 4.3f", duration) .. "s"
    return message
end

function excerpt_rangeinfo()
    local message = excerpt_rangemessage()
    mp.msg.log("info", message)
    mp.osd_message(message, 5)
end

function formatTimeString(timePos)
    local time_in_seconds = timePos
    local time_seg = timePos % 60
    timePos = timePos - time_seg
    local time_hours = math.floor(timePos / 3600)
    timePos = timePos - (time_hours * 3600)
    local time_minutes = timePos/60
    time_seg,time_ms=string.format("%.03f", time_seg):match"([^.]*).(.*)"
    time = string.format("%02d:%02d:%02d.%s", time_hours, time_minutes, time_seg, time_ms)
    return time
end

function excerpt_mark_begin_handler()
    pt = mp.get_property_native("playback-time")
    if pt == nil or pt == "none" then
        pt = 0.0
    end

    -- at some later time, setting a/b markers might be used to visualize begin/end
    -- mp.set_property("ab-loop-a", pt)
    -- mp.set_property("loop", 999)

    excerpt_begin = pt
    if excerpt_begin > excerpt_end then
        excerpt_end = excerpt_begin
    end

    excerpt_rangeinfo()
end

function excerpt_mark_end_handler()
    pt = mp.get_property_native("playback-time")
    if pt == nil or pt == "none" then
        pt = 0.0
    end

    -- at some later time, setting a/b markers might be used to visualize begin/end
    -- mp.set_property("ab-loop-b", pt)
    -- mp.set_property("loop", 999)

    excerpt_end = pt
    if excerpt_end < excerpt_begin then
        excerpt_begin = excerpt_end
    end

    excerpt_rangeinfo()
end

-- assume some plausible frame time until property "fps" is set
frame_time = 24.0 / 1001.0

function excerpt_fps_changed(name)
    ft = mp.get_property_native("fps")
    if ft ~= nil and ft > 0.0 then
        frame_time = 1.0 / ft
        -- mp.msg.log("info", "fps property changed to " .. ft .. " frame_time=" .. frame_time .. "s")
    end
end
mp.observe_property("fps", native, excerpt_fps_changed)

-- seeking

seek_account = 0.0
seek_keyframe = true

function excerpt_seek()

    local abs_sa = math.abs(seek_account)
    if abs_sa < (frame_time / 2.0) then
        seek_account = 0.0
        -- no seek required
        return
    end

    -- mp.msg.log("info", "seek_account = " .. seek_account)

    if (abs_sa >= 10.0) then
        -- for seeks above 10 seconds, always use coarse keyframe seek
        local s = seek_account
        seek_account = 0.0
        mp.commandv("seek", s, "relative+keyframes")
        return
    end

    if ((abs_sa > 0.5) or seek_keyframe) then
        -- for small seeks, use exact seek (unless instructed otherwise by user)
        local s = seek_account
        seek_account = 0.0

        local mode = "relative+exact"
        if seek_keyframe then
            mode = "relative+keyframes"
        end

        mp.commandv("seek", s, mode)
        return
    end

    -- for tiny seeks, use frame steps
    local s = frame_time
    if (seek_account < 0.0) then
        s = -s
        mp.commandv("frame_back_step")
    else
        mp.commandv("frame_step")
    end
    seek_account = seek_account - s;
end

-- we have excerpt_seek called both periodically and
-- upon the display of yet another frame - this allows
-- to make "framewise" stepping with autorepeating keys to
-- work as smooth as possible
excerpt_seek_timer = mp.add_periodic_timer(0.1, excerpt_seek)
mp.register_event("tick", excerpt_seek)
-- (I have experimented with stopping the timer when possible,
--  but this didn't work out for strange reasons, got error
--  messages from the event loop)

function check_key_release(kevent)
    -- mp.msg.log("info", tostring(kevent))
    -- for k,v in pairs(kevent) do
    --  mp.msg.log("info", "kevent[" .. k .. "] = " .. tostring(v))
    -- end

    if kevent["event"] == "up" then
        -- mp.msg.log("info", "key up detected")

        -- key was released, so we should immediately stop to do any seeking
        seek_account = 0.0

        -- The "zero-seek" at key-release seems to do more harm than good with recent mpv versions:
        --  if mpv has not reached the new position from the previously issued seek yet and a relative seek to 0.0 is done, this
        --  will counter-act the idea of doing a coarse key-frame seek, causing a long wait
        --  before an image is shown for the new position.
        -- So for no, we do not perform this "zero-seek".
        if false then
        if (not seek_keyframe) then
            -- and do a "zero-seek" to reset mpv's internal frame step counter:
            mp.commandv("seek", 0.0, "relative", "exact")
            mp.set_property("pause","yes")
        end
        end
        return true
    end
    return false
end

function excerpt_frame_forward(kevent)
    if check_key_release(kevent) then
        return
    end

    seek_keyframe = false
    seek_account = seek_account + frame_time
end

function excerpt_frame_back(kevent)
    if check_key_release(kevent) then
        return
    end

    seek_keyframe = false
    seek_account = seek_account - frame_time
end

function excerpt_keyframe_forward(kevent)
    if check_key_release(kevent) then
        return
    end

    seek_keyframe = true
    seek_account = seek_account + 0.4
end

function excerpt_keyframe_back(kevent)
    if check_key_release(kevent) then
        return
    end

    seek_keyframe = true
    seek_account = seek_account - 0.6
end

function excerpt_seek_begin_handler()
    mp.commandv("seek", excerpt_begin, "absolute", "exact")
end

function excerpt_seek_end_handler()
    mp.commandv("seek", excerpt_end, "absolute", "exact")
end

-- that's Windows only, obviously
function setClipboard (text)
    local echo
    if text ~= "" then
        for i = 1, 2 do text = text:gsub("[%^&\\<>|]", "^%0") end
        echo = "(echo " .. text:gsub("\n", " & echo ") .. ")"
    else
        echo = "echo:"
    end
    mp.commandv("run", "cmd.exe", "/d", "/c", echo .. " | clip")
end

function excerpt_write_handler()
    if excerpt_begin == excerpt_end then
        message = "excerpt_write: not writing because begin == end == " .. excerpt_begin
        mp.osd_message(message, 3)
        return
    end

    local ffmpegCmd = string.format(
        "ffmpeg -ss %s -i %s -t %s -c copy -map_chapters -1 %s-cut.mp4",
        formatTimeString(excerpt_begin),
        mp.get_property_native("path"),
        excerpt_end - excerpt_begin,
        mp.get_property_native("filename/no-ext")
    )

    local writeToFile = tonumber(mp.get_opt("excerpt-write-to-file"))
    if (writeToFile == nil) then
        writeToFile = 0
    end

    local fileName = "ffmpeg-command.txt"
    if (writeToFile == 1) then
        file = io.open(fileName, "a")
        file:write(ffmpegCmd, "\n")
        file:close()
        mp.osd_message(string.format("Written to file: %s", fileName))
    else
        setClipboard(ffmpegCmd)
        mp.osd_message(string.format("Copied to clipboard: %s", ffmpegCmd))
    end
end

-- things to do whenever a new file was loaded

function excerpt_on_loaded()
    -- pause play right after loading a file
    if mp.get_opt("excerpt-no-pause-on-file-loaded") ~= "1" then
        mp.set_property("pause","yes")
    end
end

mp.register_event("file-loaded", excerpt_on_loaded)

-- keybindings

-- mark the begin of the fragment
mp.add_key_binding("shift+i", "excerpt_mark_begin", excerpt_mark_begin_handler)
-- jump to the begin mark
mp.add_key_binding("alt+shift+i", "excerpt_seek_begin", excerpt_seek_begin_handler)
-- mark the end of the fragment
mp.add_key_binding("shift+o", "excerpt_mark_end", excerpt_mark_end_handler)
-- jump to the end mark
mp.add_key_binding("alt+shift+o", "excerpt_seek_end", excerpt_seek_end_handler)
-- generate FFmpeg command
mp.add_key_binding("x", "excerpt_write", excerpt_write_handler)

mp.add_key_binding("shift+right", "excerpt_keyframe_forward", excerpt_keyframe_forward, { repeatable = true; complex = true })
mp.add_key_binding("shift+left", "excerpt_keyframe_back", excerpt_keyframe_back, { repeatable = true; complex = true })
mp.add_key_binding("right", "excerpt_frame_forward", excerpt_frame_forward, { repeatable = true; complex = true })
mp.add_key_binding("left", "excerpt_frame_back", excerpt_frame_back, { repeatable = true; complex = true })

excerpt_rangeinfo()

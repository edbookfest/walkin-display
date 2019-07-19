gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)

node.alias("walkin")

local json = require "json"
local loader = require "loader"

local walkin_state = "walkin"
local show_event_slide = false
local switch_time = sys.now()
local event_slide
local event_slide_alpha = 0
local progress_indicator = "no"

local settings = {
    IMAGE_PRELOAD = 2;
    VIDEO_PRELOAD = 2;
    CHILD_PRELOAD = 2;
    PRELOAD_TIME = 4;
    FALLBACK_PLAYLIST = {
        {
            offset = 0;
            total_duration = 1;
            duration = 1;
            asset_name = "empty.png";
            type = "image";
        }
    }
}

local white = resource.create_colored_texture(1, 1, 1, 1)
local black = resource.create_colored_texture(0, 0, 0, 1)
local font = resource.load_font "roboto.ttf"

local function ramp(t_s, t_e, t_c, ramp_time)
    if ramp_time == 0 then return 1 end
    local delta_s = t_c - t_s
    local delta_e = t_e - t_c
    return math.min(1, delta_s * 1 / ramp_time, delta_e * 1 / ramp_time)
end

local function cycled(items, offset)
    offset = offset % #items + 1
    return items[offset], offset
end

local function strtobool(str)
    if str == "true" then
        return true
    end
    return false
end

local function printWalkinState()
    print("CURRENTLY SHOWING: " .. walkin_state)
end

local Loading = (function()
    local loading = "Loading..."
    local size = 80
    local w = font:width(loading, size)
    local alpha = 0

    local function draw()
        if alpha == 0 then
            return
        end
        font:write((WIDTH - w) / 2, (HEIGHT - size) / 2, loading, size, 1, 1, 1, alpha)
    end

    local function fade_in()
        alpha = math.min(1, alpha + 0.01)
    end

    local function fade_out()
        alpha = math.max(0, alpha - 0.01)
    end

    return {
        fade_in = fade_in;
        fade_out = fade_out;
        draw = draw;
    }
end)()

local Config = (function()
    local playlist = {}
    local switch_time = 1

    local config_file = "config.json"

    -- You can put a static-config.json file into the package directory.
    -- That way the config.json provided by info-beamer hosted will be
    -- ignored and static-config.json is used instead.
    --
    -- This allows you to import this package bundled with images/
    -- videos and a custom generated configuration without changing
    -- any of the source code.
    if CONTENTS["static-config.json"] then
        config_file = "static-config.json"
        print "[WARNING]: will use static-config.json, so config.json is ignored"
    end

    util.file_watch(config_file, function(raw)
        print("updated " .. config_file)
        local config = json.decode(raw)

        if config.auto_resolution then
            gl.setup(NATIVE_WIDTH, NATIVE_HEIGHT)
        else
            gl.setup(config.width, config.height)
        end

        print("screen size is " .. WIDTH .. "x" .. HEIGHT)

        if #config.playlist == 0 then
            playlist = settings.FALLBACK_PLAYLIST
            switch_time = 0
        else
            playlist = {}
            local total_duration = 0
            for idx = 1, #config.playlist do
                local item = config.playlist[idx]
                total_duration = total_duration + item.duration
            end

            local offset = 0
            for idx = 1, #config.playlist do
                local item = config.playlist[idx]
                if item.duration > 0 then
                    playlist[#playlist + 1] = {
                        offset = offset,
                        total_duration = total_duration,
                        duration = item.duration,
                        asset_name = item.file.asset_name,
                        type = item.file.type,
                    }
                    offset = offset + item.duration
                end
            end
            switch_time = config.switch_time
        end
    end)

    return {
        get_playlist = function() return playlist end;
        get_switch_time = function() return switch_time end;
    }
end)()

local Modules = (function()
    local function is_module(module_name)
        for name, module in pairs(loader.modules) do
            if name == module_name then
                return true, module
            end
        end
        return false
    end

    return {
        is_module = is_module;
    }
end)()

local Scheduler = (function()
    local playlist_offset = 0

    local function get_next()
        local playlist = Config.get_playlist()

        local item
        local got_content = false
        while not got_content
        do
            item, playlist_offset = cycled(playlist, playlist_offset)

            if item.type == "child" or item.type == "module" then
                local is_mod, module = Modules.is_module(item.asset_name)
                if is_mod then
                    if module.has_content() then
                        item.type = "module"
                    else
                        print(item.asset_name .. " module has no content")
                    end
                    got_content = module.has_content()
                else
                    got_content = true --childs have content
                end
            else
                got_content = true --images and videos have content
            end
        end

        print(string.format("next scheduled item is %s [%f]", item.asset_name, item.duration))
        return item
    end

    local function restart_schedule()
        playlist_offset = 0
    end

    return {
        get_next = get_next;
        restart_schedule = restart_schedule;
    }
end)()

local function draw_progress(starts, ends, now)
    local mode = progress_indicator
    if mode == "no" then
        return
    end

    if ends - starts < 2 then
        return
    end

    local progress = 1.0 / (ends - starts) * (now - starts)
    if mode == "bar_thin_white" then
        white:draw(0, HEIGHT - 10, WIDTH * progress, HEIGHT, 0.5)
    elseif mode == "bar_thin_black" then
        black:draw(0, HEIGHT - 10, WIDTH * progress, HEIGHT, 0.5)
    elseif mode == "countdown" then
        local remaining = math.ceil(ends - now)
        local text
        if remaining >= 60 then
            text = string.format("%d:%02d", remaining / 60, remaining % 60)
        else
            text = remaining
        end
        local size = 32
        local w = font:width(text, size)
        black:draw(WIDTH - w - 4, HEIGHT - size - 4, WIDTH, HEIGHT, 0.6)
        font:write(WIDTH - w - 2, HEIGHT - size - 2, text, size, 1, 1, 1, 0.8)
    end
end

local ImageJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.IMAGE_PRELOAD)

    local res = resource.load_image(ctx.asset)

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "loaded" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    local starts = fn.wait_t(ctx.starts)
    local duration = ctx.ends - starts

    print(">>> IMAGE", res, ctx.starts, ctx.ends)

    while true do
        local now = sys.now()
        if walkin_state ~= "eventslide" then
            util.draw_correct(res, 0, 0, WIDTH, HEIGHT, ramp(ctx.starts, ctx.ends, now, Config.get_switch_time()))
            draw_progress(ctx.starts, ctx.ends, now)
        end
        if now > ctx.ends then
            break
        end

        fn.wait_next_frame()
    end

    print("<<< IMAGE", res, ctx.starts, ctx.ends)
    res:dispose()

    return true
end

local VideoJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.VIDEO_PRELOAD)

    local raw = sys.get_ext "raw_video"
    local res = raw.load_video {
        file = ctx.asset,
        audio = false,
        looped = false,
        paused = true,
    }

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "paused" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    fn.wait_t(ctx.starts)

    print(">>> VIDEO", res, ctx.starts, ctx.ends)
    res:start()

    while true do
        local now = sys.now()
        if walkin_state ~= "eventslide" then
            local state, width, height = res:state()
            if state ~= "finished" then
                local layer = -2
                if now > ctx.starts + 0.1 then
                    -- after the video started, put it on a more
                    -- foregroundy layer. that way two videos
                    -- played after one another are sorted in a
                    -- predictable way and no flickering occurs.
                    layer = -1
                end

                local x1, y1, x2, y2 = util.scale_into(NATIVE_WIDTH, NATIVE_HEIGHT, width, height)
                res:layer(layer):target(x1, y1, x2, y2, ramp(ctx.starts, ctx.ends, now, Config.get_switch_time()))
            end
            draw_progress(ctx.starts, ctx.ends, now)
        end
        if now > ctx.ends then
            break
        end
        fn.wait_next_frame()
    end

    print("<<< VIDEO", res, ctx.starts, ctx.ends)
    res:dispose()

    return true
end

local ChildJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.CHILD_PRELOAD)

    local res = resource.render_child(item.asset_name)

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "loaded" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    local starts = fn.wait_t(ctx.starts)
    local duration = ctx.ends - starts

    print(">>> CHILD", res, ctx.starts, ctx.ends)

    while true do
        local now = sys.now()
        if walkin_state ~= "eventslide" then
            util.draw_correct(res, 0, 0, WIDTH, HEIGHT, ramp(ctx.starts, ctx.ends, now, Config.get_switch_time()))
            draw_progress(ctx.starts, ctx.ends, now)
        end
        if now > ctx.ends then
            break
        end
        fn.wait_next_frame()
    end

    print("<<< CHILD", res, ctx.starts, ctx.ends)
    res:dispose()

    return true
end

local ModuleJob = function(item, ctx, fn)
    fn.wait_t(ctx.starts - settings.CHILD_PRELOAD)

    local is_mod, mod = Modules.is_module(item.asset_name)
    local res = mod.get_surface()

    for now in fn.wait_next_frame do
        local state, err = res:state()
        if state == "loaded" then
            break
        elseif state == "error" then
            error("preloading failed: " .. err)
        end
    end

    print "waiting for start"
    local starts = fn.wait_t(ctx.starts)
    local duration = ctx.ends - starts

    print(">>> MODULE", item.asset_name, ctx.starts, ctx.ends)

    while true do
        local now = sys.now()
        if walkin_state ~= "eventslide" then
            util.draw_correct(res, 0, 0, WIDTH, HEIGHT, ramp(ctx.starts, ctx.ends, now, Config.get_switch_time()))
            draw_progress(ctx.starts, ctx.ends, now)
        end
        if now > ctx.ends then
            break
        end
        fn.wait_next_frame()
    end

    print("<<< MODULE", item.asset_name, ctx.starts, ctx.ends)
    res:dispose()

    return true
end

local Queue = (function()
    local jobs = {}
    local scheduled_until = sys.now()

    local function clear_jobs()
        jobs = {}
        scheduled_until = sys.now()
    end

    local function enqueue(starts, ends, item)
        local co = coroutine.create(({
            image = ImageJob,
            video = VideoJob,
            child = ChildJob,
            module = ModuleJob,
        })[item.type])

        local asset = null
        if (item.type == "child" or item.type == "module") then
            asset = item
        else
            local success, openfile = pcall(resource.open_file, item.asset_name)
            if not success then
                print("CANNOT GRAB ASSET: ", asset)
                return
            end
            asset = openfile
        end

        -- start all content at begining of transition
        if #jobs > 0 then
            starts = starts - Config.get_switch_time()
        end

        local ctx = {
            starts = starts,
            ends = ends,
            asset = asset;
        }

        local success, err = coroutine.resume(co, item, ctx, {
            wait_next_frame = function()
                return coroutine.yield(false)
            end;
            wait_t = function(t)
                while true do
                    local now = coroutine.yield(false)
                    if now > t then
                        return now
                    end
                end
            end;
        })

        if not success then
            print("CANNOT START JOB: ", err)
            return
        end

        jobs[#jobs + 1] = {
            co = co;
            ctx = ctx;
            type = item.type;
        }

        scheduled_until = ends
        print("added job. scheduled program until ", scheduled_until)
    end

    local function tick()
        gl.clear(0, 0, 0, 0)

        for try = 1, 3 do
            if sys.now() + settings.PRELOAD_TIME < scheduled_until then
                break
            end
            local item = Scheduler.get_next()
            enqueue(scheduled_until, scheduled_until + item.duration, item)
        end

        if #jobs == 0 then
            Loading.fade_in()
        else
            Loading.fade_out()
        end

        local now = sys.now()
        for idx = #jobs, 1, -1 do -- iterate backwards so we can remove finished jobs
            local job = jobs[idx]
            local success, is_finished = coroutine.resume(job.co, now)
            if not success then
                print("CANNOT RESUME JOB: ", is_finished)
                table.remove(jobs, idx)
            elseif is_finished then
                table.remove(jobs, idx)
            end
        end

        Loading.draw()
    end

    return {
        tick = tick;
        clear_jobs = clear_jobs;
    }
end)()

util.data_mapper {
    ["show_event_slide"] = function(v)
        local status = strtobool(v)
        if status ~= show_event_slide then
            show_event_slide = status
            switch_time = sys.now()
            if status then
                walkin_state = "fadein"
            else
                walkin_state = "fadeout"
            end
            print("SHOW EVENT SLIDE " .. v)
        else
            print("EVENT SLIDE IS CURRENTLY " .. v)
        end
    end;
    ["eventid"] = function(eventid)
        Queue.clear_jobs()
        Scheduler.restart_schedule()
    end;
    ["show_progress"] = function(v)
        progress_indicator = v;
    end;
}

util.set_interval(1, node.gc)

util.set_interval(5, printWalkinState)

function node.render()
    gl.clear(0, 0, 0, 1)

    Queue.tick()

    local now = sys.now()

    if walkin_state == "fadein" then
        event_slide_alpha = ramp(switch_time, now + 1, now, Config.get_switch_time())
    elseif walkin_state == "fadeout" then
        event_slide_alpha = ramp(switch_time - 1, switch_time + 0.5, now, Config.get_switch_time())
    end

    if walkin_state ~= "walkin" then

        event_slide = resource.render_child("event-slide")

        event_slide:draw(0, 0, WIDTH, HEIGHT, event_slide_alpha)
    end

    if event_slide_alpha < 0 then
        walkin_state = "walkin"
    end

    if event_slide_alpha > 1 then
        walkin_state = "eventslide"
    end

    if event_slide then
        event_slide:dispose()
        event_slide = nil
    end
end

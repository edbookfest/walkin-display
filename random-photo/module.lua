local localized, CHILDS, CONTENTS = ...

local M = {}

local random_image
local images = {}
local playback_idx = 0

local function shuffle(t)
    local n = #t
    while n > 2 do
        local k = math.random(n)
        t[n], t[k] = t[k], t[n]
        n = n - 1
    end
    return t
end

local function cycled(items, offset)
    offset = offset % #items + 1
    return items[offset], offset
end

local function load_available_images()
    local i = {}
    for name, _ in pairs(CONTENTS) do
        if name:match(".*jpg") then
            i[#i + 1] = name
        end
    end
    images = i
end

load_available_images()

print "Random image player init"

local function pick_random_image()
    if playback_idx == 0 then
        images = shuffle(images)
    end

    local filename
    filename, playback_idx = cycled(images, playback_idx)

    print("Next random image: " .. filename)

    local success, asset = pcall(resource.open_file, filename)
    if not success then
        print("CANNOT GRAB ASSET: ", asset)
        return
    end

    return asset
end

function M.get_surface()
    random_image = resource.load_image(pick_random_image())
    return random_image
end

function M.has_content()
    if #images > 0 then
        return true
    end
    return false
end

function M.unload()
    --print "sub module is unloaded"
end

function M.content_update(name)
    --print("sub module content update", name)
    load_available_images()
end

function M.content_remove(name)
    --print("sub module content delete", name)
    load_available_images()
end

return M

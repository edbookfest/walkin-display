local localized, CHILDS, CONTENTS = ...

local M = {}
local json = require "json"

local sponsor_image
local sponsor_playlist = {}
local loaded_event_id
local playback_idx = 0

local Config = (function()
    local sponsored_events = {}
    util.file_watch(localized "config.json", function(raw)
        print("updated config")
        local config = json.decode(raw)

        if #config.events == 0 then
            sponsored_events = {}
        else
            sponsored_events = {}
            for idx = 1, #config.events do
                local event = config.events[idx]
                local eventid = event.event_id
                local playlist = event.playlist
                local items = {}
                for idx = 1, #playlist do
                    local item = playlist[idx]
                    items[#items + 1] = {
                        asset_name = localized(item.file.asset_name),
                        type = item.file.type,
                    }
                end
                sponsored_events["id" .. eventid] = items
            end
        end
    end)

    return {
        get_sponsored_events = function() return sponsored_events end;
    }
end)()

local function cycled(items, offset)
    offset = offset % #items + 1
    return items[offset], offset
end

local function setContains(set, key)
    return set[key] ~= nil
end

local function load_sponsors_for_event(event_id)
    if event_id ~= loaded_event_id then
        local ok = setContains(Config.get_sponsored_events(), "id" .. event_id)
        if not ok then
            sponsor_image = nil
            sponsor_playlist = {}
            loaded_event_id = nil
            playback_idx = 0
            print("NO SPONSOR IMAGES FOUND FOR: " .. event_id)
        else
            playback_idx = 0
            sponsor_playlist = Config.get_sponsored_events()["id" .. event_id]
            loaded_event_id = event_id
            print("LOADING SPONSOR IMAGES FOR: " .. event_id)
        end
    else
        print("SPONSOR IMAGES ALREADY LOADED FOR: " .. loaded_event_id)
    end
end

util.data_mapper {
    ["eventid"] = function(eventid)
        load_sponsors_for_event(eventid)
    end;
}

local function get_next_sponsor_image()
    local item
    item, playback_idx = cycled(sponsor_playlist, playback_idx)

    print("------SPONSOR PLAYBACK INDEX " .. playback_idx);

    print("Next sponsor image: " .. item.asset_name)
    local success, asset = pcall(resource.open_file, item.asset_name)
    if not success then
        print("CANNOT GRAB ASSET: ", asset)
        return
    end
    return {
        item = item,
        asset = asset
    }
end

print "Sponsor image player init"

function M.has_content()
    if #sponsor_playlist > 0 then
        return true
    end
    return false
end

function M.get_surface()
    if M.has_content() then
        local next_asset = get_next_sponsor_image()
        local type = next_asset.item.type
        if (type == "video") then
            return resource.load_video {
                file = next_asset.asset;
                audio = false;
                looped = false;
                paused = false;
            }
        elseif (type == "image") then
            return resource.load_image(next_asset.asset)
        end
    end
end

function M.unload()
    --print "sub module is unloaded"
end

function M.content_update(name)
    --print("sub module content update", name)
end

function M.content_remove(name)
    --print("sub module content delete", name)
end

return M

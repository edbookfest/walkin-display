assert(sys.provides "nested-nodes", "nested nodes feature missing")

local GLOBAL_CONTENTS, GLOBAL_CHILDS = node.make_nested()

local M = {}

local modules = {}
local modules_content_versions = {}

local function module_event(child, event_name, content, ...)
    if not modules[child] then
        return
    end
    local event = modules[child][event_name]
    if event then
        -- print('-> event', event_name, content)
        return event(content, ...)
    end
end

local function module_unload(child)
    for content, version in pairs(modules_content_versions[child]) do
        module_event(child, 'content_remove', content)
    end
    module_event(child, 'unload')
    modules[child] = nil
    node.gc()
end

local function module_update(child, module_func)
    module_unload(child)
    local module = module_func(function(name)
        return child .. "/" .. name
    end, GLOBAL_CHILDS[child], GLOBAL_CONTENTS[child])
    modules[child] = module
    for content, version in pairs(modules_content_versions[child]) do
        module_event(child, 'content_update', content)
    end
    node.gc()
end

local function module_update_content(child, content, version)
    local mcv = modules_content_versions[child]
    if not mcv[content] or mcv[content] < version then
        mcv[content] = version
        return module_event(child, 'content_update', content)
    end
end

local function module_delete_content(child, content)
    local mcv = modules_content_versions[child]
    modules_content_versions[child][content] = nil
    return module_event(child, 'content_remove', content)
end

node.event("child_add", function(child)
    modules_content_versions[child] = {}
end)

node.event("child_remove", function(child)
    modules_content_versions[child] = nil
end)

node.event("content_update", function(name, obj)
    local child, content = util.splitpath(name)

    if child == '' then -- not interested in top level events
        return
    elseif content == 'module.lua' then
        return module_update(child, assert(
            loadstring(resource.load_file(obj), "=" .. name)
        ))
    else
        return module_update_content(child, content, GLOBAL_CONTENTS[child][name])
    end
end)

node.event("content_remove", function(name)
    local child, content = util.splitpath(name)

    if child == '' then -- not interested in top level events
        return
    elseif content == 'module.lua' then
        return module_unload(child)
    else
        return module_delete_content(child, content)
    end
end)

M.modules = modules

return M

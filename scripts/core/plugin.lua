local class = kt.class

-- stores meta info for every plugins.
---@class Plugin: Object
---@field path string
local Plugin = class("Plugin")

function Plugin:initialize(path)
  self.path = path
end

return Plugin

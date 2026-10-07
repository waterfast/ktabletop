local class = kt.class

-- stores meta info for every plugins.
---@class Plugin: Object
---@field path string
---@field i18nContext I18nContext
local Plugin = class("Plugin")

function Plugin:initialize(path)
  self.path = path
end

return Plugin

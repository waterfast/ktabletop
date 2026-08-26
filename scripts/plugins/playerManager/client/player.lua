local Player = require "plugins.playerManager.common.player"

---@class ClientPlayer: Player
local ClientPlayer = Player:subclass("ClientPlayer")

return ClientPlayer

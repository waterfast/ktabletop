local Player = require "plugins.playerManager.common.player"

---@class ServerPlayer: Player
local ServerPlayer = Player:subclass("ServerPlayer")

return ServerPlayer

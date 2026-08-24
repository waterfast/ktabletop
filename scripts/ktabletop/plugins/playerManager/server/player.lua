local Player = require("ktabletop.plugins.playerManager.common.player")

---@class ServerPlayer: Player
local ServerPlayer = class("ServerPlayer", Player)

---@param ctx Context
---@param connId integer
function ServerPlayer:initialize(ctx, connId)
  Player.initialize(self, ctx, connId)
  self._cpp = ctx:get("__cpp.common")
end

---@param command string
---@param data any
---@param isJson? boolean if true, should not json.encode here
function ServerPlayer:notify(command, data, isJson)
  self._cpp.notifySocket(self.connId, command, isJson and data or json.encode(data))
end

---@param command string
---@param data any
---@param timeout? integer
---@param timestamp? integer
---@param isJson? boolean if true, should not json.encode here
function ServerPlayer:request(command, data, timeout, timestamp, isJson)
  self._cpp.requestSocket(self.connId, command, isJson and data or json.encode(data), timeout or 0, timestamp or -1)
end

return ServerPlayer

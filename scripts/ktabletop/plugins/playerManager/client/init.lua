local ClientPlayer = require("ktabletop.plugins.playerManager.client.player")

---@type Plugin
local M = {
  name = "/ktabletop/client/playerManager",
  deps = { },
}

function M.setup(ctx, config)
  -- The local player's connId arrives later, once the connection handshake
  -- tells us who we are (see roomManager / socket plugin for when this
  -- becomes available). Until then `me` is nil.
  ctx:set("me", nil)

  ---@param connId integer
  local function setLocalPlayer(connId)
    ctx:set("me", ClientPlayer:new(ctx, connId))
  end

  ctx.setLocalPlayer = setLocalPlayer
end

return M

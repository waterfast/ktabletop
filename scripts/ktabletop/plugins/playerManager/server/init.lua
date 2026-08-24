local PlayerManager = require("ktabletop.plugins.playerManager.server.player-manager")

---@type Plugin
local M = {
  name = "/ktabletop/server/playerManager",
  deps = { "ktabletop.cpp.server" },
}

function M.setup(ctx, config)
  local playerManager = PlayerManager:new(ctx)
  ctx:set("playerManager", playerManager)
end

return M

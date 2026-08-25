local PlayerManager = require("ktabletop.plugins.playerManager.server.player-manager")
local ServerPlayer = require("ktabletop.plugins.playerManager.server.player")

---@type Plugin
local M = {
  name = "/ktabletop/server/playerManager",
  deps = { "ktabletop.cpp.server" },
}

function M.setup(ctx, config)
  local playerManager = PlayerManager:new(ctx)
  ctx:set("playerManager", playerManager)

  ctx:on("KTabletop::Socket::NewConnection", function(param)
    local connId = param.connId
    local player = ServerPlayer:new(ctx, connId)
    player.id = connId
    player.username = "guest" .. connId

    ctx:emit("KTabletop::PlayerManager::NewConnection", { player = player })
  end)
end

return M

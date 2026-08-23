local Player = require("ktabletop.plugins.playerManager.server.player")
local PlayerManager = require("ktabletop.plugins.playerManager.server.player-manager")

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
    local cpp = ctx:get("__cpp.server")

    local player = Player:new(ctx, connId)
    playerManager:addPlayer(player)

    ctx:emit("KTabletop::PlayerManager::NewConnection", {
      player = player,
    })
  end)
end

return M

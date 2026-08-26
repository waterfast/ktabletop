local PlayerManager = require("plugins.playerManager.server.player-manager")
local ServerPlayer = require("plugins.playerManager.server.player")

---@type Plugin
local M = {
  name = "/ktabletop/server/playerManager",
  deps = { "ktabletop.cpp.server" },
}

function M.setup(ctx, config)
  local playerManager = PlayerManager:new(ctx)
  ctx:set("playerManager", playerManager)

  ctx:on("Socket::NewConnection", function(param)
    local connId = param.connId
    local player = ServerPlayer:new(ctx, connId)
    player.id = connId
    player.username = "guest" .. connId

    playerManager:addPlayer(player)
    player:notify("SetupPlayer", { id = player.id, username = player.username })
    ctx:emit("PlayerManager::NewConnection", { player = player })
  end)
end

return M

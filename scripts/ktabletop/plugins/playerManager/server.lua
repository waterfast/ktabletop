local Player = require("ktabletop.plugins.playerManager.player")
local PlayerManager = require("ktabletop.plugins.playerManager.player-manager")

---@type Plugin
local M = {
  name = "/ktabletop/server/playerManager",
  deps = { "ktabletop.cpp.server" },
}

function M.setup(ctx, config)
  local playerManager = PlayerManager:new()
  ctx:serve("playerManager", playerManager)
  
  ctx:on("KTableTop::Socket::NewConnection", function(param)
    local connId = param.connId
    local cpp = ctx:get("__cpp.server")

    local player = Player:new(connId, cpp)
    playerManager:addPlayer(player)
    
    player:notify("EnterLobby", nil)
  end)
end

return M

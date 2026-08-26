local ClientPlayer = require("ktabletop.plugins.playerManager.client.player")
local Commands = require("ktabletop.plugins.playerManager.common.network-commands")

---@type Plugin
local M = {
  name = "/ktabletop/client/playerManager",
  deps = { "ktabletop.socketHelper" },
}

function M.setup(ctx, config)
  ctx:set("me", nil)

  ---@param connId integer
  local function setLocalPlayer(connId)
    ctx:set("me", ClientPlayer:new(ctx, connId))
  end
  ctx.setLocalPlayer = setLocalPlayer

  ctx:get("socketHelper").onNotificationGot(Commands.SetupPlayer, function(data)
    local p = ClientPlayer:new(ctx, data.connId)
    p.id = data.id
    p.username = data.username
    ctx:set("me", p)
    ctx:emit("KTabletop::Client::PlayerReady", p)
  end)
end

return M

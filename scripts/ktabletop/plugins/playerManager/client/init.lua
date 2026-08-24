local ClientPlayer = require("ktabletop.plugins.playerManager.client.player")
local Commands = require("ktabletop.plugins.playerManager.common.network-commands")

---@type Plugin
local M = {
  name = "/ktabletop/client/playerManager",
  deps = { "ktabletop.cpp.client" },
}

function M.setup(ctx, config)
  ctx:set("me", nil) -- nil until SetupPlayer

  ---@param connId integer
  local function setLocalPlayer(connId)
    ctx:set("me", ClientPlayer:new(ctx, connId))
  end
  ctx.setLocalPlayer = setLocalPlayer

  ctx:on("KTabletopCpp::Socket::NotificationGot", function(param)
    if param.command ~= Commands.SetupPlayer then
      return
    end
    local d = param.data
    local p = ClientPlayer:new(ctx, d.connId)
    p.id = d.id
    p.username = d.username
    ctx:set("me", p)
    ctx:emit("KTabletop::Client::PlayerReady", p)
  end)
end

return M

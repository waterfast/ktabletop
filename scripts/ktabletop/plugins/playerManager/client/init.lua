local ClientPlayer = require("ktabletop.plugins.playerManager.client.player")
local Commands = require("ktabletop.plugins.playerManager.common.network-commands")

---@type Plugin
local M = {
  name = "/ktabletop/client/playerManager",
  deps = { "ktabletop.socketHelper" },
}

function M.setup(ctx, config)
  ctx:get("socketHelper").onNotificationGot(Commands.SetupPlayer, function(data)
    local selfConnId = ctx:get("__cpp.client").getConnId()
    local p = ClientPlayer:new(ctx, selfConnId)
    p.id = data.id
    p.username = data.username

    ctx:set("myself", p)
  end)
end

return M

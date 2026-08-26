local ClientLobby = require "plugins.roomManager.client.lobby"
local Commands = require "plugins.playerManager.common.network-commands"

local async = require "core.async"

---@type Plugin
local M = {
  name = "/ktabletop/client/roomManager",
  deps = { "ktabletop.socketHelper", "/ktabletop/client/playerManager" },
}

function M.setup(ctx, config)
  local onNotificationGot = ctx:get("socketHelper").onNotificationGot
  onNotificationGot(Commands.EnterLobby, async.async(function(data)
    local cpp = ctx:get("__cpp.common")
    ctx:set("lobby", ClientLobby:new(ctx))
    cpp.luaEvent("Client::PushLobby", {})

    local myself = ctx:get("myself") --[[ @as ClientPlayer ]]
    local reply = myself:request(Commands.FetchRoomList)
    print("FetchRoomList reply", inspect(reply))
  end))

  onNotificationGot(Commands.UpdatePlayerNum, function(data)
    local lobby = ctx:get("lobby") --[[ @as ClientLobby ]]
    lobby:setProperty("playerCount", data[1])
  end)
end

return M

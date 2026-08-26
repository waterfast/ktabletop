local ClientLobby = require("ktabletop.plugins.roomManager.client.lobby")
local Commands = require("ktabletop.plugins.playerManager.common.network-commands")

---@type Plugin
local M = {
  name = "/ktabletop/client/roomManager",
  deps = { "ktabletop.socketHelper", "/ktabletop/client/playerManager" },
}

function M.setup(ctx, config)
  local async = require("ktabletop.core.async")

  local function notifyChanged(ctx)
    ctx:emit("KTabletop::Client::RoomStore::Changed", ctx:get("current"))
  end

  local function onEnterLobby(ctx, data)
    ctx:set("current", ClientLobby:new(ctx))
    notifyChanged(ctx)
    ctx:get("__cpp.common").luaEvent("KTabletop::Client::PushLobby", {})
    async.async(function()
      local cpp = ctx:get("__cpp.common")
      local cid = ctx:get("__cpp.client").getConnId()
      local doRequest = async.wrap(function(cmd, js, cb)
        cpp.requestSocket(cid, cmd, js, 5, -1, function(reply, err)
          cb(err, reply)
        end)
      end)
      local ok, reply = async.await(doRequest(Commands.FetchRoomList, json.encode({})))
      print("FetchRoomList reply", reply)
    end)()
  end

  local function onUpdatePlayerNum(ctx, data)
    ctx:get("current").playerCount = data[1]
    notifyChanged(ctx)
  end

  local onNotificationGot = ctx:get("socketHelper").onNotificationGot
  onNotificationGot(Commands.EnterLobby, function(data)
    onEnterLobby(ctx, data)
  end)
  onNotificationGot(Commands.UpdatePlayerNum, function(data)
    onUpdatePlayerNum(ctx, data)
  end)
end

return M

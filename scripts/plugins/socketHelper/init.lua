local async = require("core.async")

local M = {
  name = "/ktabletop/socketHelper",
  ifaces = { "ktabletop.socketHelper" },
}

function M.setup(ctx)
  local notif = {}

  local function onNotificationGot(cmd, cb)
    notif[cmd] = notif[cmd] or {}
    notif[cmd][#notif[cmd] + 1] = cb
  end

  local req = {}

  local function onRequestGot(cmd, cb)
    assert(req[cmd] == nil)
    req[cmd] = async.async(cb)
  end

  ctx:set("socketHelper", {
    onNotificationGot = onNotificationGot,
    onRequestGot = onRequestGot,
  })

  ctx:on("Core::Socket::NotificationGot", function(param)
    local list = notif[param.command]
    if not list then return end
    for _, fn in ipairs(list) do
      fn(param.data)
    end
  end)

  ctx:on("Core::Socket::RequestGot", async.async(function(param)
    local fn = req[param.command]
    if not fn then return end

    local reqId = param.requestId
    local connId = param.connId

    local player = ctx:get("myself") --[[ @as Player? ]]
    if not player then
      local pm = ctx:get("playerManager") --[[ @as PlayerManager ]]
      player = pm:findPlayer(connId)
    end

    assert(player, ("cannot find player of connId %d in request #%d"):format(connId, reqId))

    local ok, reply, err = async.await(fn(player, param.data))
    if not ok then
      player:reply(false, reqId, reply)
    elseif err then
      player:reply(false, reqId, err)
    else
      player:reply(true, reqId, reply)
    end
  end))
end

return M

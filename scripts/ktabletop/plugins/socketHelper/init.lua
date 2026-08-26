local async = require("ktabletop.core.async")

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
    req[cmd] = cb
  end

  ctx:set("socketHelper", {
    onNotificationGot = onNotificationGot,
    onRequestGot = onRequestGot,
  })

  ctx:on("KTabletopCpp::Socket::NotificationGot", function(param)
    local list = notif[param.command]
    if not list then return end
    for _, fn in ipairs(list) do
      fn(param.data)
    end
  end)

  ctx:on("KTabletopCpp::Socket::RequestGot", function(param)
    local fn = req[param.command]
    if not fn then return end
    async.async(function()
      local a, b = fn(param.data)
      local reply, err
      if type(a) == "table" and getmetatable(a) ~= nil then
        local ok, r1, r2 = async.await(a)
        if not ok then err = r1 else reply, err = r1, r2 end
      else
        reply, err = a, b
      end
      local cpp = ctx:get("__cpp.common")
      if err then
        cpp.notifySocket(param.connId, "ErrorMsg", json.encode(err))
      else
        cpp.replySocket(param.connId, param.requestId, json.encode(reply or {}))
      end
    end)()
  end)
end

return M

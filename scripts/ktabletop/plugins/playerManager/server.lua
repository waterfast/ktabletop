---@type Plugin
local M = {
  name = "/ktabletop/server/playerManager",
  deps = { "ktabletop.cpp.server" },
}

function M.setup(ctx, config)
  ctx:on("KTableTop::Socket::NewConnection", function(param)
    local connId = param.connId
    local cpp = ctx:get("__cpp.server")

    -- TODO: create player for this connId
    -- there should be some table like `players` in ctx
    cpp.notifySocket(connId, "EnterLobby", json.encode(nil))
  end)
end

return M

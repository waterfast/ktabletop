-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomManager = require "plugins.roomManager.server.room-manager"

---@type Plugin
local M = {
  name = "/ktabletop/server/roomManager",
  deps = { "/ktabletop/server/playerManager", "ktabletop.socketHelper" },
}

function M.setup(ctx, config)
  local roomManager = RoomManager:new(ctx)
  ctx:serve("roomManager", roomManager)

  ctx:on("PlayerManager::NewConnection", function(param)
    roomManager.lobby:addPlayer(param.player)
  end)

  local onRequestGot = ctx:get("socketHelper").onRequestGot
  onRequestGot("FetchRoomList", function(player, data)
    return {}, nil
  end)
end

return M

-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local RoomManager = require("ktabletop.plugins.roomManager.room-manager")

---@type Plugin
local M = {
  name = "/ktabletop/server/roomManager",
  deps = { "/ktabletop/server/playerManager" },
}

function M.setup(ctx, config)
  local roomManager = RoomManager:new(ctx)
  ctx:serve("roomManager", roomManager)

  ctx:on("KTableTop::PlayerManager::NewConnection", function(param)
    roomManager.lobby:addPlayer(param.player)
  end)
end

return M

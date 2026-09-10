-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = ktabletop.class

-- Manages all game rooms running in this thread,
---@class GameThread: Object
local GameThread = class("GameThread")

function GameThread:initialize()
end

---@param roomId integer
---@param playerId integer
---@param command string
---@param data any
function GameThread:handleRequest(roomId, playerId, command, data)
  ktabletop.log.info(("HandleRequest: roomId=%d playerId=%d command=%s data=%s"):format(roomId, playerId, command, ktabletop.json.encode(data)))
end

return GameThread

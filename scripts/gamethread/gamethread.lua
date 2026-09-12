-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = ktabletop.class
local GameRoom = require "gamethread.room"

-- Manages all game contexts running in this thread,
---@class GameThread: Object
---@field contexts table<integer, GameRoom>
local GameThread = class("GameThread")

function GameThread:initialize()
  self.contexts = {}
end

---@param roomId integer
---@return GameRoom
function GameThread:registerContext(roomId)
  local context = GameRoom:new(roomId)
  self.contexts[roomId] = context
  return context
end

---@param roomId integer
function GameThread:removeContext(roomId)
  self.contexts[roomId] = nil
end

---@param roomId integer
---@param userId integer
---@param command string
---@param data any
function GameThread:handleRequest(roomId, userId, command, data)
  ktabletop.log.info(("HandleRequest: roomId=%d userId=%d command=%s data=%s"):format(roomId, userId, command, ktabletop.json.encode(data)))

  if command == "newroom" then
    self:registerContext(data.id):run()
  end
end

return GameThread

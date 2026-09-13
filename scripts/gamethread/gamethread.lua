-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = ktabletop.class

---@class GameThread: Object
---@field contexts table<integer, ServerGameContext>
local GameThread = class("GameThread")

function GameThread:initialize()
  self.contexts = {}
end

---@param boardgame BoardGame
---@param data table
---@return ServerGameContext
function GameThread:registerContext(boardgame, data)
  local context = boardgame.serverContextClass:new(data)
  self.contexts[data.id] = context
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
    local boardgame = ktabletop.boardgames:get("chess")
    self:registerContext(boardgame, data):run()
  end
end

return GameThread

-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local ServerRoomBase = require "server.room.roombase"
local GameLogic = require "gamethread.gamelogic"

---@class GameRoom: ServerRoomBase
---@field logic GameLogic?
---@field gameFinished boolean
local GameRoom = ServerRoomBase:subclass("GameRoom")

function GameRoom:initialize(roomId)
  ServerRoomBase.initialize(self)
  self.id = roomId
  self.gameFinished = false
end

function GameRoom:run()
  self.logic = GameLogic:new(self)
  self.logic:start()
end

function GameRoom:gameOver()
  if self.gameFinished then return end
  self.gameFinished = true

  ktabletop.log.info("GameOver")
  ktabletop.gamethread:removeContext(self.id)
  self.logic.root:shutdown()
end

return GameRoom

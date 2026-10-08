-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local async = require "corelib.async"
local class = kt.class
local GameEvent = require "gamethread.gameevent"

---@class GameLogic: Object
---@field ctx ServerGameContext
---@field root GameEvent
---@field gameEventStack GameEvent[]
---@field allGameEvents table<integer, any>
---@field eventRecorder table<any, GameEvent[]>
---@field currentEventId integer
local GameLogic = class("GameLogic")

function GameLogic:initialize(ctx)
  self.ctx = ctx

  self.gameEventStack = {}
  self.allGameEvents = {}
  self.eventRecorder = {}
  self.currentEventId = 0
end

---@param event GameEvent
function GameLogic:pushEvent(event)
  self.gameEventStack[#self.gameEventStack + 1] = event

  self.currentEventId = self.currentEventId + 1
  event.id = self.currentEventId
  self.allGameEvents[event.id] = event

  local key = event.class
  self.eventRecorder[key] = self.eventRecorder[key] or {}
  self.eventRecorder[key][#self.eventRecorder[key] + 1] = event
end

---@return GameEvent?
function GameLogic:popEvent()
  return table.remove(self.gameEventStack)
end

---@return GameEvent?
function GameLogic:getCurrentEvent()
  return self.gameEventStack[#self.gameEventStack]
end

---@return integer
function GameLogic:getCurrentEventDepth()
  return #self.gameEventStack
end

---@param eventType any
---@param includeSelf? boolean
---@return GameEvent?
function GameLogic:getMostRecentEvent(eventType, includeSelf)
  local current = self:getCurrentEvent()
  if not current then return nil end
  return current:findParent(eventType, includeSelf == nil and true or includeSelf)
end

---@return string
function GameLogic:dumpEventStack()
  local top = self:getCurrentEvent()

  local ret = "===== Start of event stack dump =====\n"
  while top do
    ret = ret .. tostring(top) .. "\n"
    top = top.parent
  end
  ret = ret .. "===== End of event stack dump =====\n"
  return ret
end

--- root event of game
local Game = GameEvent:subclass("GameEvent.Game")
function Game:main()
  self.ctx.logic:run()
end

function GameLogic:start()
  async.run(function()
    local root = Game:new(self.ctx)
    self.root = root
    self.ctx:broadcast("Room::StartGame", { gameType = self.ctx.gameType })
    local ok, errmsg = pcall(root.exec, root)
    local ctx = self.ctx
    if not ctx.gameFinished then
      -- root event may be killed by error?
      if not ok then
        kt.log.critical(errmsg)
      else
        kt.log.info("Game is over now because root event finished.")
      end
      ctx:gameOver()
    end
  end)
end

function GameLogic:run()
  kt.log.info("Hello, world!")
end

return GameLogic

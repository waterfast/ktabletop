-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local class = kt.class
local ServerGameContext = require "gamethread.game-context"

---@class GameThread: Object
---@field contexts table<integer, ServerGameContext>
---@field contextRegistry table<thread, ServerGameContext>
local GameThread = class("GameThread")

function GameThread:initialize()
  self.contexts = {}
  self.contextRegistry = setmetatable({}, { __mode = "k" })
end

---@param boardgame Boardgame
---@param data table
---@return ServerGameContext
function GameThread:registerContext(boardgame, data)
  local context = ServerGameContext:new(data, boardgame)
  self.contexts[data.id] = context
  return context
end

---@param roomId integer
function GameThread:removeContext(roomId)
  self.contexts[roomId] = nil
end

---@param co thread
---@param context ServerGameContext
function GameThread:bindCoroutineToContext(co, context)
  self.contextRegistry[co] = context
end

---@return GameContextBase
function GameThread:currentGameContext()
  return self.contextRegistry[coroutine.running()]
end

---@param roomId integer
---@param userId integer
---@param command string
---@param data any
function GameThread:handleRequest(roomId, userId, command, data)
  if command == "newroom" then
    local boardgame = kt.engine:getGame("chess")
    self:registerContext(boardgame, data):run()
    return
  end

  local ctx = self.contexts[roomId]
  if not ctx then return end
  local f = ctx.callbacks[command]
  if f then f(ctx, ctx:getPlayerById(userId), data) end
end

return GameThread

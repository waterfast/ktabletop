-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local LObject = require "corelib.lobject"
local async = require "corelib.async"

---@class GameViewModel: Object, LObject
---@field actionHandler table<string, fun(vm: GameViewModel, data: table, ret: any)>
local GameViewModel = kt.class("GameViewModel")
GameViewModel:include(LObject)

GameViewModel:Invokable("leaveGame")
GameViewModel:Invokable("leaveToRoom")
GameViewModel:Invokable("leaveToLobby")

function GameViewModel:initialize()
  self.actionHandler = {}
end

---@param name string
---@param fn fun(vm: GameViewModel, data: table, ret: any)
function GameViewModel:addActionHandler(name, fn)
  self.actionHandler[name] = fn
end

---@param name string
---@param data table
---@param ret any
function GameViewModel:onAction(name, data, ret)
  local handler = self.actionHandler[name]
  if handler then handler(self, data, ret) end
end

function GameViewModel:leaveGame()
  kt.client:leaveGame()
end

function GameViewModel:leaveToRoom()
  local client = kt.client
  local room = client.room
  if not room then return end

  client.gameContext = nil

  kt.c.luaEvent("Client::EnterRoom", {
    id = room.id,
    name = room.name,
    capacity = room.capacity,
    viewModelName = room.vm._stringId,
  })
end

function GameViewModel:leaveToLobby()
  local client = kt.client
  client.gameContext = nil

  async.run(function()
    client.myself:request("Room::Quit", {})
  end)
end

return GameViewModel

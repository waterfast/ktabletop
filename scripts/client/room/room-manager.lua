-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local ClientLobby = require "client.room.lobby"
local Commands = require "core.network-commands"

local async = require "corelib.async"

local class = ktabletop.class
local inspect = ktabletop.inspect

--- Handles the client-side lobby lifecycle.
---@class ClientRoomManager: Object
---@field lobby ClientLobby?
local ClientRoomManager = class("ClientRoomManager")

---@param client Client
function ClientRoomManager:initialize(client)
  self.client = client
  self.lobby = nil

  client:onNotificationGot(Commands.EnterLobby, async.async(function(data)
    self.lobby = ClientLobby:new()
    ktabletop.luaEvent("Client::PushLobby", {})

    local myself = client.playerManager.myself --[[ @as ClientPlayer ]]
    local uiHelper = client.uiHelper
    local reply = uiHelper:awaitRequest(myself, myself:asyncRequest(Commands.FetchRoomList), {
      cancellable = true,
      message = "Loading rooms..."
    })
    print("FetchRoomList reply", inspect(reply))
  end))

  client:onNotificationGot(Commands.UpdatePlayerNum, function(data)
    local lobby = self.lobby --[[ @as ClientLobby ]]
    lobby:setProperty("playerCount", data[1])
  end)
end

return ClientRoomManager

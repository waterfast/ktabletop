-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local ClientLobby = require "client.room.lobby"

local async = require "corelib.async"

local class = ktabletop.class
local inspect = ktabletop.inspect

---@class ClientRoomManager: Object
---@field lobby ClientLobby
local ClientRoomManager = class("ClientRoomManager")

---@param client Client
function ClientRoomManager:initialize(client)
  self.client = client
  self.lobby = nil

  client:onNotificationGot("EnterLobby", async.async(function(data)
    self.lobby = ClientLobby:new()
    ktabletop.luaEvent("Client::PushLobby", {})

    local myself = client.playerManager.myself --[[ @as ClientPlayer ]]
    local uiHelper = client.uiHelper
    local reply = uiHelper:awaitRequest(myself, myself:asyncRequest("FetchRoomList"), {
      cancellable = true,
      message = "Loading rooms..."
    })
    ktabletop.log.info("FetchRoomList reply", inspect(reply))
  end))

  client:onNotificationGot("UpdatePlayerNum", function(data)
    local lobby = self.lobby
    lobby:setProperty("playerCount", data[1])
  end)
end

return ClientRoomManager

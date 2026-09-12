-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local LObject = require "corelib.lobject"
local async = require "corelib.async"

---@class LobbyViewModel: Object, LObject
---@field userCount integer
---@field lobby ClientLobby
---@field myself ClientUser
local LobbyViewModel = ktabletop.class("LobbyViewModel")
LobbyViewModel:include(LObject)

LobbyViewModel:Property("userCount")
LobbyViewModel:Property("rooms")
LobbyViewModel:Property("selfId")
LobbyViewModel:Signal("chatMessage")

LobbyViewModel:Invokable("disconnectFromHost")
LobbyViewModel:Invokable("fetchRooms")
LobbyViewModel:Invokable("joinRoom")
LobbyViewModel:Invokable("createRoom")
LobbyViewModel:Invokable("sendChatMessage")

---@param lobby ClientLobby
function LobbyViewModel:initialize(lobby)
  self.lobby = lobby
  self.myself = ktabletop.client.myself

  self:setPropertyBinding("userCount", function()
    return self.lobby.userCount
  end)
  self:setPropertyBinding("rooms", function()
    return self.lobby.rooms
  end)
  self:setPropertyBinding("selfId", function()
    return self.myself.id
  end)
end

function LobbyViewModel:disconnectFromHost()
  ktabletop.luaEvent("Client::DisconnectFromHost", nil)
end

function LobbyViewModel:fetchRooms()
  async.async(function()
    local rooms = self.myself:request("Lobby::FetchRooms", {})
    table.sort(rooms, function(a, b) return a.id < b.id end)
    self.lobby.rooms = rooms
  end)()
end

function LobbyViewModel:joinRoom(roomId)
  async.async(function()
    self.myself:request("Room::Join", { id = roomId })
  end)()
end

function LobbyViewModel:createRoom(data)
  async.async(function()
    local p = self.myself
    local roomId = p:request("Room::Create", data)
    p:request("Room::Join", { id = roomId })
  end)()
end

function LobbyViewModel:sendChatMessage(text)
  async.async(function()
    self.myself:request("Room::Chat", { text = text })
  end)()
end

return LobbyViewModel

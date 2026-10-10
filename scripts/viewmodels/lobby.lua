-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local LObject = require "corelib.lobject"
local async = require "corelib.async"
local translateServerMessage = require "client.server-messages"

---@class LobbyViewModel: Object, LObject
---@field userCount integer
---@field lobby ClientLobby
---@field myself ClientUser
local LobbyViewModel = kt.class("LobbyViewModel")
LobbyViewModel:include(LObject)

LobbyViewModel:Property("userCount")
LobbyViewModel:Property("lobbyUsers")
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
  self.myself = kt.client.myself
  self.taskScope = async.newscope()

  self:setPropertyBinding("userCount", function()
    return self.lobby.userCount
  end)
  self:setPropertyBinding("lobbyUsers", function()
    return self.lobby.lobbyUsers
  end)
  self:setPropertyBinding("rooms", function()
    return self.lobby.rooms
  end)
  self:setPropertyBinding("selfId", function()
    return self.myself.id
  end)
end

function LobbyViewModel:disconnectFromHost()
  kt.c.luaEvent("Client::DisconnectFromHost", nil)
end

function LobbyViewModel:fetchRooms()
  self.taskScope:spawn(function()
    local rooms = self.myself:request("Lobby::FetchRooms", {})
    table.sort(rooms, function(a, b) return a.id < b.id end)
    self.lobby.rooms = rooms
  end)
end

function LobbyViewModel:joinRoom(roomId)
  self.taskScope:spawn(function()
    local _, err = self.myself:request("Room::Join", { id = roomId })
    if err then kt.c.showToast(translateServerMessage(err)) end
  end)
end

function LobbyViewModel:createRoom(data)
  self.taskScope:spawn(function()
    local p = self.myself
    local roomId, err = p:request("Room::Create", data)
    if err then
      kt.c.showToast(translateServerMessage(err))
      return
    end
    _, err = p:request("Room::Join", { id = roomId })
    if err then kt.c.showToast(translateServerMessage(err)) end
  end)
end

function LobbyViewModel:sendChatMessage(text)
  self.taskScope:spawn(function()
    local _, err = self.myself:request("Room::Chat", { text = text })
    if err then kt.c.showToast(translateServerMessage(err)) end
  end)
end

return LobbyViewModel

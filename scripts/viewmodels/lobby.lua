-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local LObject = require "corelib.lobject"
local async = require "corelib.async"
local tablib = ktabletop.tablib

---@class LobbyViewModel: Object, LObject
---@field userCount integer
local LobbyViewModel = ktabletop.class("LobbyViewModel")
LobbyViewModel:include(LObject)

LobbyViewModel:Property("userCount")
LobbyViewModel:Property("rooms")
LobbyViewModel:Property("selfId")
LobbyViewModel:Property("messages")

LobbyViewModel:Invokable("disconnectFromHost")
LobbyViewModel:Invokable("fetchRooms")
LobbyViewModel:Invokable("joinRoom")
LobbyViewModel:Invokable("createRoom")
LobbyViewModel:Invokable("sendChatMessage")

function LobbyViewModel:initialize()
  self:setPropertyBinding("userCount", function()
    return ktabletop.client.lobby.userCount
  end)
  self:setPropertyBinding("rooms", function()
    return ktabletop.client.lobby.rooms
  end)
  self:setPropertyBinding("selfId", function ()
    return ktabletop.client.myself.id
  end)
  self:setPropertyBinding("messages", function()
    return ktabletop.client.lobby.messages
  end)
end

function LobbyViewModel:disconnectFromHost()
  ktabletop.luaEvent("Client::DisconnectFromHost", nil)
end

function LobbyViewModel:fetchRooms()
  async.async(function()
    local rooms = ktabletop.client.myself:request("Lobby::FetchRooms", {})
    table.sort(rooms, function(a, b) return a.id < b.id end)
    ktabletop.client.lobby.rooms = rooms
  end)()
end

function LobbyViewModel:joinRoom(roomId)
  async.async(function()
    ktabletop.client.myself:request("Room::Join", { id = roomId })
  end)()
end

function LobbyViewModel:createRoom(data)
  async.async(function()
    local p = ktabletop.client.myself
    local roomId = p:request("Room::Create", data)
    p:request("Room::Join", { id = roomId })
  end)()
end

function LobbyViewModel:sendChatMessage(text)
  async.async(function()
    ktabletop.client.myself:request("Room::Chat", { text = text })
  end)()
end

return LobbyViewModel

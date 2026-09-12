local LObject = require "corelib.lobject"
local async = require "corelib.async"
local tablib = ktabletop.tablib

---@class WaitingRoomViewModel: Object, LObject
local WaitingRoomViewModel = ktabletop.class("WaitingRoomViewModel")
WaitingRoomViewModel:include(LObject)

WaitingRoomViewModel:Property("name")
WaitingRoomViewModel:Property("roomId")
WaitingRoomViewModel:Property("users")
WaitingRoomViewModel:Property("selfId")
WaitingRoomViewModel:Property("ownerId")
WaitingRoomViewModel:Property("capacity")
WaitingRoomViewModel:Property("messages")

WaitingRoomViewModel:Invokable("addRobot")
WaitingRoomViewModel:Invokable("startGame")
WaitingRoomViewModel:Invokable("quitRoom")
WaitingRoomViewModel:Invokable("sendChatMessage")

function WaitingRoomViewModel:initialize()
  self:setPropertyBinding("name", function()
    return ktabletop.client.room.name
  end)
  self:setPropertyBinding("roomId", function()
    return ktabletop.client.room.id
  end)
  self:setPropertyBinding("capacity", function()
    return ktabletop.client.room.capacity
  end)
  self:setPropertyBinding("users", function()
    return tablib.map(ktabletop.client.room.users, function(p)
      return { id = p.id, username = p.username }
    end)
  end)
  self:setPropertyBinding("selfId", function()
    return ktabletop.client.myself.id
  end)
  self:setPropertyBinding("ownerId", function()
    local owner = ktabletop.client.room.owner
    return owner and owner.id or -1
  end)
  self:setPropertyBinding("messages", function()
    return ktabletop.client.room and ktabletop.client.room.messages or {}
  end)
end

function WaitingRoomViewModel:addRobot()
  async.async(function()
    ktabletop.client.myself:request("Room::AddRobot", {})
  end)()
end

function WaitingRoomViewModel:startGame()
  async.async(function()
    ktabletop.client.myself:request("Room::StartGame", {})
  end)()
end

function WaitingRoomViewModel:quitRoom()
  async.async(function()
    ktabletop.client.myself:request("Room::Quit", {})
  end)()
end


function WaitingRoomViewModel:sendChatMessage(text)
  async.async(function()
    ktabletop.client.myself:request("Room::Chat", { text = text })
  end)()
end

return WaitingRoomViewModel

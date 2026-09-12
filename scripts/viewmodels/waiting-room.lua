local LObject = require "corelib.lobject"
local async = require "corelib.async"
local tablib = ktabletop.tablib

---@class WaitingRoomViewModel: Object, LObject
---@field room ClientRoom
local WaitingRoomViewModel = ktabletop.class("WaitingRoomViewModel")
WaitingRoomViewModel:include(LObject)

WaitingRoomViewModel:Property("name")
WaitingRoomViewModel:Property("roomId")
WaitingRoomViewModel:Property("users")
WaitingRoomViewModel:Property("selfId")
WaitingRoomViewModel:Property("ownerId")
WaitingRoomViewModel:Property("capacity")
WaitingRoomViewModel:Signal("chatMessage")

WaitingRoomViewModel:Invokable("addRobot")
WaitingRoomViewModel:Invokable("startGame")
WaitingRoomViewModel:Invokable("quitRoom")
WaitingRoomViewModel:Invokable("sendChatMessage")

---@param room ClientRoom
function WaitingRoomViewModel:initialize(room)
  self.room = room
  self.myself = ktabletop.client.myself

  self:setPropertyBinding("name", function()
    return self.room.name
  end)
  self:setPropertyBinding("roomId", function()
    return self.room.id
  end)
  self:setPropertyBinding("capacity", function()
    return self.room.capacity
  end)
  self:setPropertyBinding("users", function()
    return tablib.map(self.room.users, function(p)
      return { id = p.id, username = p.username }
    end)
  end)
  self:setPropertyBinding("selfId", function()
    return self.myself.id
  end)
  self:setPropertyBinding("ownerId", function()
    local owner = self.room.owner
    return owner and owner.id or -1
  end)
end

function WaitingRoomViewModel:addRobot()
  async.async(function()
    self.myself:request("Room::AddRobot", {})
  end)()
end

function WaitingRoomViewModel:startGame()
  async.async(function()
    self.myself:request("Room::StartGame", {})
  end)()
end

function WaitingRoomViewModel:quitRoom()
  async.async(function()
    self.myself:request("Room::Quit", {})
  end)()
end


function WaitingRoomViewModel:sendChatMessage(text)
  async.async(function()
    self.myself:request("Room::Chat", { text = text })
  end)()
end

return WaitingRoomViewModel

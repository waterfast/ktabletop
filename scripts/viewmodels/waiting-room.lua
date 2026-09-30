local LObject = require "corelib.lobject"
local async = require "corelib.async"
local translateServerMessage = require "client.server-messages"
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
WaitingRoomViewModel:Invokable("toggleReady")
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
      return { id = p.id, username = p.username, ready = p.ready }
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
  async.run(function()
    local _, err = self.myself:request("Room::AddRobot", {})
    if err then ktabletop.showToast(translateServerMessage(err)) end
  end)
end

function WaitingRoomViewModel:startGame()
  async.run(function()
    local _, err = self.myself:request("Room::StartGame", {})
    if err then ktabletop.showToast(translateServerMessage(err)) end
  end)
end

function WaitingRoomViewModel:quitRoom()
  async.run(function()
    self.myself:request("Room::Quit", {})
  end)
end

function WaitingRoomViewModel:toggleReady()
  async.run(function()
    local _, err = self.myself:request("Room::Ready", {})
    if err then ktabletop.showToast(translateServerMessage(err)) end
  end)
end


function WaitingRoomViewModel:sendChatMessage(text)
  async.run(function()
    local _, err = self.myself:request("Room::Chat", { text = text })
    if err then ktabletop.showToast(translateServerMessage(err)) end
  end)
end

return WaitingRoomViewModel

local LObject = require "corelib.lobject"
local async = require "corelib.async"
local tablib = ktabletop.tablib

---@class WaitingRoomViewModel: Object, LObject
local WaitingRoomViewModel = ktabletop.class("WaitingRoomViewModel")
WaitingRoomViewModel:include(LObject)

WaitingRoomViewModel:Property("name")
WaitingRoomViewModel:Property("roomId")
WaitingRoomViewModel:Property("players")
WaitingRoomViewModel:Property("selfId")
WaitingRoomViewModel:Property("ownerId")

WaitingRoomViewModel:Invokable("addRobot")
WaitingRoomViewModel:Invokable("startGame")
WaitingRoomViewModel:Invokable("quitRoom")

function WaitingRoomViewModel:initialize()
  self:setPropertyBinding("name", function()
    return ktabletop.client.room.name
  end)
  self:setPropertyBinding("roomId", function()
    return ktabletop.client.room.id
  end)
  self:setPropertyBinding("players", function()
    return tablib.map(ktabletop.client.room.players, function(p)
      return p.id
    end)
  end)
  self:setPropertyBinding("selfId", function()
    return ktabletop.client.myself.id
  end)
  self:setPropertyBinding("ownerId", function()
    local owner = ktabletop.client.room.owner
    return owner and owner.id or -1
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

return WaitingRoomViewModel

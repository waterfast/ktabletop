local LObject = require "corelib.lobject"
local async = require "corelib.async"
local tablib = ktabletop.tablib

---@class WaitingRoomViewModel: Object, LObject
local WaitingRoomViewModel = ktabletop.class("WaitingRoomViewModel")
WaitingRoomViewModel:include(LObject)

WaitingRoomViewModel:Property("players")
WaitingRoomViewModel:Property("ownerId")
WaitingRoomViewModel:Invokable("quitRoom")

function WaitingRoomViewModel:initialize()
  self:setPropertyBinding("players", function()
    return tablib.map(ktabletop.client.room.players, function(p)
      return p.id
    end)
  end)
  self:setPropertyBinding("ownerId", function()
    local owner = ktabletop.client.room.owner
    return owner and owner.id or -1
  end)
end

function WaitingRoomViewModel:quitRoom()
  async.async(function()
    ktabletop.client.myself:request("Room::Quit", {})
  end)()
end

return WaitingRoomViewModel


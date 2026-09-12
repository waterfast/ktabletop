local RoomBase = require "server.room.roombase"

---@class Lobby: ServerRoomBase
local Lobby = RoomBase:subclass("Lobby")

function Lobby:initialize()
  RoomBase.initialize(self)

  self.id = 0

  self:setRequestHandler("Lobby::FetchRooms", self.handleFetchRooms)
  self:setRequestHandler("Room::Create", self.handleCreateRoom)
  self:setRequestHandler("Room::Join", self.handleJoinRoom)
end

---@param user ServerUser
function Lobby:addUser(user)
  RoomBase.addUser(self, user)
  user:notify("Lobby::Enter", nil)
  self:updateOnlineInfo()
end

---@param user ServerUser
function Lobby:removeUser(user)
  RoomBase.removeUser(self, user)
  self:updateOnlineInfo()
end

function Lobby:updateOnlineInfo()
  self:broadcast("Lobby::UpdateOnlineInfo", {
    onlineUsers = #self.users,
  })
end

function Lobby:handleFetchRooms()
  local rm = ktabletop.server.roomManager
  local rooms = {}
  for _, room in pairs(rm.rooms) do
    rooms[#rooms + 1] = {
      id = room.id,
      name = room.name,
      capacity = room.capacity,
      userCount = #room.users,
      ownerId = room.owner and room.owner.id or -1,
    }
  end
  return rooms
end

function Lobby:handleCreateRoom(user, data)
  local rm = ktabletop.server.roomManager
  local room = rm:createRoom(user, data.name, data.capacity)
  if not room then
    return nil, "createRoom failed!"
  end

  return room.id
end

function Lobby:handleJoinRoom(user, data)
  local rm = ktabletop.server.roomManager
  local room = rm:findRoom(data.id)
  if not room then
    return nil, "no such room"
  end

  -- TODO: password check
  -- TODO: isOutdated check

  room:addUser(user)
  self:removeUser(user)
end

return Lobby

local RoomBase = require "server.room.roombase"
local tablib = ktabletop.tablib

---@class Room: ServerRoomBase
---@field owner ServerUser
---@field gameStarted boolean
local Room = RoomBase:subclass("Room")

local nextRoomId = 1

function Room:initialize()
  RoomBase.initialize(self)
  self.id = nextRoomId
  nextRoomId = nextRoomId + 1
  self.owner = nil
  self.name = ""
  self.capacity = 0
  self.gameStarted = false

  self:setRequestHandler("Room::AddRobot", self.handleAddRobot)
  self:setRequestHandler("Room::Quit", self.handleQuitRoom)
  self:setRequestHandler("Room::StartGame", self.handleStartGame)
end

function Room:isFull()
  return #self.users >= self.capacity
end

---@param user ServerUser
function Room:setOwner(user)
  self.owner = user
  self:broadcast("Room::Owner", { id = user.id })
end

---@param user ServerUser
function Room:addUser(user)
  if self:isFull() or self.gameStarted then
    user:notify("ErrorMsg", "Room is full or already started")
    return
  end

  self:broadcast("Room::AddUser", {
    id = user.id,
    username = user.username,
  })

  RoomBase.addUser(self, user)
  user:notify("Room::Enter", {
    id = self.id,
    name = self.name,
    capacity = self.capacity,
  })

  for _, p in ipairs(self.users) do
    if p ~= user then
      user:notify("Room::AddUser", {
        id = p.id,
        username = p.username,
      })
    end
  end

  -- TODO: observer


  if self.owner == nil then
    self:setOwner(user)
  else
    user:notify("Room::Owner", { id = self.owner.id })
  end
end

---@param user ServerUser
function Room:handleAddRobot(user)
  if self.owner ~= user then
    return nil, "you need to be room owner to add robot!"
  end

  if self:isFull() then
    return nil, "room is full!"
  end

  local robot = ktabletop.server.userManager:createRobot()
  self:addUser(robot)
end

---@param user ServerUser
function Room:handleStartGame(user)
  if user ~= self.owner then
    return nil, "you need to be room owner to start the game!"
  end

  if self.gameStarted then
    return nil, "game already started!"
  end

  if not self:isFull() then
    return nil, "room is not full!"
  end

  self.gameStarted = true

  local users = tablib.map(self.users, function(u)
    return { connId = u.connId, id = u.id, username = u.username }
  end)

  ktabletop.startGame(self.id, {
    id = self.id,
    name = self.name,
    capacity = self.capacity,
    users = users,
  })
end

---@param user ServerUser
function Room:handleQuitRoom(user)
  self:removeUser(user)

  -- TODO: check if is online
  local lobby = ktabletop.server.roomManager.lobby
  lobby:addUser(user)

  -- TODO: isOutdated
end

---@param user ServerUser
function Room:removeUser(user)
  if not RoomBase.removeUser(self, user) then
    return
  end

  self:broadcast("Room::RemoveUser", { id = user.id })

  if user == self.owner then
    if #self.users > 0 then
      self:setOwner(self.users[1])
    else
      self.owner = nil
    end
  end
end

return Room

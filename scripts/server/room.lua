local RoomBase = require "server.roombase"
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
  self:setRequestHandler("Room::Ready", self.handleReady)
end

function Room:isFull()
  return #self.users >= self.capacity
end

---@return boolean
function Room:allReady()
  for _, p in ipairs(self.users) do
    if p ~= self.owner and not p.ready then
      return false
    end
  end
  return true
end

---@param user ServerUser
function Room:setOwner(user)
  self.owner = user
  self:broadcast("Room::Owner", { id = user.id })
end

---@param user ServerUser
function Room:addUser(user)
  if self:isFull() or self.gameStarted then
    user:notify("App::ShowToast", "room.full")
    return
  end

  if user.state ~= "robot" then
    user.ready = false
  end
  self:broadcast("Room::AddUser", {
    id = user.id,
    username = user.username,
    ready = user.ready,
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
        ready = p.ready,
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
    return nil, "room.not_owner_add_robot"
  end

  if self:isFull() then
    return nil, "room.full"
  end

  local robot = ktabletop.server.userManager:createRobot()
  self:addUser(robot)
end

---@param user ServerUser
function Room:handleReady(user)
  user.ready = not user.ready
  self:broadcast("Room::ReadyChanged", {
    id = user.id,
    ready = user.ready,
  })
end

---@param user ServerUser
function Room:handleStartGame(user)
  if user ~= self.owner then
    return nil, "room.not_owner_start"
  end

  if self.gameStarted then
    return nil, "room.already_started"
  end

  if not self:isFull() then
    return nil, "room.not_full_start"
  end

  if not self:allReady() then
    return nil, "room.not_all_ready"
  end

  self.gameStarted = true

  for _, p in ipairs(self.users) do
    p.ready = (p == self.owner) or (p.state == "robot")
  end

  local users = tablib.map(self.users, function(u)
    return { connId = u.connId, id = u.id, username = u.username, state = u.state }
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

  if self:isAbandoned() then
    self:destroy()
  elseif user == self.owner then
    if #self.users > 0 then
      self:setOwner(self.users[1])
    else
      self.owner = nil
    end
  end
end

function Room:isAbandoned()
  return not tablib.find(self.users, function(p)
    return p.state == "online" or p.state == "trust"
  end)
end

function Room:destroy()
  local rm = ktabletop.server.roomManager
  local um = ktabletop.server.userManager

  rm:removeRoom(self.id)
  for _, p in ipairs(self.users) do
    if p.state == "online" or p.state == "trust" then
      self:removeUser(p)
      rm.lobby:addUser(p)
    else
      um:removeUser(p.connId)
    end
  end
end

return Room

-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

--- Contexts manage plugins and dispatch events, also used for storing values
---@class Context: Object
---@field private _parent Context?
local Context = class("Context")

---@param parent? Context
function Context:initialize(parent)
  self._parent = parent
  self._values = {}
  self._plugins = {}
  self._ifaces = {}
  self._listeners = {}
end

function Context:child()
  return Context:new(self)
end

function Context:__tostring()
  return "Context (plugins=[" .. table.concat(
    tablib.keys(self._plugins), ","
  ) .. "])"
end

-- Value read/write
-----------------------

function Context:set(key, value)
  self._values[key] = value
end

function Context:get(key, defaultRet)
  if self._values[key] ~= nil then
    return self._values[key]
  end
  if self._parent then
    return self._parent:get(key)
  end
  return defaultRet
end

--- Let the value usable by all contexts of the chain
function Context:serve(key, value)
  local tmp = self
  while tmp._parent ~= nil do
    tmp = tmp._parent
  end
  tmp:set(key, value)
end

-- Plugin manager
---------------------

--- Load a plugin
---@param plugin Plugin
function Context:loadPlugin(plugin)
  local name = plugin.name
  assert(name, "Plugin must have a name")
  assert(not self._plugins[name], "Plugin already loaded: " .. name)
  for _, iface in ipairs(plugin.ifaces or {}) do
    local owner = self._ifaces[iface]
    assert(not owner or owner == plugin, ("Interface already implemented: %s"):format(iface))
  end
  self._plugins[name] = plugin
  for _, iface in ipairs(plugin.ifaces or {}) do
    self._ifaces[iface] = plugin
  end
  if plugin.setup then
    plugin.setup(self)
  end
end

---@param pluginName string
function Context:unloadPlugin(pluginName)
  local plugin = self._plugins[pluginName]
  assert(plugin, "Plugin not loaded: " .. pluginName)
  if plugin.teardown then
    plugin.teardown(self)
  end
  for _, iface in ipairs(plugin.ifaces or {}) do
    self._ifaces[iface] = nil
  end
  self._plugins[pluginName] = nil
end

--- Find out an implementation of the interface
---@param iface string
function Context:getIFace(iface)
  if self._ifaces[iface] ~= nil then
    return self._ifaces[iface]
  end

  if self._parent then
    return self._parent:getIFace(iface)
  end

  return nil
end

-- Event listener
---------------------

---@param signalName string
function Context:emit(signalName, data)
  for _, callback in ipairs(self._listeners[signalName] or {}) do
    callback(data)
  end
end

---@param signalName string
---@param callback fun(data)
function Context:on(signalName, callback)
  local list = self._listeners[signalName]
  if not list then
    list = {}
    self._listeners[signalName] = list
  end
  list[#list + 1] = callback
end

-- Start and stop
--------------------

function Context:start()
  self:emit("KTabletop::Context::Start")
end

function Context:stop()
  self:emit("KTabletop::Context::Stop")
end

return Context

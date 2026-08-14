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
end

function Context:child()
  return Context:new(self)
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
end

---@param pluginName string
function Context:unloadPlugin(pluginName)
end

--- Find out an implementation of the interface
---@param iface string
function Context:getIFace(iface)
end

-- Event listener
---------------------

---@param signalName string
function Context:emit(signalName, data)
end

---@param signalName string
---@param callback fun(data)
function Context:on(signalName, callback)
end

-- Start and stop
--------------------

function Context:start()
end

function Context:stop()
end

return Context

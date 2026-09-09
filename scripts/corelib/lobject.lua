local class = ktabletop.class
local tablib = ktabletop.tablib

--==========================
-- Bindable property impl
--==========================

---@class _PropertyManager
local propertyManager = {
  current = nil, ---@type Property?
  _evalSet = {},
}

---@param prop Property
function propertyManager:evalProperty(prop)
  if self._evalSet[prop] then
    error(("property '%s': binding loop detected"):format(prop.name or "?"))
  end

  prop:clearDeps()

  local old = self.current
  self.current = prop
  self._evalSet[prop] = true
  local ok, newValue = pcall(prop.binding)
  self.current = old
  self._evalSet[prop] = nil

  if not ok then
    error(newValue)
  end

  local changed = (newValue ~= prop.data)
  prop.data = newValue
  prop.dirty = false
  return changed
end

---@param prop Property
function propertyManager:recordGetting(prop)
  local cur = self.current
  if not cur or cur == prop then return end
  cur:addDep(prop)
end

---@param prop Property
function propertyManager:propertyChanged(prop)
  for dep in pairs(prop.dependents) do
    dep.dirty = true
    if dep.binding then
      if self:evalProperty(dep) then
        self:propertyChanged(dep)
      end
    end
  end

  if prop.changedCallback then
    prop.changedCallback()
  end
end

--- Ref: https://doc.qt.io/qt-6/qproperty.html
---@class Property: Object
---@field name string
---@field data any
---@field binding (fun(): any)?
---@field changedCallback fun()?
---@field dirty boolean
---@field deps table<Property, boolean?>
local Property = class("Property")

---@param name string?
---@param value any
function Property:initialize(name, value)
  self.name = name or ""
  self.data = value
  self.binding = nil
  self.changedCallback = nil
  self.dirty = false
  self.deps = setmetatable({}, { __mode = "k" })
  self.dependents = setmetatable({}, { __mode = "k" })
end

function Property:setValue(v)
  self.binding = nil
  self.dirty = false
  if v == self.data then return end
  self.data = v
  propertyManager:propertyChanged(self)
end

function Property:value()
  if self.dirty and self.binding then
    if propertyManager:evalProperty(self) then
      propertyManager:propertyChanged(self)
    end
  end
  propertyManager:recordGetting(self)
  return self.data
end

function Property:setBinding(fn)
  if type(fn) ~= "function" then
    error("binding must be a function", 3)
  end
  self.binding = fn
  self.dirty = true
  if propertyManager:evalProperty(self) then
    propertyManager:propertyChanged(self)
  end
end

-- set changed callback.
function Property:onValueChanged(fn)
  self.changedCallback = fn
end

---@param prop Property
function Property:addDep(prop)
  if not self.deps[prop] then
    self.deps[prop] = true
    prop.dependents[self] = true
  end
end

function Property:clearDeps()
  for prop in pairs(self.deps) do
    prop.dependents[self] = nil
  end
  self.deps = setmetatable({}, { __mode = "k" })
end

--==========================
-- public part: LObject
--==========================

---@class PropertyOpts
---@field name string?
---@field defaultValue any

--- QObject-like class mixin. provides Q_PROPERTY and Q_INVOKABLE,
--- while don't rely on any Qt facilities. yes this is a pure-lua impl
--- Q_PROPERTY: define properties, support property binding and onChanged callbacks
--- Q_INVOKABLE: expose methods that are callable from QML side
---@class LObject
---@field _stringId string? required if this need to be exposed to C++
---@field private __props table<string, Property> instances
local LObject = {
  static = {},
}

function LObject:included(klass)
  klass.static.__properties = {}
  -- note: they don't support subclassing now
  klass.static.__invokables = {} -- callable from QML: invoke(method, params)
  klass.static.__signals = {} -- when called, call QML function onSignal
end

---@param name string
---@return PropertyOpts?
local function findPropertyDef(klass, name)
  while klass do
    local defs = klass.__properties
    if defs and defs[name] ~= nil then
      return defs[name]
    end
    klass = klass.super
  end
  return nil
end

---@return Property?
function LObject:_getProp(key)
  local props = rawget(self, "__props")
  if not props then
    props = {}
    rawset(self, "__props", props)
  end
  if not props[key] then
    local def = findPropertyDef(self.class, key)
    if not def then return nil end
    props[key] = Property:new(def.name, def.defaultValue)
  end
  return props[key]
end

-- Read property
function LObject:__index(k)
  local prop = self:_getProp(k)
  if prop ~= nil then
    return prop:value()
  end
  return rawget(self, k)
end

-- write property
function LObject:__newindex(k, v)
  local prop = self:_getProp(k)
  if prop ~= nil then
    prop:setValue(v)
  else
    rawset(self, k, v)
  end
end

---@param name string
---@param fn fun(): any
function LObject:setPropertyBinding(name, fn)
  local p = self:_getProp(name)
  if p then p:setBinding(fn) end
end


---@param name string
---@param fn fun(): any
function LObject:setPropertyOnValueChanged(name, fn)
  local p = self:_getProp(name)
  if p then p:onValueChanged(fn) end
end

---@param fn fun(k: string): any
function LObject:setOnValueChanged(fn)
  local klass = self.class
  while klass do
    local defs = klass.__properties
    for k in pairs(defs or {}) do
      self:_getProp(k):onValueChanged(function() return fn(k) end)
    end
    klass = klass.super
  end
end

-- use this after altering table-type properties
function LObject:notifyPropertyChanged(name)
  local p = self:_getProp(name)
  if p then propertyManager:propertyChanged(p) end
end

function LObject:emitSignal(sig, data)
  assert(self.class.__signals[sig], "Signals must be registered")
  ktabletop.luaEvent("LObject::Signal", {
    id = self._stringId,
    signal = sig,
    data = data,
  })
end

local reservedProperties = {
  -- Qt specific
  "id", "objectName", "parent",

  -- KTabletop internal
  "opts", "invoke", "signalEmitted", "onSignalEmitted", "refIndex",
}

---@param key string
function LObject.static:Property(key, opts)
  assert(not tablib.contains(reservedProperties, key), ("property name '%s' is reserved"):format(key))
  local t = self.static.__properties
  opts = opts or {}
  opts.name = key
  t[key] = opts
end

function LObject.static:Invokable(key)
  local t = self.static.__invokables
  t[key] = true
end

function LObject.static:Signal(key)
  local t = self.static.__signals
  t[key] = true
end

---@diagnostic disable

--- STATIC METHOD: register property to the class
---@param key string
---@param opts PropertyOpts?
function LObject:Property(key, opts)
  error("This is a static method, please call with <Class>:Property")
end

--- STATIC METHOD: register invokable to the class
---@param key string
function LObject:Invokable(key)
  error("This is a static method, please call with <Class>:Invokable")
end

--- STATIC METHOD: register signal to the class
---@param key string
function LObject:Signal(key)
  error("This is a static method, please call with <Class>:Signal")
end

---@diagnostic enable

function LObject:createCppObject()
  assert(self._stringId)
  local props, invokables, signals = {}, {}, {}
  local klass = self.class
  while klass do
    for k in pairs(klass.__properties or {}) do
      props[k] = self[k]
    end
    for k in pairs(klass.__invokables or {}) do
      invokables[#invokables + 1] = k
    end
    for k in pairs(klass.__signals or {}) do
      signals[#signals + 1] = k
    end
    klass = klass.super
  end

  self:setOnValueChanged(function(k)
    ktabletop.luaEvent("LObject::ValueChanged", {
      id = self._stringId,
      key = k,
      value = self[k],
    })
  end)

  return {
    id = self._stringId,
    props = props,
    invokables = invokables,
    signals = signals,
  }
end

return LObject

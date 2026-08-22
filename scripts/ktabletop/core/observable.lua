-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

---@class Observable
---@field _stringId string
local Observable = {
  static = {}
}

function Observable:setProperty(key, value)
  local oldValue = self[key]
  self[key] = value
  if type(value) == "table" or oldValue ~= value then
    -- TODO: need more discussion here
    -- as we can see, this assumes base class has `_stringId` and `ctx` field
    self.ctx:get("__cpp.common").luaEvent("KTableTop::Observable::ValueChanged", {
      _stringId = self._stringId,
      key = key,
      value = value,
    })
  end
end

function Observable:getPropertyMap()
  local ret = {
    _stringId = self._stringId
  }
  for _, k in ipairs(self.class.static.__observableProperties) do
    ret[k] = self[k]
  end
  return ret
end

function Observable:createObserveObject()
  local cpp = self.ctx:get("__cpp.common")
  cpp.luaEvent("KTableTop::Observable::NewObject", self:getPropertyMap())
end

---@param key string
function Observable.static:registerProperty(key)
  local t = self.static.__observableProperties
  t[#t + 1] = key
end

function Observable:included(klass)
  klass.static.__observableProperties = {}
end

return Observable

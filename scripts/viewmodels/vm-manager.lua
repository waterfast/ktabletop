local class = ktabletop.class

---@class ViewModelManager: Object
local ViewModelManager = class("ViewModelManager")

function ViewModelManager:initialize()
  self._types = {}
  self._instances = {}
  self._nextId = 1
end

---@param name string
---@param klass Object
function ViewModelManager:registerType(name, klass)
  self._types[name] = klass
end

--- Get view model from opts
--- if objectName specified, return existing one
--- otherwise create new one, type should be registered into this manager
---@param opts {
---   objectName: string?,
---   type: string?,
---   params: any[]?,
--- }
---@return LObject?
function ViewModelManager:getViewModel(opts)
  assert(type(opts) == "table", "opts must be a table")

  local objectName = opts.objectName
  if objectName then
    return self._instances[objectName]
  end

  assert(opts.type, "opts must contain a 'type'")
  local klass = self._types[opts.type]
  assert(klass, ("view model type '%s' is not registered"):format(tostring(opts.type)))

  local obj = klass:new(table.unpack(opts.params or {}))
  objectName = ("%s_%d"):format(klass.name, self._nextId)
  self._nextId = self._nextId + 1

  obj._stringId = objectName
  self._instances[objectName] = obj
  return obj
end

---@param obj LObject
function ViewModelManager:removeViewModel(obj)
  self._instances[obj._stringId] = nil
end

return ViewModelManager

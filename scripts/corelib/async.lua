-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- Async lib for KTabletop.
-- Build on top of Qt event loop, but can be easily moved to other event loop system.
-- Can wrap Boost-style async functions, that is, have a callback as its last param
--   which looks like `fun(errCode, value)`.
-- Reference: GameEvent system from `Freekill'.

local co = coroutine
local unpack = table.unpack or unpack

-- private markers
local ASYNC = { "ASYNC" }
local AWAIT = { "AWAIT" }

local CANCELED = "Operation canceled"

-- AsyncScheduler handles results yielded from an async function.
-- async functions should be started from main coroutine.
local scheduler = {
  coroutineMap = setmetatable({}, { __mode = "k" }),
}

---@param fn AsyncFunction
function scheduler:add(fn)
  self.coroutineMap[fn.coro] = fn
end

---@param fn AsyncFunction
function scheduler:start(fn)
  assert(type(fn) == "table" and fn[ASYNC], "must be AsyncFunction")
  self:add(fn)
  fn.state = "running"
  return self:resume(fn, unpack(fn.args, 1, fn.args.n))
end

---@param fn AsyncFunction
function scheduler:resume(fn, ...)
  local coro = fn.coro

  -- when trying to resume a canceled function, finish it immediately
  if fn.cancelled then
    fn.state, fn.errmsg = "error", CANCELED
    local status = co.status(coro)
    if status == "dead" then
      return
    elseif status == "suspended" then
      co.close(coro)
    end
    return self:finish(fn)
  end

  -- fn usually call async.await inside it.
  -- awaiting something or finishing exection will make co.resume return.
  local pack = table.pack(co.resume(coro, ...))
  local status = co.status(coro)
  local ok = pack[1]
  local ret = pack[2]

  if status == "dead" then
    if not ok then
      fn.state, fn.errmsg = "error", pack[2]
    else
      fn.state = "done"
      fn.results = table.pack(table.unpack(pack, 2, pack.n))
    end
    return self:finish(fn)
  end

  assert(ret[ASYNC] or ret == AWAIT, "unexpected yield result " .. tostring(ret))
  if ret[ASYNC] then
    return self:start(ret)
  end
end

-- await on an AsyncFunction or Awaitable
-- return true and callback results, or false plus error message
---@param fn AsyncFunction|CppAsyncFunction
---@return boolean, ...
function scheduler:await(fn, ...)
  local current = co.running()
  local f = self.coroutineMap[current]
  assert(f, "cannot await outside async function")
  if f.cancelled then
    return false, CANCELED
  end
  if not (type(fn) == "table" and (fn[ASYNC] or fn[AWAIT])) then
    -- accidentally await on normal functions; return
    return true, fn, ...
  end

  f.callee = fn

  -- they will yield to scheduler:resume().
  if fn[ASYNC] then
    -- will be resumed by scheduler:finish(fn).
    return co.yield(fn)
  else
    -- Slot function might be called immediately.
    local yielded = false
    local syncResults
    local callback = function(err, ...)
      local ok = not err
      if yielded then
        f.callee = nil
        self:resume(f, ok, err, ...)
      else
        syncResults = table.pack(ok, err, ...)
      end
    end
    -- equals to call C++ function async_something(...args, callback)
    fn(callback)

    if syncResults ~= nil then
      f.callee = nil
      return unpack(syncResults, 1, syncResults.n)
    end
    yielded = true
    -- will be resumed by callback.
    return co.yield(AWAIT)
  end
end

---@param fn AsyncFunction
function scheduler:finish(fn)
  self.coroutineMap[fn.coro] = nil
  local a = fn.caller
  -- calling async function in sync code like async.async(func)()
  if not a then
    if fn.state == "done" then
      return unpack(fn.results, 1, fn.results.n)
    elseif fn.cancelled then
      return nil
    else
      error(fn.errmsg)
    end
  end

  -- async.await(func(...)); resume exection of my caller
  ---@cast a -nil
  a.callee = nil
  if fn.state == "done" then
    self:resume(a, true, unpack(fn.results, 1, fn.results.n))
  else
    local errmsg = fn.errmsg
    if not fn.cancelled then
      errmsg = debug.traceback(fn.coro, errmsg)
    end
    self:resume(a, false, errmsg)
  end
end

---@param fn AsyncFunction|CppAsyncFunction
function scheduler:cancel(fn)
  if type(fn) ~= "table" or not (fn[ASYNC] or fn[AWAIT]) then
    return
  end
  if fn.cancelled then return end
  fn.cancelled = true
  -- cancel all callees recursively
  if fn.callee then
    self:cancel(fn.callee)
    fn.callee = nil
  end

  if fn[ASYNC] then
    if co.running() == fn.coro then
      -- will make co.resume return false, CANCELED
      error(CANCELED)
    end
  elseif fn[AWAIT] and type(fn.completionToken) == "function" then
    fn.completionToken(CANCELED)
  end
end

-- Async functions is implemented with a table containing __call metamethod.
-- That table contains useful field for other async related stuff.

--- A running async function.
---@class AsyncFunction
---@field coro thread
---@field args table
---@field state "pending"|"running"|"done"|"error"
---@field results any[]
---@field errmsg string?
---@field caller AsyncFunction?
---@field callee AsyncFunction?
---@field cancelled boolean?
local AsyncFunction = {}
AsyncFunction.__index = AsyncFunction

function AsyncFunction.new(fn, args)
  local current = co.running()
  return setmetatable({
    [ASYNC] = true,
    coro = co.create(fn),
    args = args,
    caller = scheduler.coroutineMap[current],
    state = "pending",
  }, AsyncFunction)
end

function AsyncFunction:__call()
  return scheduler:start(self)
end

---@class AsyncFunctionFactory
---@field fn fun(...): any
local AsyncFunctionFactory = {}
AsyncFunctionFactory.__index = AsyncFunctionFactory

function AsyncFunctionFactory.new(fn)
  return setmetatable({
    fn = fn,
  }, AsyncFunctionFactory)
end

function AsyncFunctionFactory:__call(...args)
  local f = AsyncFunction.new(self.fn, args)
  local current = co.running()
  local fn = scheduler.coroutineMap[current]
  -- When calling a async function in sync code, running immediately until return or await.
  if not fn then
    return f()
  end
  return f
end

---@class CppAsyncFunction
---@field fn fun(...)
---@field args table
---@field completionToken fun(err, ...)
---@field cancelled boolean?
local CppAsyncFunction = {}
CppAsyncFunction.__index = CppAsyncFunction

function CppAsyncFunction:__call(cb)
  local args = self.args
  local fn = self.fn
  args.n = args.n + 1
  args[args.n] = cb
  local packed = table.pack(fn(unpack(args, 1, args.n)))
  self.completionToken = packed[1]
end

-- usage: async(function() ... end)
-- creates an asyncFunctionFactory.
---@param fn fun(...): any
---@return fun(...): any
local async = function(fn)
  ---@diagnostic disable-next-line
  return AsyncFunctionFactory.new(fn)
end

--- await for another async func, or wrapped awaitable func.
---@param fn AsyncFunction
local await = function(fn)
  return scheduler:await(fn)
end

--- cancel an async execution and everything it awaits down the chain.
---@param fn AsyncFunction
local cancel = function(fn)
  scheduler:cancel(fn)
end

-- use with function that with callback as last param
-- fn should return immediately
local wrap = function(fn)
  return function(...args)
    return setmetatable({
      [AWAIT] = true,
      fn = fn,
      args = args,
    }, CppAsyncFunction)
  end
end

return {
  async = async,
  await = await,
  wrap = wrap,
  cancel = cancel,
}

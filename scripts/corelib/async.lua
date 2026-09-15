-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- Async lib for KTabletop. For Lua 5.5
-- Build on top of Qt event loop, but can be easily moved to other event loop system.
-- Can wrap Boost-style async functions, that is, have a callback as its last param
--   which looks like `fun(errCode, value)`.
-- Reference: GameEvent system from `Freekill'.

local co = coroutine
local unpack = table.unpack
local pack = table.pack

-- private markers
local ASYNC = { "ASYNC" }
local AWAIT = { "AWAIT" }

local CANCELLED = "Operation canceled"

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
    fn.state, fn.errmsg = "error", CANCELLED
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
  local packed = pack(co.resume(coro, ...))
  local status = co.status(coro)
  local ok = packed[1]
  local ret = packed[2]

  if status == "dead" then
    if not ok then
      fn.state, fn.errmsg = "error", packed[2]
    else
      fn.state = "done"
      fn.results = pack(unpack(packed, 2, packed.n))
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
    return false, CANCELLED
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
    local callback = function(err, ret)
      if yielded then
        f.callee = nil
        return self:resume(f, not err, err or ret)
      else
        syncResults = { not err, err or ret }
      end
    end
    -- equals to call C++ function async_something(...args, callback)
    fn(callback)

    if syncResults ~= nil then
      f.callee = nil
      return unpack(syncResults)
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
  -- calling async function in sync code like async.run(func, ...)
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
    return self:resume(a, true, unpack(fn.results, 1, fn.results.n))
  else
    local errmsg = fn.errmsg
    if not fn.cancelled then
      errmsg = debug.traceback(fn.coro, errmsg)
    end
    return self:resume(a, false, errmsg)
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
      -- will make co.resume return false, CANCELLED
      error(CANCELLED)
    end
  elseif fn[AWAIT] and type(fn.cancelFunc) == "function" then
    fn.cancelFunc(CANCELLED)
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
---@field cancelFunc fun(err, ...)
---@field cancelled boolean?
local CppAsyncFunction = {}
CppAsyncFunction.__index = CppAsyncFunction

function CppAsyncFunction:__call(cb)
  local args = self.args
  local fn = self.fn
  args.n = args.n + 1
  args[args.n] = cb
  local packed = pack(fn(unpack(args, 1, args.n)))
  self.cancelFunc = packed[1]
end

--------------------------------------------------------------

local M = {
  CANCELLED = CANCELLED,
}

-- usage: async(function() ... end)
-- creates an asyncFunctionFactory.
---@param fn fun(...): any
---@return fun(...): any
function M.async(fn)
  ---@diagnostic disable-next-line
  return AsyncFunctionFactory.new(fn)
end

--- start an async function from sync context.
---@param fn fun(...): any
function M.run(fn, ...)
  return M.async(fn)(...)
end

--- await for another async func, or wrapped awaitable func.
---@param fn AsyncFunction|CppAsyncFunction
function M.await(fn)
  return scheduler:await(fn)
end

--- cancel an async execution and everything it awaits down the chain.
---@param fn AsyncFunction|CppAsyncFunction
function M.cancel(fn)
  return scheduler:cancel(fn)
end

-- use with function that with callback as last param
-- fn should return immediately
function M.wrap(fn)
  return function(...args)
    return setmetatable({
      [AWAIT] = true,
      fn = fn,
      args = args,
    }, CppAsyncFunction)
  end
end

return M

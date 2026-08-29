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
  return self:resume(fn, unpack(fn.args, 1, fn.args.n))
end

---@param fn AsyncFunction
function scheduler:resume(fn, ...)
  local coro = fn.coro

  -- 1. yield a new AsyncFunction
  -- 2. yield AWAIT; co.yield myself and wait the callback wakeup me
  -- 3. coro is dead: yield return values of fn
  -- 4. pack[1] == false; killed by error
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

  -- comment them will not change anything
  -- if ret[AWAIT] then
  --   return
  -- end
end

-- await on an AsyncFunction or Awaitable
-- return true and callback results, or false plus error message
---@return boolean, ...
function scheduler:await(fn, ...)
  local current = co.running()
  local f = self.coroutineMap[current]
  assert(f, "cannot await outside async function")
  if not (type(fn) == "table" and (fn[ASYNC] or fn[AWAIT])) then
    -- accidentally await on normal functions; return
    return true, fn, ...
  end

  if fn[ASYNC] then
    return co.yield(fn)
  else
    -- C++ note: callback must be called from main coroutine. But it can also
    -- be invoked synchronously (re-entrantly, e.g. a Qt signal emitted inside
    -- a `co.resume`); in that case the work is already done, so just return
    -- its results instead of yielding.
    local yielded = false
    local syncResults
    fn(function(err, ...)
      local ok = not err
      if yielded then
        self:resume(f, ok, err, ...)
      else
        syncResults = table.pack(ok, err, ...)
      end
    end)
    if syncResults ~= nil then
      return unpack(syncResults, 1, syncResults.n)
    end
    yielded = true
    return co.yield(AWAIT)
  end
end

---@param fn AsyncFunction
function scheduler:finish(fn)
  self.coroutineMap[fn.coro] = nil
  local a = fn.caller
  if not a then
    if fn.state == "done" then
      return unpack(fn.results, 1, fn.results.n)
    else
      error(fn.errmsg)
    end
  end
  fn.caller = nil
  if fn.state == "done" then
    self:resume(a, true, unpack(fn.results, 1, fn.results.n))
  else
    self:resume(a, false, fn.errmsg)
  end
end

-- Async functions is implemented with a table containing __call metamethod.
-- That table contains useful field for other async related stuff.

--- A running async function.
---@class AsyncFunction
---@field coro thread
---@field args table
---@field state "pending"|"done"|"error"
---@field results any[]
---@field errmsg string?
---@field caller AsyncFunction?
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

-- use with function that with callback as last param
-- fn should return immediately
local wrap = function(fn)
  return function(...args)
    local awaitable
    awaitable = setmetatable({
      [AWAIT] = true,
    }, {
      __call = function(_, cb)
        args.n = args.n + 1
        args[args.n] = cb
        awaitable.syncResult = table.pack(fn(unpack(args, 1, args.n)))
      end
    })
    return awaitable
  end
end

return {
  async = async,
  await = await,
  wrap = wrap,
}

require "ktabletop.ktabletop"
local Context = require "ktabletop.core.context"
local BusyState = require "ktabletop.core.busy-state"

local function newBusyState()
  local ctx = Context:new()
  local luaEvents = {}

  ctx:set("__cpp.common", {
    luaEvent = function(type_, payload) luaEvents[#luaEvents + 1] = { type_, payload }  end,
  })

  return BusyState:new(ctx), ctx
end

describe("BusyState", function()
  it("starts idle", function()
    local busy = newBusyState()
    assert.are.equal(0, busy.count)
    assert.is_false(busy.blocking)
    assert.is_false(busy.cancellable)
  end)

  it("tracks a simple blocking operation by default", function()
    local busy = newBusyState()
    local finish = busy:begin()
    assert.are.equal(1, busy.count)
    assert.is_true(busy.blocking)

    finish()
    assert.are.equal(0, busy.count)
    assert.is_false(busy.blocking)
  end)

  it("does not block when blocking = false", function()
    local busy = newBusyState()
    local finish = busy:begin({ blocking = false })
    assert.are.equal(1, busy.count)
    assert.is_false(busy.blocking)
    finish()
  end)

  it("keeps blocking true while any concurrent op still wants it", function()
    local busy = newBusyState()
    local finishA = busy:begin({ blocking = true })
    local finishB = busy:begin({ blocking = false })

    assert.is_true(busy.blocking)
    finishB()
    assert.is_true(busy.blocking)
    finishA()
    assert.is_false(busy.blocking)
  end)

  it("is idempotent when finish is called twice", function()
    local busy = newBusyState()
    local finish = busy:begin()
    finish()
    finish()
    assert.are.equal(0, busy.count)
  end)

  it("exposes cancellable and calls onCancel", function()
    local busy = newBusyState()
    local cancelled = false
    local finish = busy:begin({ cancellable = true, onCancel = function() cancelled = true end })

    assert.is_true(busy.cancellable)
    busy:cancel()
    assert.is_true(cancelled)

    finish()
    assert.is_false(busy.cancellable)
  end)

  it("cancels the most recently started cancellable operation", function()
    local busy = newBusyState()
    local calls = {}
    local finishA = busy:begin({ cancellable = true, onCancel = function() calls[#calls + 1] = "A" end })
    local finishB = busy:begin({ cancellable = true, onCancel = function() calls[#calls + 1] = "B" end })

    busy:cancel()
    assert.are.same({ "B" }, calls)

    finishB()
    finishA()
  end)
end)
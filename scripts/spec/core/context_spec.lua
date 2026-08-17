-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

require "ktabletop.ktabletop"
local Context = require "ktabletop.core.context"

describe("Context", function()
  local ctx

  before_each(function()
    ctx = Context:new()
  end)

  describe("value storage", function()
    it("sets and gets a value", function()
      ctx:set("key", "value")
      assert.are.equal("value", ctx:get("key"))
    end)

    it("returns nil for a missing key", function()
      assert.is_nil(ctx:get("missing"))
    end)

    it("returns the default for a missing key", function()
      assert.are.equal("default", ctx:get("missing", "default"))
    end)

    it("treats setting a nil value as unset", function()
      ctx:set("key", "value")
      ctx:set("key", nil)
      assert.are.equal("default", ctx:get("key", "default"))
    end)
  end)

  describe("child contexts", function()
    it("creates a child context", function()
      local child = ctx:child()
      assert.is_true(child:isInstanceOf(Context))
      assert.is_not(ctx, child)
    end)

    it("falls back to the parent for missing values", function()
      ctx:set("key", "parent")
      local child = ctx:child()
      assert.are.equal("parent", child:get("key"))
    end)

    it("does not write through to the parent", function()
      local child = ctx:child()
      child:set("key", "child")
      assert.is_nil(ctx:get("key"))
      assert.are.equal("child", child:get("key"))
    end)

    it("chains through multiple levels", function()
      ctx:set("key", "root")
      local child = ctx:child()
      local grandchild = child:child()
      assert.are.equal("root", grandchild:get("key"))
    end)
  end)

  describe("serve", function()
    it("sets the value at the root context", function()
      local child = ctx:child():child()
      child:serve("key", "rooted")
      assert.are.equal("rooted", ctx:get("key"))
      assert.are.equal("rooted", child:get("key"))
    end)
  end)

  describe("plugin manager", function()
    local function makePlugin()
      return {
        name = "/org/example/test",
        deps = {},
        optionalDeps = {},
        ifaces = { "org.example.test.Interface" },
        setup = function(self, pluginCtx) self.pluginCtx = pluginCtx end,
      }
    end

    it("loads a plugin and exposes its interface", function()
      local plugin = makePlugin()
      ctx:loadPlugin(plugin)
      assert.are.equal(plugin, ctx:getIFace("org.example.test.Interface"))
    end)

    it("calls setup with the context on load", function()
      local plugin = makePlugin()
      ctx:loadPlugin(plugin)
      assert.are.equal(ctx, plugin.pluginCtx)
    end)

    it("returns nil for an unknown interface", function()
      assert.is_nil(ctx:getIFace("org.example.nope.Interface"))
    end)

    it("unloads a plugin and its interfaces", function()
      local plugin = makePlugin()
      ctx:loadPlugin(plugin)
      ctx:unloadPlugin(plugin.name)
      assert.is_nil(ctx:getIFace("org.example.test.Interface"))
    end)

    it("fails when loading a plugin without a name", function()
      assert.has_error(function()
        ctx:loadPlugin({ ifaces = {} })
      end)
    end)

    it("fails when loading the same plugin twice", function()
      local plugin = makePlugin()
      ctx:loadPlugin(plugin)
      assert.has_error(function()
        ctx:loadPlugin(plugin)
      end)
    end)

    it("fails when an interface is already implemented by another plugin", function()
      local pluginA = makePlugin()
      local pluginB = makePlugin()
      pluginB.name = "/org/example/test2"
      ctx:loadPlugin(pluginA)
      assert.has_error(function()
        ctx:loadPlugin(pluginB)
      end)
    end)

    it("allows loading another plugin after the owner unloads", function()
      local pluginA = makePlugin()
      local pluginB = makePlugin()
      pluginB.name = "/org/example/test2"
      ctx:loadPlugin(pluginA)
      ctx:unloadPlugin(pluginA.name)
      ctx:loadPlugin(pluginB)
      assert.are.equal(pluginB, ctx:getIFace("org.example.test.Interface"))
    end)

    it("fails when unloading an unknown plugin", function()
      assert.has_error(function()
        ctx:unloadPlugin("/org/example/nope")
      end)
    end)
  end)

  describe("event listener", function()
    it("calls the callback on emit", function()
      local received
      ctx:on("signal", function(data) received = data end)
      ctx:emit("signal", "payload")
      assert.are.equal("payload", received)
    end)

    it("calls all callbacks registered for a signal", function()
      local count = 0
      ctx:on("signal", function() count = count + 1 end)
      ctx:on("signal", function() count = count + 1 end)
      ctx:emit("signal")
      assert.are.equal(2, count)
    end)

    it("does not call callbacks of other signals", function()
      local called = false
      ctx:on("other", function() called = true end)
      ctx:emit("signal")
      assert.is_false(called)
    end)

    it("does nothing when emitting an unlistened signal", function()
      assert.is_nil(ctx:emit("unlistened"))
    end)

    it("emits start and stop signals", function()
      local started = false
      local stopped = false
      ctx:on("KTableTop::Context::Start", function() started = true end)
      ctx:on("KTableTop::Context::Stop", function() stopped = true end)
      ctx:start()
      ctx:stop()
      assert.is_true(started)
      assert.is_true(stopped)
    end)
  end)
end)

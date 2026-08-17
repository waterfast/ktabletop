require "ktabletop.ktabletop"
local Context = require "ktabletop.core.context"

local ctx = Context:new()

ctx:loadPlugin {
  name = "/ktabletop/test",
  setup = function(ctx, config)
    ctx:on("KTableTop::Context::Start", function ()
      print("Client plugin started... I want to listen on some QML signals!")
    end)
  end,
}

ctx:start()

MainContext = ctx

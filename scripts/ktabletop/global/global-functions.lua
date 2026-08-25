-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

Emit = function(sig, param)
  MainContext:emit(sig, param)
  print("Emit finished", coroutine.running())
end

LoadPlugin = function(plugin)
  MainContext:loadPlugin(plugin)
end

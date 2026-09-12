-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

local registry = setmetatable({}, { __mode = "k" })

local M = {}

---@param co thread
---@param context GameContextBase
function M.bind(co, context)
  registry[co] = context
end

---@return GameContextBase?
function M.current()
  return registry[coroutine.running()]
end

return M

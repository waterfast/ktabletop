-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- No need to require this file.
do return end

---@meta

-- Below shows how to write an plugin...

-- Just annotations that describes format of a plugin
-- Plugin itself is a regular table
---@class Plugin
---@field name string Name looks like a DBus object: /org/example/myplugin
---@field deps? string[] interfaces depended by the plugin
---@field optionalDeps? string[]
---@field ifaces? string[] interfaces the plugin implements and exports
local M = {}

---@param ctx Context
---@param config any
function M.setup(ctx, config)
end

return M

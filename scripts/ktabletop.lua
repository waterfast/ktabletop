-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- script executed before entering client or server script PWD should be `scripts/`

-- The `ktabletop` table is created by C++ (luaopen_ktabletop) and already holds
-- the C++ backend functions. Here we extend it with the Lua-side libraries, so
-- the global scope only gains `ktabletop` itself.

ktabletop.json = require "3rdparty.json"
ktabletop.class = require "3rdparty.middleclass"
ktabletop.inspect = require "3rdparty.inspect"

ktabletop.tablib = require "corelib.tablib"
ktabletop.strlib = require "corelib.strlib"

-- I think that're all preparations to do?
do return end

-- Code below are pseudo codes telling LSP how does middleclass work

---@meta

---@class class
---@field public static any
--- middleclass
local class = {}

---@param cls class|Object
---@return boolean
function class:isSubclassOf(cls) end

---@class Object
---@field public class class
local Object = { static = {} }

---@generic T
---@param self T
function Object:initialize(...) end

---@generic T
---@param self T
---@return T
function Object:new(...)end

---@generic T
---@param self T
---@param name string
---@return T
function Object:subclass(name)end

---@param cls class|Object
---@return boolean
function Object:isInstanceOf(cls) end

---@param cls class|Object
---@return boolean
function Object:isSubclassOf(cls) end

function Object:include(e) end

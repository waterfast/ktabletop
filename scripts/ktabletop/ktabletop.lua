-- SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
-- SPDX-License-Identifier: LGPL-2.1-or-later

-- script executed before entering client or server script
-- PWD should be `scripts/`

-- load libraries as global variable
-- Note: we must avoid globals as much as possible.

json = require "3rdparty.json"
class = require "3rdparty.middleclass"
inspect = require "3rdparty.inspect"

-- These will be used very frequently too, making it global should make sense
tablib = require "ktabletop.global.tablib"

-- for c++ (Lua::call needs global function)
require "ktabletop.global.global-functions"

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

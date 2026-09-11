// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "async-context.h"
#include "lua/c-wrapper.h"
#include "lua/lua-binding.h"

#include <lua.hpp>

AsyncContext::AsyncContext(LuaBinding *parent, int callback)
    : QObject(parent)
    , m_binding(parent)
    , m_callback(callback)
{
}

void AsyncContext::completeVoid()
{
    complete();
}

void AsyncContext::complete(std::error_code err, QVariant val)
{
    if (m_callback == LUA_NOREF) {
        return;
    }

    auto *L = m_binding->state();
    int ref = m_callback;
    m_callback = LUA_NOREF;

    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    QVariant errVal = err ? QString::fromStdString(err.message()) : QVariant::fromValue(nullptr);
    if (!val.isValid()) {
        val = QVariant::fromValue(nullptr);
    }
    LuaVM::call(L, {errVal, val});
    luaL_unref(L, LUA_REGISTRYINDEX, ref);

    deleteLater();
}

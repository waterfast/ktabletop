// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua-binding.h"
#include "c-wrapper.h"

#include <QDir>
#include <QString>

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

#include <lua.hpp>

static QHash<lua_State *, LuaBinding *> bindingInstances;

LuaBinding::LuaBinding(QObject *parent, Role role)
    : QObject(parent)
    , role_(role)
{
    L = new LuaVM;
    bindingInstances.insert(L->state(), this);

    QDir::setCurrent(u"scripts"_s);
    if (role == Server) {
        L->dofile(u"server-entry.lua"_s);
    } else {
        L->dofile(u"client-entry.lua"_s);
    }
    QDir::setCurrent(u".."_s);
}

LuaBinding::~LuaBinding()
{
    bindingInstances.remove(L->state());
    delete L;
}

LuaBinding::Role LuaBinding::role() const
{
    return role_;
}

int LuaBinding::gameThreadId() const
{
    return gameThreadId_;
}

void LuaBinding::setGameThreadId(int id)
{
    gameThreadId_ = id;
}

void LuaBinding::triggerLuaEvent(const QString &type, const QVariant &payload)
{
    luaEvent(type, payload);
}

void LuaBinding::emit(const QString &type, const QVariantMap &payload)
{
    L->call(u"Emit"_s, {type, payload});
}

void LuaBinding::loadPlugin(const QVariantMap &plugin)
{
    L->call(u"LoadPlugin"_s, {plugin});
}

LuaVM &LuaBinding::vm()
{
    return *L;
}

LuaBinding *LuaBinding::forState(lua_State *state)
{
    // find its main coroutine first. Or we cannot find that LuaBinding
    lua_rawgeti(state, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
    auto mainState = lua_tothread(state, -1);
    lua_pop(state, 1);
    return bindingInstances.value(mainState);
}

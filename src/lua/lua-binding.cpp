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
}

LuaBinding::~LuaBinding()
{
    bindingInstances.remove(L->state());
    delete L;
}

void LuaBinding::run()
{
    QDir::setCurrent(u"scripts"_s);
    if (role_ == Server) {
        L->dofile(u"server/entry.lua"_s);
    } else {
        L->dofile(u"client/entry.lua"_s);
    }
    QDir::setCurrent(u".."_s);
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

QVariant LuaBinding::callMethod(const QString &subtable, const QString &method, const QVariantList &args)
{
    lua_State *L = this->L->state();

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);

    lua_getglobal(L, "ktabletop"); // ktabletop
    lua_getfield(L, -1, subtable.toUtf8().constData()); // ktabletop.<field>
    lua_replace(L, -2);
    lua_getfield(L, -1, method.toUtf8().constData());
    // stack: msgh, <object>, <fn>
    lua_pushvalue(L, -2);

    int nargs = 1; // self
    for (auto &v : args) {
        LuaVM::pushValue(L, v);
        nargs++;
    }
    // stack: msgh, <object>, <fn>, self, args...

    int err = lua_pcall(L, nargs, 1, -nargs - 3);
    if (err) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 3);
        return QVariant();
    }
    auto result = LuaVM::readValue(L);
    lua_pop(L, 2);

    return result;
}

LuaVM &LuaBinding::vm()
{
    return *L;
}

lua_State *LuaBinding::state() const
{
    return L->state();
}

LuaBinding *LuaBinding::forState(lua_State *state)
{
    // find its main coroutine first. Or we cannot find that LuaBinding
    lua_rawgeti(state, LUA_REGISTRYINDEX, LUA_RIDX_MAINTHREAD);
    auto mainState = lua_tothread(state, -1);
    lua_pop(state, 1);
    return bindingInstances.value(mainState);
}

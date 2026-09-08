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
    // stack: msgh, <object>, <ret>
    if (err) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 3);
        return QVariant();
    }
    auto result = LuaVM::readValue(L);
    lua_pop(L, 3);

    return result;
}

QVariantMap LuaBinding::createLObject(const QVariantMap &opts)
{
    lua_State *L = this->L->state();

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);
    const int msgh = lua_gettop(L);

    lua_getglobal(L, "ktabletop");
    lua_getfield(L, -1, "viewModelManager");
    lua_replace(L, -2);
    lua_getfield(L, -1, "getViewModel");
    lua_pushvalue(L, -2);
    LuaVM::pushValue(L, QVariant(opts));
    // stack: msgh, vmManager, fn, vmManager, opts

    if (lua_pcall(L, 2, 1, msgh) != LUA_OK) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 3);
        return {};
    }
    const int obj = lua_gettop(L);

    // stack: msgh, vmManager, retObj
    lua_getfield(L, obj, "createCppObject");
    lua_pushvalue(L, -2);
    if (lua_pcall(L, 1, 1, msgh) != LUA_OK) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 4);
        return {};
    }

    // stack: msgh, vmManager, retObj, ret
    QVariantMap data = LuaVM::readValue(L).toMap();
    lua_pop(L, 1);
    const int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    data[u"refIndex"_s] = ref;
    lua_pop(L, 3);

    return data;
}

QVariant LuaBinding::invokeLObject(int ref, const QString &method, const QVariantList &args)
{
    lua_State *L = this->L->state();

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);
    const int msgh = lua_gettop(L);

    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    lua_getfield(L, -1, method.toUtf8().constData());
    if (lua_type(L, -1) != LUA_TFUNCTION) {
        lua_pop(L, 3);
        qWarning() << "LObject method not invokable:" << method;
        return {};
    }
    lua_pushvalue(L, -2);
    for (auto &arg : args) {
        LuaVM::pushValue(L, arg);
    }

    if (lua_pcall(L, args.length() + 1, 1, msgh) != LUA_OK) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 3);
        return {};
    }
    // stack: msgh, obj, result
    QVariant result = LuaVM::readValue(L);
    lua_pop(L, 3);
    return result;
}

void LuaBinding::releaseLObject(int ref)
{
    if (ref == LUA_NOREF) {
        return;
    }

    lua_State *L = this->L->state();

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);
    const int msgh = lua_gettop(L);

    lua_getglobal(L, "ktabletop");
    lua_getfield(L, -1, "viewModelManager");
    lua_replace(L, -2);
    lua_getfield(L, -1, "removeViewModel");
    lua_pushvalue(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    // stack: msgh, vmManager, fn, vmManager, obj(ref)

    // return a nil via pcall, so I can lua_pop(L, 3) without concern about stack
    if (lua_pcall(L, 2, 1, msgh) != LUA_OK) {
        qCritical() << lua_tostring(L, -1);
    }
    lua_pop(L, 3);

    // unref that obj anyway.
    luaL_unref(L, LUA_REGISTRYINDEX, ref);
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

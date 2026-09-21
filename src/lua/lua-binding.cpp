// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua-binding.h"
#include "c-wrapper.h"

#include <QDir>
#include <QString>

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

#include <lua.hpp>

// Thread-safe way to get binding instance
static const char regKey = 0;

LuaBinding::LuaBinding(QObject *parent, Role role)
    : QObject(parent)
    , m_role(role)
{
    L = new LuaVM;
    lua_pushlightuserdata(L->state(), this);
    lua_rawsetp(L->state(), LUA_REGISTRYINDEX, &regKey);
}

LuaBinding::~LuaBinding()
{
    delete L;
}

void LuaBinding::run()
{
    L->eval(u"package.path = './scripts/?.lua;./scripts/?/init.lua;' .. package.path"_s);
    if (m_role == Server) {
        L->dofile(u"scripts/server/entry.lua"_s);
    } else if (m_role == GameThread) {
        L->dofile(u"scripts/gamethread/entry.lua"_s);
    } else {
        L->dofile(u"scripts/client/entry.lua"_s);
    }
}

LuaBinding::Role LuaBinding::role() const
{
    return m_role;
}

int LuaBinding::gameThreadId() const
{
    return m_gameThreadId;
}

void LuaBinding::setGameThreadId(int id)
{
    m_gameThreadId = id;
}

void LuaBinding::triggerLuaEvent(const QString &type, const QVariant &payload)
{
    luaEvent(type, payload);
}

QVariant LuaBinding::callKTabletopMethod(const QString &subtable, const QString &method, const QVariantList &args)
{
    lua_State *L = this->L->state();

    LuaVM::pushLibFunc(L, "ktabletop", subtable.toUtf8().constData());
    auto result = this->L->callMethod(method, args);
    lua_pop(L, 1);

    return result;
}

QVariantMap LuaBinding::createLObject(const QVariantMap &opts)
{
    QVariantMap result;
    auto *vm = this->L;
    lua_State *L = vm->state();

    LuaVM::pushLibFunc(L, "ktabletop", "viewModelManager");
    auto ref = vm->callMethod(u"getViewModel"_s, {opts});
    lua_pop(L, 1);
    if (!ref.isValid()) {
        return result;
    }

    LuaVM::pushValue(L, ref);
    auto obj = vm->callMethod(u"createCppObject"_s);
    lua_pop(L, 1);
    if (!obj.isValid()) {
        luaL_unref(L, LUA_REGISTRYINDEX, ref.value<LuaRef>().index);
        return result;
    }

    result = obj.toMap();
    result[u"refIndex"_s] = ref.value<LuaRef>().index;

    return result;
}

QVariant LuaBinding::invokeLObject(int ref, const QString &method, const QVariantList &args)
{
    auto *vm = this->L;
    lua_State *L = vm->state();

    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    auto result = vm->callMethod(method, args);
    lua_pop(L, 1);

    return result;
}

void LuaBinding::releaseLObject(int ref)
{
    lua_State *L = this->L->state();

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
    lua_rawgetp(state, LUA_REGISTRYINDEX, &regKey);
    auto *binding = static_cast<LuaBinding *>(lua_touserdata(state, -1));
    lua_pop(state, 1);
    return binding;
}

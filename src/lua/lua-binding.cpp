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
    auto *vm = this->L;
    lua_State *L = vm->state();

    // TODO: maybe viewModelManager shouldn't hold a reference to that viewModel.
    LuaVM::pushLibFunc(L, "ktabletop", "viewModelManager");
    vm->callMethod(u"removeViewModel"_s, {QVariant::fromValue(LuaRef{ref})});
    lua_pop(L, 1);

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
    auto *mainState = lua_tothread(state, -1);
    lua_pop(state, 1);
    return bindingInstances.value(mainState);
}

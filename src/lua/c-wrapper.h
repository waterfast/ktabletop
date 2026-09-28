// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

// wrapper classes for Lua and Git2

#include <QHash>
#include <QMutex>
#include <QThread>
#include <QVariant>
#include <lua.hpp>

struct LuaRef {
    int index = LUA_NOREF;
};

struct LuaRefRAII {
    LuaRefRAII(lua_State *L, int ref)
        : L(L)
        , index(ref)
    {
    }
    LuaRefRAII(LuaRefRAII &) = delete;
    LuaRefRAII(LuaRefRAII &&other)
        : L(other.L)
        , index(other.index)
    {
        this->index = LUA_NOREF;
    }

    ~LuaRefRAII()
    {
        if (index != LUA_NOREF) {
            luaL_unref(L, LUA_REGISTRYINDEX, index);
        }
    }

    lua_State *L;
    int index = LUA_NOREF;
};

template<uint8_t Expected>
struct LuaStk {
    int index = 0;
    static constexpr uint8_t luaType = Expected;
};

class LuaVM
{
public:
    explicit LuaVM();
    LuaVM(LuaVM &) = delete;
    LuaVM(LuaVM &&) = delete;
    ~LuaVM();

    lua_State *state() const;

    void dofile(const QString &path);

    QVariant call(const QString &func_name, QVariantList params = {});

    // call the obj:method(params), obj should at top of stack; stack remains unchanged after call
    QVariant callMethod(const QString &method, QVariantList args = {});

    QVariant eval(const QString &lua);

    static void dumpStack(lua_State *L);
    // call the function with params, function should at top of stack; it will be popped after call
    static QVariant call(lua_State *L, QVariantList params = {});
    static void pushValue(lua_State *L, QVariant v);
    static QVariant readValue(lua_State *L, int index = 0, QHash<const void *, bool> stack = QHash<const void *, bool>());

    static int pushLibFunc(lua_State *L, const char *libName, const char *funcName);

    template<class... Ts>
    static std::tuple<Ts...> readArgs(lua_State *L)
    {
        int nargs = lua_gettop(L);
        int expectedArgs = sizeof...(Ts);
        if (nargs != expectedArgs) {
            luaL_error(L, "expected %d arguments, got %d", expectedArgs, nargs);
            std::unreachable();
        }

        int i = 1;
        auto next = [&i] {
            return i++;
        }; // to supress GCC warnings...
        return std::tuple<Ts...>{readArg<Ts>(L, next())...};
    }

private:
    lua_State *L;

    template<class T>
    static T readArg(lua_State *L, int i)
    {
        if constexpr (std::same_as<T, bool>) {
            luaL_checktype(L, i, LUA_TBOOLEAN);
            return lua_toboolean(L, i) != 0;
        } else if constexpr (std::same_as<T, const char *>) {
            return luaL_checkstring(L, i);
        } else if constexpr (std::integral<T>) {
            return static_cast<T>(luaL_checkinteger(L, i));
        } else if constexpr (std::floating_point<T>) {
            return static_cast<T>(luaL_checknumber(L, i));
        } else if constexpr (requires { T::luaType; }) {
            luaL_checktype(L, i, static_cast<int>(T::luaType));
            return T{i};
        } else {
            static_assert(!std::same_as<T, T>, "unsupported Lua arg type");
        }
    }
};

Q_DECLARE_METATYPE(LuaRef);

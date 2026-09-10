// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "c-wrapper.h"
#include <QFile>

LuaVM::LuaVM()
{
    L = luaL_newstate();
    luaL_openlibs(L);
}

LuaVM::~LuaVM()
{
    lua_close(L);
}

lua_State *LuaVM::state() const
{
    return L;
}

bool LuaVM::dofile(const QString &path)
{
    if (!QFile::exists(path)) {
        qCritical() << path << "does not exist!";
        return false;
    }

    int msgh = pushLibFunc(L, "debug", "traceback");

    luaL_loadfile(L, path.toUtf8().constData());
    int error = lua_pcall(L, 0, 0, msgh);
    if (error) {
        qCritical().noquote() << "LuaVM::dofile(" << path << ") failed: " << lua_tostring(L, -1);
        ;
        lua_pop(L, 1);
    }
    lua_pop(L, 1);

    return !error;
}

void LuaVM::dumpStack()
{
    int top = lua_gettop(L);
    for (int i = 1; i <= top; i++) {
        printf("%d\t%s\t", i, luaL_typename(L, i));
        switch (lua_type(L, i)) {
        case LUA_TNUMBER:
            printf("%g\n", lua_tonumber(L, i));
            break;
        case LUA_TSTRING:
            printf("%s\n", lua_tostring(L, i));
            break;
        case LUA_TBOOLEAN:
            printf("%s\n", (lua_toboolean(L, i) ? "true" : "false"));
            break;
        case LUA_TNIL:
            printf("%s\n", "nil");
            break;
        default:
            printf("%p\n", lua_topointer(L, i));
            break;
        }
    }
}

QVariant LuaVM::call(const QString &func_name, QVariantList params)
{
    int msgh = pushLibFunc(L, "debug", "traceback");

    auto nargs = params.length();
    lua_getglobal(L, func_name.toLatin1().data());

    for (auto v : params) {
        pushValue(L, v);
    }

    QVariant result;
    int err = lua_pcall(L, nargs, 1, msgh);
    if (err) {
        qCritical().noquote() << "LuaVM::call(" << func_name << ") failed: " << lua_tostring(L, -1);
    } else {
        result = readValue(L);
    }
    lua_pop(L, 2);

    return result;
}

QVariant LuaVM::eval(const QString &lua)
{
    int err;
    int msgh = pushLibFunc(L, "debug", "traceback");
    err = luaL_loadstring(L, lua.toUtf8().constData());
    if (err != LUA_OK) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 2); // clear err+msgh
        return QVariant();
    }

    QVariant result;
    err = lua_pcall(L, 0, 1, msgh);
    if (err) {
        qCritical() << lua_tostring(L, -1);
    } else {
        result = readValue(L);
    }
    lua_pop(L, 2);

    return result;
}

void LuaVM::pushValue(lua_State *L, QVariant v)
{
    QVariantList list;
    QVariantMap map;
    auto typeId = v.typeId();
    switch (typeId) {
    case QMetaType::Bool:
        lua_pushboolean(L, v.toBool());
        break;
    case QMetaType::Int:
    case QMetaType::UInt:
        lua_pushinteger(L, v.toInt());
        break;
    case QMetaType::LongLong:
        lua_pushinteger(L, v.toLongLong());
        break;
    case QMetaType::Double:
        lua_pushnumber(L, v.toDouble());
        break;
    case QMetaType::QString: {
        auto bytes = v.toString().toUtf8();
        lua_pushstring(L, bytes.data());
        break;
    }
    case QMetaType::QByteArray: {
        auto ba = v.toByteArray();
        lua_pushlstring(L, ba.data(), ba.size());
        break;
    }
    case QMetaType::QVariantList:
    case QMetaType::QStringList:
    case QMetaType::QJsonArray:
        lua_newtable(L);
        list = v.toList();
        for (int i = 1; i <= list.length(); i++) {
            lua_pushinteger(L, i);
            pushValue(L, list[i - 1]);
            lua_settable(L, -3);
        }
        break;
    case QMetaType::QVariantMap:
    case QMetaType::QJsonObject:
        lua_newtable(L);
        map = v.toMap();
        for (auto i = map.cbegin(), end = map.cend(); i != end; i++) {
            auto bytes = i.key().toUtf8();
            lua_pushstring(L, bytes.data());
            pushValue(L, i.value());
            lua_settable(L, -3);
        }
        break;
    case QMetaType::Nullptr:
        lua_pushnil(L);
        break;
    default:
        qCritical() << "cannot handle QVariant type" << v.typeName() << "(id:" << v.typeId() << "): pushing nil";
        lua_pushnil(L);
        break;
    }
}

QVariant LuaVM::readValue(lua_State *L, int index, QHash<const void *, bool> stack)
{
    if (index == 0)
        index = lua_gettop(L);
    auto tp = lua_type(L, index);
    switch (tp) {
    case LUA_TNIL:
        return QVariant::fromValue(nullptr);
    case LUA_TBOOLEAN:
        return QVariant((bool)lua_toboolean(L, index));
    case LUA_TNUMBER:
        return QVariant(lua_tonumber(L, index));
    case LUA_TSTRING: {
        return QString::fromUtf8(lua_tostring(L, index));
    }
    case LUA_TTABLE: {
        auto p = lua_topointer(L, index);
        if (stack[p]) {
            qCritical("circular reference detected");
            return QVariant();
        }
        stack[p] = true;

        lua_len(L, index);
        int length = lua_tointeger(L, -1);
        lua_pop(L, 1);

        if (length == 0) {
            bool empty = true;
            QVariantMap map;

            lua_pushnil(L);
            while (lua_next(L, index) != 0) {
                QString key;
                if (lua_type(L, -2) == LUA_TNUMBER) {
                    key = QString::fromUtf8(lua_tostring(L, -2));
                } else if (lua_type(L, -2) == LUA_TSTRING) {
                    key = QString::fromUtf8(lua_tostring(L, -2));
                } else {
                    qCritical("key of object must be string");
                    return QVariant();
                }

                auto value = readValue(L, lua_gettop(L), stack);
                lua_pop(L, 1);

                map[key] = value;
                empty = false;
            }

            if (empty) {
                return QVariantList();
            } else {
                return map;
            }
        } else {
            QVariantList arr;
            for (int i = 1; i <= length; i++) {
                lua_rawgeti(L, index, i);
                arr << readValue(L, lua_gettop(L), stack);
                lua_pop(L, 1);
            }
            return arr;
        }
        break;
    }

    // ignore function, userdata and thread
    default:
        qCritical("unexpected value type %s", lua_typename(L, tp));
    }
    return QVariant();
}

int LuaVM::pushLibFunc(lua_State *L, const char *libName, const char *funcName)
{
    lua_getglobal(L, libName);
    lua_getfield(L, -1, funcName);
    lua_replace(L, -2);

    // return index of pushed function
    return lua_gettop(L);
}

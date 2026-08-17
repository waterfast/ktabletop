// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "c-wrapper.h"
#include <QFile>

extern "C" {
int luaopen_ktabletop(lua_State *);
}

LuaVM::LuaVM()
{
    L = luaL_newstate();
    luaL_openlibs(L);
    // luaopen_ktabletop(L);
}

LuaVM::~LuaVM()
{
    // qDebug("LuaVM state %p closed", this);
    lua_close(L);
}

bool LuaVM::needLock()
{
    auto thr = QThread::currentThread();
    bool ret = false;
    bool locked = true;
    if (interpreter_lock.tryLock(0)) {
        locked = false;
        interpreter_lock.unlock();
    }
    if (!locked || current_thread != thr) {
        current_thread = thr;
        ret = true;
    }
    return ret;
}

bool LuaVM::dofile(const QString &path)
{
    if (!QFile::exists(path)) {
        qCritical() << path << "does not exist!";
        return false;
    }
    QMutexLocker locker(needLock() ? &interpreter_lock : nullptr);

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);

    luaL_loadfile(L, path.toUtf8().constData());
    int error = lua_pcall(L, 0, 0, -2);

    if (error) {
        const char *error_msg = lua_tostring(L, -1);
        qCritical() << error_msg;
        lua_pop(L, 2);
        return false;
    }

    lua_pop(L, 1);
    return true;
}

void LuaVM::setGlobal(const QString &name, const QString &jsonValue)
{
    QMutexLocker locker(needLock() ? &interpreter_lock : nullptr);
    auto bytes = jsonValue.toUtf8();
    lua_pushlstring(L, bytes.constData(), bytes.size());
    lua_setglobal(L, name.toUtf8().constData());
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
    QMutexLocker locker(needLock() ? &interpreter_lock : nullptr);

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);

    auto nargs = params.length();
    lua_getglobal(L, func_name.toLatin1().data());

    for (auto v : params) {
        pushValue(L, v);
    }

    // handler位于function位置的前一个
    int err = lua_pcall(L, nargs, 1, -nargs - 2);
    if (err) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 2);
        return QVariant();
    }
    auto result = readValue(L);
    lua_pop(L, 2);

    return result;
}

QVariant LuaVM::eval(const QString &lua)
{
    QMutexLocker locker(needLock() ? &interpreter_lock : nullptr);

    lua_getglobal(L, "debug");
    lua_getfield(L, -1, "traceback");
    lua_replace(L, -2);

    int err;
    err = luaL_loadstring(L, lua.toUtf8().constData());
    if (err != LUA_OK) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 2);
        return QVariant();
    }
    err = lua_pcall(L, 0, 1, -2);
    if (err) {
        qCritical() << lua_tostring(L, -1);
        lua_pop(L, 2);
        return QVariant();
    }
    auto result = readValue(L);
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
        lua_newtable(L);
        list = v.toList();
        for (int i = 1; i <= list.length(); i++) {
            lua_pushinteger(L, i);
            pushValue(L, list[i - 1]);
            lua_settable(L, -3);
        }
        break;
    case QMetaType::QVariantMap:
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
    case QMetaType::UnknownType: // 应该是 undefined，感觉很危险
        lua_pushnil(L);
        break;
    default:
        // 继续判自定义MetaType，这些不能在case语句判
        // if (typeId == QMetaType::fromType<Client *>().id()) {
        //   SWIG_NewPointerObj(L, v.value<Client *>(), SWIGTYPE_p_Client, 0);
        // } else if (typeId == QMetaType::fromType<RoomThread *>().id()) {
        //   SWIG_NewPointerObj(L, v.value<RoomThread *>(), SWIGTYPE_p_RoomThread, 0);
        // } else if (typeId == QMetaType::fromType<Server *>().id()) {
        //   SWIG_NewPointerObj(L, v.value<Server *>(), SWIGTYPE_p_Server, 0);
        // } else {
        qCritical() << "cannot handle QVariant type" << v.typeId();
        lua_pushnil(L);
        // }
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
        size_t len = lua_rawlen(L, index);
        return QVariant::fromValue<const char *>(lua_tolstring(L, index, &len));
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

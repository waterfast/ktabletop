// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua-binding.h"
#include "async-context.h"
#include "lua-helper.h"

#include <QDir>
#include <QString>

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

#include <lua.hpp>

// Thread-safe way to get binding instance
static const char regKey = 0;

static constexpr char sandboxLua[] = {
#embed "sandboxing.lua"
};

LuaBinding::LuaBinding(QObject *parent, Role role)
    : QObject(parent)
    , m_role(role)
{
    L = luaL_newstate();
    luaL_openlibs(L);
    lua_pushlightuserdata(L, this);
    lua_rawsetp(L, LUA_REGISTRYINDEX, &regKey);

    // rewrite package.path/cpath searchers with custom one, since they are unnecessary
    // (they should be unnecessary in this app, according to my experience)
    LuaVM::getTableField(L, "package", "searchers");
    lua_pushcfunction(L, &LuaBinding::qrcSearcher);
    lua_rawseti(L, -2, 2);
    lua_pushcfunction(L, &LuaBinding::rtpSearcher);
    lua_rawseti(L, -2, 3);
    lua_pop(L, 1);

    lua_setwarnf(L, &LuaBinding::warnf, this);
    lua_warning(L, "@on", false);
    connect(this, &LuaBinding::luaWarning, this, [](QString msg) {
        qCritical().noquote() << msg;
    });

    luaL_dostring(L, sandboxLua);
}

LuaBinding::~LuaBinding()
{
    lua_close(L);
}

void LuaBinding::run()
{
    if (m_role == Server) {
        LuaVM::eval(L, u"require 'server.entry'"_s);
    } else if (m_role == GameThread) {
        LuaVM::eval(L, u"require 'gamethread.entry'"_s);
    } else {
        LuaVM::eval(L, u"require 'client.entry'"_s);
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
    LuaVM::getTableField(L, "ktabletop", subtable.toUtf8().constData());
    auto result = LuaVM::callMethod(L, method, args);
    lua_pop(L, 1);

    return result;
}

QVariantMap LuaBinding::createLObject(const QVariantMap &opts)
{
    QVariantMap result;

    LuaVM::getTableField(L, "ktabletop", "viewModelManager");
    auto ref = LuaVM::callMethod(L, u"getViewModel"_s, {opts});
    lua_pop(L, 1);
    if (!ref.isValid()) {
        return result;
    }

    LuaVM::pushValue(L, ref);
    auto obj = LuaVM::callMethod(L, u"createCppObject"_s);
    lua_pop(L, 1);
    if (!obj.isValid()) {
        luaL_unref(L, LUA_REGISTRYINDEX, ref.value<LuaRef>().index);
        return result;
    }

    result = obj.toMap();
    result[u"refIndex"_s] = ref.value<LuaRef>().index;

    lua_rawgeti(L, LUA_REGISTRYINDEX, ref.value<LuaRef>().index);

    return result;
}

QVariant LuaBinding::invokeLObject(int ref, const QString &method, const QVariantList &args)
{
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    auto result = LuaVM::callMethod(L, method, args);
    lua_pop(L, 1);

    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);

    return result;
}

void LuaBinding::releaseLObject(int ref)
{
    lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
    luaL_unref(L, LUA_REGISTRYINDEX, ref);
}

lua_State *LuaBinding::state() const
{
    return L;
}

const QStringList &LuaBinding::runtimePaths() const
{
    return m_runtimePaths;
}

void LuaBinding::setRuntimePaths(const QStringList &paths)
{
    m_runtimePaths = paths;
}

LuaBinding *LuaBinding::forState(lua_State *state)
{
    lua_rawgetp(state, LUA_REGISTRYINDEX, &regKey);
    auto *binding = static_cast<LuaBinding *>(lua_touserdata(state, -1));
    lua_pop(state, 1);
    return binding;
}

int LuaBinding::pushAsyncCancelToken(lua_State *L, AsyncContext *ctx)
{
    // ctx is certainly alive when calling this function from Lua
    // because this will only be triggered by async.cancel,
    // and if ctx->complete has been called,
    // corresponding awaitable should have done and removed from calling chain
    constexpr auto f = [](lua_State *L) {
        auto *ctx = static_cast<AsyncContext *>(lua_touserdata(L, lua_upvalueindex(1)));
        ctx->cancel();
        return 0;
    };

    lua_pushlightuserdata(L, ctx);
    lua_pushcclosure(L, f, 1);
    return 1;
}

void LuaBinding::warnf(void *ud, const char *msg, int)
{
    auto *binding = reinterpret_cast<LuaBinding *>(ud);
    Q_EMIT binding->luaWarning(QString::fromUtf8(msg));
}

int LuaBinding::qrcSearcher(lua_State *L)
{
    QString filename;
    const char *modname = luaL_checkstring(L, 1);
    auto name = QString::fromUtf8(modname).replace(u"."_s, u"/"_s);
    auto name1 = u":/scripts/" + name + u".lua"_s;
    auto name2 = u":/scripts/" + name + u"/init.lua"_s;
    if (QFile::exists(name1)) {
        filename = name1;
    } else if (QFile::exists(name2)) {
        filename = name2;
    }
    if (filename.isEmpty()) {
        lua_pushstring(L, QString(u"qrcSearcher: module '%1' not found"_s).arg(modname).toUtf8().constData());
        return 1;
    }

    QFile file(filename);
    [[unlikely]] if (!file.open(QIODevice::ReadOnly)) {
        lua_pushstring(L, QString(u"qrcSearcher: module '%1' open error"_s).arg(modname).toUtf8().constData());
        return 1;
    }
    auto filenameBytes = filename.prepend(u"=qrc"_s).toUtf8();
    auto *filenameStr = filenameBytes.constData();
    auto bytes = file.readAll();
    [[likely]] if (luaL_loadbuffer(L, bytes.constData(), bytes.length(), filenameStr) == LUA_OK) {
        lua_pushstring(L, filename.toUtf8().constData());
        return 2;
    } else {
        file.close();
        return luaL_error(L, "error loading module '%s' from file '%s':\n\t%s", lua_tostring(L, 1), filenameStr, lua_tostring(L, -1));
    }
}

static QString searchRtpPath(lua_State *L, const QString &name)
{
    auto *binding = LuaBinding::forState(L);
    const auto &pathList = binding->runtimePaths();

    for (const auto &dir : pathList) {
        auto file1 = dir + u"/"_s + name + u".lua"_s;
        QFileInfo f1(file1);
        if (f1.exists() && f1.isFile() && f1.isReadable()) {
            return file1;
        }
        auto file2 = dir + u"/"_s + name + u"/init.lua"_s;
        QFileInfo f2(file1);
        if (f2.exists() && f2.isFile() && f2.isReadable()) {
            return file2;
        }
    }

    return {};
}

// Something like package.searchpath but not call it directly for performance
int LuaBinding::rtpSearcher(lua_State *L)
{
    const char *modname = luaL_checkstring(L, 1);
    auto name = QString::fromUtf8(modname).replace(u"."_s, u"/"_s);

    auto path = searchRtpPath(L, name);
    auto bytes = path.toUtf8();
    auto *pathStr = bytes.constData();
    if (path.isEmpty()) {
        lua_pushstring(L, QString(u"rtpSearcher: module '%1' not found"_s).arg(modname).toUtf8().constData());
        return 1;
    }

    if (luaL_loadfile(L, pathStr) == LUA_OK) {
        lua_pushstring(L, pathStr);
        return 2;
    } else {
        return luaL_error(L, "error loading module '%s' from file '%s':\n\t%s", lua_tostring(L, 1), pathStr, lua_tostring(L, -1));
    }
}

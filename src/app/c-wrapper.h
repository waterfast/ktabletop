#pragma once

// wrapper classes for Lua and Git2

#include <QHash>
#include <QMutex>
#include <QThread>
#include <QVariant>
#include <lua.hpp>

class LuaVM
{
public:
    explicit LuaVM();
    LuaVM(LuaVM &) = delete;
    LuaVM(LuaVM &&) = delete;
    ~LuaVM();

    bool dofile(const QString &path);
    void dumpStack();

    QVariant call(const QString &func_name, QVariantList params = QVariantList());
    QVariant eval(const QString &lua);
    void setGlobal(const QString &name, const QString &jsonValue);

private:
    lua_State *L;
    QMutex interpreter_lock;
    QThread *current_thread = nullptr;

    bool needLock();

    static void pushValue(lua_State *L, QVariant v);
    static QVariant readValue(lua_State *L, int index = 0, QHash<const void *, bool> stack = QHash<const void *, bool>());
};

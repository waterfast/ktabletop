// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>
#include <QVariant>

class LuaVM;
class AsyncContext;
struct lua_State;

class LuaBinding : public QObject
{
    Q_OBJECT

public:
    enum Role {
        Server,
        GameThread,
        Client,
    };
    Q_ENUM(Role);

    explicit LuaBinding(QObject *parent = nullptr, Role role = Server);
    ~LuaBinding() override;

    // Execute the entry script for the role.
    void run();

    Role role() const;
    // for GameThread role only
    int gameThreadId() const;
    void setGameThreadId(int id);

    // called by Lua
    void triggerLuaEvent(const QString &type, const QVariant &payload);

    // Call `ktabletop.<subtable>:<method>(args...)`
    QVariant callKTabletopMethod(const QString &subtable, const QString &method, const QVariantList &args = {});

    // call `ktabletop.viewModelManager:getViewModel(opts)`
    // returned table is added a `refIndex` field
    QVariantMap createLObject(const QVariantMap &opts);
    // Call `LObject:method(args)` on the object referenced by `ref`.
    QVariant invokeLObject(int ref, const QString &method, const QVariantList &args);
    // Release the registry reference held for an LObject.
    void releaseLObject(int ref);

    LuaVM &vm();
    lua_State *state() const;

    static LuaBinding *forState(lua_State *state);
    static int pushAsyncCancelToken(lua_State *L, AsyncContext *ctx);

public Q_SLOTS:
    // void requestDone(int func, std::error_code err, QByteArray data);
    // void delayDone(int func);

Q_SIGNALS:
    void luaEvent(const QString &type, const QVariant &payload);
    void luaWarning(QString message);

private:
    Role m_role;
    int m_gameThreadId = 0;
    LuaVM *L;

    static void warnf(void *ud, const char *msg, int tocont);
    static int qrcSearcher(lua_State *L);
};

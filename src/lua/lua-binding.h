// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>
#include <QVariant>

class LuaVM;
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
    QVariant callMethod(const QString &subtable, const QString &method, const QVariantList &args = {});

    LuaVM &vm();
    lua_State *state() const;

    static LuaBinding *forState(lua_State *state);

Q_SIGNALS:
    void luaEvent(const QString &type, const QVariant &payload);

private:
    Role role_;
    int gameThreadId_ = 0;
    LuaVM *L;
};

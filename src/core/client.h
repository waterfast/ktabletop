// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>

class LuaBinding;
class UserConnection;

class Client : public QObject
{
    Q_OBJECT

public:
    static Client *instance();
    ~Client();

    LuaBinding *luaBinding() const;
    UserConnection *connection() const;

    void connectToHost(const QString &server, ushort port = 17943, const QString &username = QString(), const QString &password = QString());

private:
    explicit Client(QObject *parent = nullptr);

    LuaBinding *L;
    UserConnection *m_connection;
};

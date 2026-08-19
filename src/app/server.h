// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QHash>
#include <QHostAddress>
#include <QObject>

class LuaBinding;
class ClientSocket;
class ServerSocket;
class UserConnection;

class Server : public QObject
{
    Q_OBJECT

public:
    static Server *instance();
    ~Server();

    bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

private:
    explicit Server(QObject *parent = nullptr);

    LuaBinding *L;
    ServerSocket *server;
    QHash<int, UserConnection *> connections;

    void processNewConnection(ClientSocket *client);
};

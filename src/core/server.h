// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QHash>
#include <QHostAddress>
#include <QObject>
#include <QVariantMap>

class LuaBinding;
class ClientSocket;
class ServerSocket;
class UserConnection;
class GameThread;

class Server : public QObject
{
    Q_OBJECT

public:
    static constexpr ushort DefaultPort = 17943u;

    static Server *instance();
    ~Server();

    bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = DefaultPort);

    UserConnection *findConnection(int connId) const;

    GameThread *createGameThread();
    GameThread *getGameThread(int id) const;
    void removeGameThread(int id);
    GameThread *getAvailableGameThread();

    // TODO
    void startGameRoom(int roomId, const QVariantMap &data);

    void dispatchLuaEvent(const QString &type, const QVariant &data);

private:
    explicit Server(QObject *parent = nullptr);

    LuaBinding *L;
    ServerSocket *server;
    QHash<int, UserConnection *> connections;
    QHash<int, GameThread *> gameThreads;

    void processNewConnection(ClientSocket *client);
};

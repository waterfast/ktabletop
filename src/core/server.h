// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QHash>
#include <QHostAddress>
#include <QObject>
#include <QVariantMap>

#include <openssl/evp.h>

class LuaBinding;
class ClientSocket;
class ServerSocket;
class UserConnection;
class GameThread;
class DbThread;
class QSettings;

// TODO: Handle command from UserConnection::request. most times that user should be OP
class UserRequestAdapter;
// TODO: Handle command from http API, should have bearer TOKEN
class HttpApiAdapter;

class StdinAdapter;
class CommandHandler;

class Server : public QObject
{
    Q_OBJECT

public:
    static constexpr ushort DefaultPort = 17943u;

    static Server *instance();
    static bool initialized();
    static void destroy();
    ~Server();

    bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = DefaultPort);

    UserConnection *findConnection(int connId) const;
    LuaBinding *luaBinding() const;

    GameThread *createGameThread();
    GameThread *getGameThread(int id) const;
    void removeGameThread(int id);
    GameThread *getAvailableGameThread();

    // TODO
    void startGameRoom(int roomId, const QVariantMap &data);

    void dispatchLuaEvent(const QString &type, const QVariant &data);

    QString authPublicKey() const;
    EVP_PKEY *authPrivateKey() const;

    DbThread *usersDb() const;
    StdinAdapter *shell() const;

    QSettings *config() const;
    void reloadConfig();

    void setDataPath(const QString &path);

Q_SIGNALS:
    void luaWarning(QString message);

private:
    explicit Server(QObject *parent = nullptr);

    LuaBinding *L;
    ServerSocket *server;
    QHash<int, UserConnection *> connections;
    QHash<int, GameThread *> gameThreads;

    DbThread *m_usersDb = nullptr;

    StdinAdapter *m_shell;

    QSettings *m_config = nullptr;

    QString m_dataPath = QStringLiteral("./server");

    QString m_authPublicKey;
    EVP_PKEY *m_authPrivateKey = nullptr;

    void initAuthKeys();
    void initUsersDb();
    void initConfig();
    void processNewConnection(ClientSocket *client);
};

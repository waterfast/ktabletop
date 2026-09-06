// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend-controller.h"
#include "qml/lobject-manager.h"
#include "qml/qml-backend.h"

#include "core/client.h"
#include "core/server.h"
#include "lua/lua-binding.h"

#include "network/client-socket.h"
#include "network/user-connection.h"
#include <QHostAddress>
#include <QTcpSocket>

using namespace Qt::Literals::StringLiterals;

QmlBackendController::QmlBackendController(QmlBackend *backend, QObject *parent)
    : QObject(parent)
    , m_backend(backend)
{
    connect(m_backend, &QmlBackend::startServerRequested, this, &QmlBackendController::onStartServerRequested);
    connect(m_backend, &QmlBackend::joinServerRequested, this, &QmlBackendController::onJoinServerRequested);

    auto *manager = LObjectManager::instance();
    manager->setCreateObjectFn([](const QVariantMap &opts) {
        return Client::instance()->luaBinding()->createLObject(opts);
    });
    manager->setReleaseObjectFn([](int ref) {
        Client::instance()->luaBinding()->releaseLObject(ref);
    });
    QObject::connect(manager, &LObjectManager::invoked, [](int ref, const QString &method, const QVariantList &args) {
        Client::instance()->luaBinding()->invokeLObject(ref, method, args);
    });
}

QmlBackendController::~QmlBackendController()
{
}

void QmlBackendController::onStartServerRequested(ushort port)
{
    auto server = Server::instance();
    if (!server->listen(QHostAddress::Any, port)) {
        // server->deleteLater();
        qCritical("Cannot start server!");
    }
}

void QmlBackendController::onJoinServerRequested(const QString &address, ushort port)
{
    auto client = Client::instance();
    connect(client->luaBinding(), &LuaBinding::luaEvent, LObjectManager::instance(), &LObjectManager::dispatch, Qt::UniqueConnection);
    connect(client->luaBinding(), &LuaBinding::luaEvent, this, &QmlBackendController::handleCommonLuaEvent, Qt::UniqueConnection);
    client->connectToHost(address, port);
}

void QmlBackendController::handleCommonLuaEvent(const QString &sig, const QVariant &)
{
    if (sig == u"Client::EnterLobby"_s) {
        m_backend->enterLobby();
    } else if (sig == u"Client::DisconnectFromHost"_s) {
        Client::instance()->connection()->socket()->socket()->disconnectFromHost();
    }
}

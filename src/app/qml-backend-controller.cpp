// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend-controller.h"
#include "qml/lobject-manager.h"
#include "qml/main-view-model.h"
#include "qml/qml-backend.h"

#include "core/client.h"
#include "core/server.h"
#include "lua/lua-binding.h"

#include "network/client-socket.h"
#include "network/user-connection.h"
#include <QFileInfo>
#include <QHostAddress>
#include <QTcpSocket>
#include <QUrl>

using namespace Qt::Literals::StringLiterals;

QmlBackendController::QmlBackendController(QmlBackend *backend, QObject *parent)
    : QObject(parent)
    , m_backend(backend)
{
    auto *vm = m_backend->mainViewModel();
    connect(vm, &MainViewModel::startServerRequested, this, &QmlBackendController::onStartServerRequested);
    connect(vm, &MainViewModel::joinServerRequested, this, &QmlBackendController::onJoinServerRequested);

    auto *manager = LObjectManager::instance();
    auto *client = Client::instance();
    manager->setCreateObjectFn([](const QVariantMap &opts) {
        return Client::instance()->luaBinding()->createLObject(opts);
    });
    manager->setReleaseObjectFn([](int ref) {
        Client::instance()->luaBinding()->releaseLObject(ref);
    });
    QObject::connect(manager, &LObjectManager::invoked, client, [](int ref, const QString &method, const QVariantList &args) {
        Client::instance()->luaBinding()->invokeLObject(ref, method, args);
    });
}

QmlBackendController::~QmlBackendController()
{
}

void QmlBackendController::onStartServerRequested(ushort port)
{
    auto *server = Server::instance();
    if (!server->listen(QHostAddress::Any, port)) {
        // server->deleteLater();
        qCritical("Cannot start server!");
    }
}

void QmlBackendController::onJoinServerRequested(const QString &address, ushort port, const QString &username)
{
    auto *client = Client::instance();
    connect(client->luaBinding(), &LuaBinding::luaEvent, LObjectManager::instance(), &LObjectManager::dispatch, Qt::UniqueConnection);
    connect(client->luaBinding(), &LuaBinding::luaEvent, this, &QmlBackendController::handleCommonLuaEvent, Qt::UniqueConnection);
    client->connectToHost(address, port, username);
}

void QmlBackendController::handleCommonLuaEvent(const QString &sig, const QVariant &data)
{
    auto *vm = m_backend->mainViewModel();
    if (sig == u"Client::EnterLobby"_s) {
        const QVariantMap map = data.toMap();
        vm->setLobbyViewModelName(map.value(u"viewModelName"_s).toString());
        vm->setRoomId(0);
        vm->setGameStarted(false);
        vm->setConnected(true);
        vm->setRoomViewModelName(QString());
        m_backend->enterLobby();
    } else if (sig == u"Client::DisconnectFromHost"_s) {
        vm->setConnected(false);
        vm->setLobbyViewModelName(QString());
        vm->setRoomViewModelName(QString());
        vm->setGameViewModelName(QString());
        vm->setGamePageUrl(QString());
        vm->setRoomId(0);
        vm->setGameStarted(false);
        Client::instance()->connection()->socket()->socket()->disconnectFromHost();
    } else if (sig == u"Client::EnterRoom"_s) {
        const QVariantMap map = data.toMap();
        vm->setRoomViewModelName(map.value(u"viewModelName"_s).toString());
        vm->setRoomId(map.value(u"id"_s).toInt());
        vm->setGameStarted(false);
    } else if (sig == u"Client::EnterGame"_s) {
        const QVariantMap map = data.toMap();
        const QString pageUrl = map.value(u"pageUrl"_s).toString();
        vm->setGameViewModelName(map.value(u"viewModelName"_s).toString());
        vm->setGamePageUrl(QUrl::fromLocalFile(QFileInfo(pageUrl).absoluteFilePath()).toString());
        vm->setGameStarted(true);
    }
}

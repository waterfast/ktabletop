// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend-controller.h"
#include "qml/lobject-manager.h"
#include "qml/main-view-model.h"
#include "qml/qml-backend.h"

#include "client.h"
#include "core/lua/lua-binding.h"
#include "core/packman.h"
#include "core/server.h"

#include "core/network/client-socket.h"
#include "core/network/user-connection.h"
#include <QFileInfo>
#include <QHostAddress>
#include <QTcpSocket>
#include <QUrl>

#include <KLocalizedString>
#include <QtConcurrent>

using namespace Qt::Literals::StringLiterals;

QmlBackendController::QmlBackendController(QmlBackend *backend, QObject *parent)
    : QObject(parent)
    , m_backend(backend)
{
    auto *vm = m_backend->mainViewModel();
    connect(vm, &MainViewModel::startServerRequested, this, &QmlBackendController::onStartServerRequested);
    connect(vm, &MainViewModel::joinServerRequested, this, &QmlBackendController::onJoinServerRequested);

    connect(vm, &MainViewModel::progressTaskCancelRequested, this, [](const QString &key) {
        if (Client::initialized()) {
            Client::instance()->cancelTask(key);
        }
    });

    auto *packman = PackMan::instance();
    connect(packman, &PackMan::updateTransferMessage, this, [vm](const QString &repoName, const QString &message) {
        Q_EMIT vm->setProgressDialogData(u"git-progress-"_s + repoName, message, -1, false);
    });
    connect(packman, &PackMan::errorOccurred, this, [vm](const QString &repoName, const QString &message) {
        Q_EMIT vm->clearProgressDialogData(u"git-progress-"_s + repoName);
        Q_EMIT vm->showErrorDialog(message);
    });

    connect(vm, &MainViewModel::installPackRequested, this, [this](const QString &url) {
        if (url.isEmpty()) {
            return;
        }
        const QString name = PackMan::extractPackName(url);
        startPackJob(name, i18n("Downloading %1…", name), [url] {
            PackMan::instance()->downloadNewPack(url);
        });
    });

    auto *manager = LObjectManager::instance();
    manager->setCreateObjectFn([](const QVariantMap &opts) {
        return Client::instance()->luaBinding()->createLObject(opts);
    });
    manager->setReleaseObjectFn([](int ref) {
        Client::instance()->luaBinding()->releaseLObject(ref);
    });
}

QmlBackendController::~QmlBackendController()
{
}

void QmlBackendController::startPackJob(const QString &name, const QString &message, std::function<void()> work)
{
    auto *vm = m_backend->mainViewModel();
    const QString key = u"git-progress-"_s + name;

    Q_EMIT vm->setProgressDialogData(key, message, -1, false);

    QtConcurrent::run([work] {
        work();
    }).then(this, [this, key] {
        Q_EMIT m_backend->mainViewModel()->clearProgressDialogData(key);
    });
}

void QmlBackendController::onStartServerRequested(ushort port)
{
    auto *server = Server::instance();
    auto *vm = m_backend->mainViewModel();
    connect(server, &Server::luaWarning, vm, &MainViewModel::showLuaError);
    server->luaBinding()->run();
    if (!server->listen(QHostAddress::Any, port)) {
        // server->deleteLater();
        auto *vm = m_backend->mainViewModel();
        vm->showToast(i18n("Cannot start server!"));
    }
}

void QmlBackendController::onJoinServerRequested(const QString &address, ushort port, const QString &username, const QString &password)
{
    Client::destroy();
    auto *client = Client::instance();
    auto *vm = m_backend->mainViewModel();
    auto *manager = LObjectManager::instance();
    connect(client->luaBinding(), &LuaBinding::luaWarning, vm, &MainViewModel::showLuaError);
    connect(client->luaBinding(), &LuaBinding::luaEvent, LObjectManager::instance(), &LObjectManager::dispatch);
    connect(client->luaBinding(), &LuaBinding::luaEvent, this, &QmlBackendController::handleCommonLuaEvent);
    connect(manager, &LObjectManager::invoked, client, [client](int ref, const QString &method, const QVariantList &args) {
        client->luaBinding()->invokeLObject(ref, method, args);
    });

    connect(client, &Client::showToast, vm, &MainViewModel::showToast);
    connect(client, &Client::showErrorDialog, vm, &MainViewModel::showErrorDialog);
    connect(client, &Client::setProgressDialogData, vm, &MainViewModel::setProgressDialogData);
    connect(client, &Client::clearProgressDialogData, vm, &MainViewModel::clearProgressDialogData);

    client->luaBinding()->run();
    client->connectToHost(address, port, username, password);
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
    } else if (sig == u"Client::SocketError"_s) {
        vm->setConnected(false);
    }
}

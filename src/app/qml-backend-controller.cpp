// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend-controller.h"
#include "qml/lobject-manager.h"
#include "qml/qml-backend.h"

#include "core/client.h"
#include "core/server.h"
#include "lua/lua-binding.h"

#include <QHostAddress>

using namespace Qt::Literals::StringLiterals;

QmlBackendController::QmlBackendController(QmlBackend *backend, QObject *parent)
    : QObject(parent)
    , m_backend(backend)
{
    connect(m_backend, &QmlBackend::startServerRequested, this, &QmlBackendController::onStartServerRequested);
    connect(m_backend, &QmlBackend::joinServerRequested, this, &QmlBackendController::onJoinServerRequested);
    connect(LObjectManager::instance(), &LObjectManager::valueChanged, this, &QmlBackendController::onPropertyMapValueChanged);
}

QmlBackendController::~QmlBackendController()
{
}

void QmlBackendController::onStartServerRequested(ushort port)
{
    auto server = Server::instance();
    if (!server->listen(QHostAddress::Any, port)) {
        server->deleteLater();
        qCritical("Cannot start server!");
    }
}

void QmlBackendController::onJoinServerRequested(const QString &address, ushort port)
{
    auto client = Client::instance();
    connect(client->luaBinding(), &LuaBinding::luaEvent, LObjectManager::instance(), &LObjectManager::dispatch, Qt::UniqueConnection);
    client->connectToHost(address, port);
}

void QmlBackendController::onPropertyMapValueChanged(const QString &, const QString &, const QVariant &)
{
    qWarning("Changing value directly from QML view will have no effect.");
}

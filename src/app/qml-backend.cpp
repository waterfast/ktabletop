// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend.h"
#include "client.h"
#include "server.h"

bool QmlBackend::startServer(ushort port)
{
    auto server = Server::instance();
    if (!server->listen(QHostAddress::Any, port)) {
        server->deleteLater();
        qCritical("Cannot start server!");
        return false;
    }
    return true;
}

void QmlBackend::joinServer(QString address, ushort port)
{
    auto client = Client::instance();
    client->connectToHost(address, port);
}

// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QTcpServer>
#include <QTcpSocket>

class ClientSocket;

class ServerSocket : public QObject
{
    Q_OBJECT

public:
    ServerSocket(QObject *parent = nullptr);

    bool listen(const QHostAddress &address = QHostAddress::Any, ushort port = 9527u);

Q_SIGNALS:
    void newConnection(ClientSocket *socket);

private:
    QTcpServer *server;
    void processNewConnection();
};

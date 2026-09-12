// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "main-view-model.h"

MainViewModel::MainViewModel(QObject *parent)
    : QObject(parent)
{
}

bool MainViewModel::connected() const
{
    return m_connected;
}

void MainViewModel::setConnected(bool connected)
{
    if (m_connected == connected) {
        return;
    }
    m_connected = connected;
    Q_EMIT connectedChanged(m_connected);
}

int MainViewModel::roomId() const
{
    return m_roomId;
}

void MainViewModel::setRoomId(int roomId)
{
    if (m_roomId == roomId) {
        return;
    }
    m_roomId = roomId;
    Q_EMIT roomIdChanged(m_roomId);
}

bool MainViewModel::gameStarted() const
{
    return m_gameStarted;
}

void MainViewModel::setGameStarted(bool gameStarted)
{
    if (m_gameStarted == gameStarted) {
        return;
    }
    m_gameStarted = gameStarted;
    Q_EMIT gameStartedChanged(m_gameStarted);
}

void MainViewModel::startSinglePlayer(const QString &username)
{
    const ushort port = 17943;
    Q_EMIT startServerRequested(port);
    Q_EMIT joinServerRequested(QStringLiteral("127.0.0.1"), port, username);
}

void MainViewModel::joinMultiPlayer(const QString &address, int port, const QString &username)
{
    Q_EMIT joinServerRequested(address, static_cast<ushort>(port), username);
}

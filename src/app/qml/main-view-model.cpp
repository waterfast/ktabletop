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

QString MainViewModel::lobbyViewModelName() const
{
    return m_lobbyViewModelName;
}

void MainViewModel::setLobbyViewModelName(const QString &name)
{
    if (m_lobbyViewModelName == name) {
        return;
    }
    m_lobbyViewModelName = name;
    Q_EMIT lobbyViewModelNameChanged(m_lobbyViewModelName);
}

QString MainViewModel::roomViewModelName() const
{
    return m_roomViewModelName;
}

void MainViewModel::setRoomViewModelName(const QString &name)
{
    if (m_roomViewModelName == name) {
        return;
    }
    m_roomViewModelName = name;
    Q_EMIT roomViewModelNameChanged(m_roomViewModelName);
}

QString MainViewModel::gameViewModelName() const
{
    return m_gameViewModelName;
}

void MainViewModel::setGameViewModelName(const QString &name)
{
    if (m_gameViewModelName == name) {
        return;
    }
    m_gameViewModelName = name;
    Q_EMIT gameViewModelNameChanged(m_gameViewModelName);
}

QString MainViewModel::gamePageUrl() const
{
    return m_gamePageUrl;
}

void MainViewModel::setGamePageUrl(const QString &url)
{
    if (m_gamePageUrl == url) {
        return;
    }
    m_gamePageUrl = url;
    Q_EMIT gamePageUrlChanged(m_gamePageUrl);
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

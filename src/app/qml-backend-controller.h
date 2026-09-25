// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>

class QmlBackend;

class QmlBackendController : public QObject
{
    Q_OBJECT

public:
    explicit QmlBackendController(QmlBackend *backend, QObject *parent = nullptr);
    ~QmlBackendController() override;

private Q_SLOTS:
    void onStartServerRequested(ushort port);
    void onJoinServerRequested(const QString &address, ushort port, const QString &username, const QString &password);

private:
    QmlBackend *const m_backend;

    void handleCommonLuaEvent(const QString &command, const QVariant &data);
};

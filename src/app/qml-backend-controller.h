// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>

#include <functional>

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

    // since there is no client instance when using plugin manager,
    // we need to offer new method to launch "async" download job.
    // (This is purely for displaying progress)
    void startPackJob(const QString &name, const QString &message, std::function<void()> work);
};

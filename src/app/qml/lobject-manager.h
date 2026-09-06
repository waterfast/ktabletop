// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QHash>
#include <QObject>
#include <QVariant>

#include <functional>

class LObjectProxy;

class LObjectManager : public QObject
{
    Q_OBJECT

public:
    // Handlers installed by the host (app layer) to talk to the Lua binding.
    // Only creation needs to be synchronous (callback), invoke/signal go through signals.
    using CreateObjectFn = std::function<QVariantMap(const QVariantMap &)>;
    using ReleaseObjectFn = std::function<void(int)>;

    static LObjectManager *instance();

    LObjectProxy *get(const QString &objectName) const;

    void dispatch(const QString &type, const QVariant &payload);

    void setCreateObjectFn(CreateObjectFn fn);
    void setReleaseObjectFn(ReleaseObjectFn fn);

    QVariantMap createObject(const QVariantMap &opts);
    void releaseObject(int ref);

    void registerProxy(const QString &objectName, LObjectProxy *proxy);
    void unregisterProxy(const QString &objectName, LObjectProxy *proxy);

Q_SIGNALS:
    // emitted when QML invokes a method on an LObject; the host forwards it to Lua
    void invoked(int ref, const QString &method, const QVariantList &args);

private:
    explicit LObjectManager(QObject *parent = nullptr);
    void onValueChanged(const QVariant &data);
    void onSignal(const QVariant &data);

    CreateObjectFn m_createObjectFn;
    ReleaseObjectFn m_releaseObjectFn;

    QHash<QString, LObjectProxy *> m_maps;
};

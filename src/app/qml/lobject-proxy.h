// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QQmlPropertyMap>
#include <QVariant>
#include <QtQml>

class LObjectProxy : public QQmlPropertyMap
{
    Q_OBJECT
    QML_NAMED_ELEMENT(LuaObject)

    Q_PROPERTY(QVariantMap opts READ opts WRITE setOpts REQUIRED)
    Q_PROPERTY(QObject *parent READ parent WRITE setParent)

public:
    explicit LObjectProxy(QObject *parent = nullptr);
    ~LObjectProxy() override;

    QVariantMap opts();
    void setOpts(QVariantMap mp);

    Q_INVOKABLE void invoke(const QString &method, const QVariantList &args = QVariantList());

Q_SIGNALS:
    void invoked(int ref, const QString &method, const QVariantList &args);
    void signalEmitted(const QString &name, const QVariant &data);

private:
    bool initialized = false;
    int m_refIndex = -1;
    QStringList m_invokables;

    QVariantMap m_opts;
};

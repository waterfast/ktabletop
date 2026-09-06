// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QQmlPropertyMap>
#include <QVariant>
#include <QtQml>

class LObjectProxy : public QQmlPropertyMap
{
    Q_OBJECT
    QML_ELEMENT

public:
    explicit LObjectProxy(QObject *parent = nullptr);

    Q_INVOKABLE void invoke(const QString &method, const QVariant &args = QVariant());

Q_SIGNALS:
    void invoked(const QString &method, const QVariant &args);
    void signalEmitted(const QString &name, const QVariant &data);
};

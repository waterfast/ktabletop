// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lobject-proxy.h"

LObjectProxy::LObjectProxy(QObject *parent)
    : QQmlPropertyMap(this, parent)
{
}

void LObjectProxy::invoke(const QString &method, const QVariant &args)
{
    Q_EMIT invoked(method, args);
}

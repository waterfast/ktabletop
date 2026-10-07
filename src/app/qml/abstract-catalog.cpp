// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "abstract-catalog.h"

AbstractCatalog::AbstractCatalog(QObject *parent)
    : QObject(parent)
{
}

AbstractCatalog::~AbstractCatalog() = default;

QString AbstractCatalog::i18n(const QString &msg) const
{
    return msg;
}

QString AbstractCatalog::i18nc(const QString &ctx, const QString &msg) const
{
    Q_UNUSED(ctx);
    return msg;
}

QString AbstractCatalog::i18np(const QString &singular, const QString &plural, int n) const
{
    return n == 1 ? singular : plural;
}

QString AbstractCatalog::i18ncp(const QString &ctx, const QString &singular, const QString &plural, int n) const
{
    Q_UNUSED(ctx);
    return n == 1 ? singular : plural;
}

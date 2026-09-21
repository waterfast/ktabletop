#pragma once

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QString>
#include <QVariant>

namespace KTabletopUtils
{

template<typename... Args>
QSqlQuery execQuery(const QSqlDatabase &db, const QString &sql, const Args &...args)
{
    QSqlQuery query(db);
    query.prepare(sql);
    auto _ = {0, (query.addBindValue(args), 0)...};
    query.exec();
    return query;
}

} // namespace KTabletopUtils
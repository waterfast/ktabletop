#include "db-thread.h"

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlRecord>

#include <QEventLoop>

using namespace Qt::StringLiterals;

class QueryWorker : public QObject
{
    Q_OBJECT
public:
    QueryWorker(const QString &name)
        : dbName(name)
    {
    }

public Q_SLOTS:
    void query(std::shared_ptr<QPromise<DbThread::DbResult>> promise, const QString sql, const QVariantList values);

private:
    QString dbName;
};

void QueryWorker::query(std::shared_ptr<QPromise<DbThread::DbResult>> promise, const QString sql, const QVariantList values)
{
    QSqlQuery query(QSqlDatabase::database(dbName));
    if (values.empty()) {
        query.exec(sql);
    } else {
        query.prepare(sql);
        for (const auto &v : values) {
            query.addBindValue(v);
        }
        query.exec();
    }

    const QSqlError err = query.lastError();
    QList<QVariantList> rows;
    if (!err.isValid() && query.isSelect()) {
        const QSqlRecord rec = query.record();
        while (query.next()) {
            QVariantList row;
            row.reserve(rec.count());
            for (int i = 0; i < rec.count(); ++i) {
                row.append(query.value(i));
            }
            rows.append(std::move(row));
        }
    }
    if (err.isValid()) {
        qWarning().noquote() << dbName << ": error occurred when executing SQL: query=" << sql << " error=" << err.text();
    }
    promise->emplaceResult(err, std::move(rows));
    promise->finish();
}

#include "db-thread.moc"

// -------------------------------------------------

DbThread::DbThread(QObject *parent, const QString &connectionName, const QString &dbFilePath)
    : QThread(parent)
    , m_connectionName(connectionName)
    , m_dbFilePath(dbFilePath)
{
    QEventLoop loop;
    connect(this, &DbThread::ready, &loop, &QEventLoop::quit);
    start();
    loop.exec();
}

DbThread::~DbThread()
{
    if (isRunning()) {
        quit();
        wait();
    }
}

void DbThread::run()
{
    QSqlDatabase db = QSqlDatabase::addDatabase(u"QSQLITE"_s, m_connectionName);
    db.setDatabaseName(m_dbFilePath);
    if (!db.open()) {
        qFatal() << "DbThread cannot open" << m_dbFilePath << db.lastError().text();
    }

    QueryWorker worker(m_connectionName);
    connect(this, &DbThread::queryReady, &worker, &QueryWorker::query);

    Q_EMIT ready();

    exec();

    db.close();
    QSqlDatabase::removeDatabase(m_connectionName);
}

void DbThread::execMultiSql(const QString &sql)
{
    const auto sqlList = sql.split(u";"_s);

    // do not support transaction and rollback;
    // this function should only be used on executing sql schema files
    // maybe will support transactions on day.
    for (auto &stmt : sqlList) {
        if (stmt.simplified().isEmpty())
            continue;
        auto result = execQuerySync(stmt);
        auto &err = result.first;
        if (err.isValid()) {
            break;
        }
    }
}

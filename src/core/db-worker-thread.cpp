#include "db-worker-thread.h"

#include <QSqlDatabase>
#include <QSqlQuery>
#include <QSqlRecord>

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
    void query(std::shared_ptr<QPromise<DbWorkerThread::DbResult>> promise, const QString sql, const QVariantList values);

private:
    QString dbName;
};

void QueryWorker::query(std::shared_ptr<QPromise<DbWorkerThread::DbResult>> promise, const QString sql, const QVariantList values)
{
    QSqlQuery query(QSqlDatabase::database(dbName));
    query.prepare(sql);
    for (const auto &v : values) {
        query.addBindValue(v);
    }
    query.exec();

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
    promise->emplaceResult(err, std::move(rows));
    promise->finish();
}

#include "db-worker-thread.moc"

// -------------------------------------------------

DbWorkerThread::DbWorkerThread(QObject *parent, const QString &connectionName, const QString &dbFilePath)
    : QThread(parent)
    , m_connectionName(connectionName)
    , m_dbFilePath(dbFilePath)
{
    start();
}

DbWorkerThread::~DbWorkerThread()
{
    if (isRunning()) {
        quit();
        wait();
    }
}

void DbWorkerThread::run()
{
    QSqlDatabase db = QSqlDatabase::addDatabase(u"QSQLITE"_s, m_connectionName);
    db.setDatabaseName(m_dbFilePath);
    if (!db.open()) {
        qWarning() << "DbWorkerThread cannot open" << m_dbFilePath << db.lastError().text();
    }

    QueryWorker worker(m_connectionName);
    connect(this, &DbWorkerThread::queryReady, &worker, &QueryWorker::query);

    exec();

    db.close();
    QSqlDatabase::removeDatabase(m_connectionName);
}

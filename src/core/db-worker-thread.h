#pragma once

#include <QFuture>
#include <QPromise>
#include <QSqlError>
#include <QThread>

class DbWorkerThread : public QThread
{
    Q_OBJECT

public:
    using DbResult = std::pair<QSqlError, QList<QVariantList>>;

    DbWorkerThread(QObject *parent, const QString &connectionName, const QString &dbFilePath);
    ~DbWorkerThread();

    template<typename... Args>
    QFuture<DbResult> execQuery(const QString &sql, const Args &...args)
    {
        auto promise = std::make_shared<QPromise<DbResult>>();
        promise->start();
        QFuture<DbResult> future = promise->future();

        Q_EMIT queryReady(std::move(promise), sql, QVariantList{args...});
        return future;
    }

Q_SIGNALS:
    void queryReady(std::shared_ptr<QPromise<DbResult>> promise, const QString sql, const QVariantList values);

protected:
    void run() override;

private:
    QString m_connectionName;
    QString m_dbFilePath;
};

#pragma once

#include <QObject>
#include <QSqlDatabase>

class PackMan : public QObject
{
    Q_OBJECT

public:
    PackMan(QObject *parent = nullptr);
    ~PackMan();

    QString getPackSummary();
    QStringList getDisabledPacks();
    void loadSummary(const QString &, bool useThread = false);
    int downloadNewPack(const QString &url, bool useThread = false);
    void enablePack(const QString &pack);
    void disablePack(const QString &pack);
    int updatePack(const QString &pack, const QString &hash);
    int upgradePack(const QString &pack);
    void removePack(const QString &pack);
    QString listPackages();

    void forceCheckoutMaster(const QString &pack);

    void syncCommitHashToDatabase();

private:
    QStringList disabled_packs;
    QSqlDatabase db;

    void sanitizePackageDb(const QString &packname);
};

extern PackMan *Pacman;

#pragma once

#include <QObject>
#include <QSqlDatabase>

struct PluginManifest {
    bool valid = false;
    QString name;

    static PluginManifest fromJson(const QJsonObject &obj);
};

class PackMan : public QObject
{
    Q_OBJECT

public:
    static PackMan *instance();
    static bool initialized();
    static void destroy();
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

    QStringList listPluginPaths();

    void forceCheckoutMaster(const QString &pack);

    void syncCommitHashToDatabase();

private:
    explicit PackMan(QObject *parent = nullptr);
    QStringList disabled_packs;
    QSqlDatabase db;

    void sanitizePackageDb(const QString &packname);
};

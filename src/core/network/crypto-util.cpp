#include "crypto-util.h"

#include <QFile>

#include <openssl/bio.h>
#include <openssl/core_names.h>
#include <openssl/kdf.h>
#include <openssl/pem.h>
#include <openssl/rand.h>

namespace KTabletopCrypto
{

EVP_PKEY *generateEd25519KeyPairs()
{
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_ED25519, nullptr);
    if (!ctx) {
        return nullptr;
    }

    EVP_PKEY *pkey = nullptr;
    if (EVP_PKEY_keygen_init(ctx) <= 0 || EVP_PKEY_keygen(ctx, &pkey) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return nullptr;
    }

    EVP_PKEY_CTX_free(ctx);
    return pkey;
}

bool writeKeyPair(const QString &privPath, const QString &pubPath, EVP_PKEY *pkey)
{
    const QByteArray priv = privPath.toUtf8();
    const QByteArray pub = pubPath.toUtf8();
    bool ok = true;

    BIO *privBio = BIO_new_file(priv.constData(), "w");
    if (!privBio || PEM_write_bio_PrivateKey(privBio, pkey, nullptr, nullptr, 0, nullptr, nullptr) != 1) {
        ok = false;
    }
    BIO_free_all(privBio);

    BIO *pubBio = BIO_new_file(pub.constData(), "w");
    if (!pubBio || PEM_write_bio_PUBKEY(pubBio, pkey) != 1) {
        ok = false;
    }
    BIO_free_all(pubBio);

    if (ok) {
        QFile::setPermissions(privPath, QFileDevice::ReadOwner | QFileDevice::WriteOwner);
    }
    return ok;
}

EVP_PKEY *loadPrivateKey(const QString &path)
{
    const QByteArray p = path.toUtf8();
    BIO *bio = BIO_new_file(p.constData(), "r");
    if (!bio) {
        return nullptr;
    }

    EVP_PKEY *pkey = PEM_read_bio_PrivateKey(bio, nullptr, nullptr, nullptr);
    BIO_free_all(bio);
    return pkey;
}

QByteArray generateNonce(int length)
{
    QByteArray nonce(length, Qt::Uninitialized);
    if (RAND_bytes(reinterpret_cast<unsigned char *>(nonce.data()), length) != 1) {
        return QByteArray();
    }
    return nonce;
}

EVP_PKEY *generateX25519KeyPairs()
{
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_id(EVP_PKEY_X25519, nullptr);
    if (!ctx) {
        return nullptr;
    }

    EVP_PKEY *pkey = nullptr;
    if (EVP_PKEY_keygen_init(ctx) <= 0 || EVP_PKEY_keygen(ctx, &pkey) <= 0) {
        EVP_PKEY_CTX_free(ctx);
        return nullptr;
    }

    EVP_PKEY_CTX_free(ctx);
    return pkey;
}

QByteArray x25519RawPublicKey(EVP_PKEY *pkey)
{
    size_t len = 0;
    if (EVP_PKEY_get_raw_public_key(pkey, nullptr, &len) != 1) {
        return QByteArray();
    }

    QByteArray pub(len, Qt::Uninitialized);
    if (EVP_PKEY_get_raw_public_key(pkey, reinterpret_cast<unsigned char *>(pub.data()), &len) != 1) {
        return QByteArray();
    }

    pub.resize(len);
    return pub;
}

QByteArray ed25519Sign(EVP_PKEY *privateKey, const QByteArray &data)
{
    if (!privateKey) {
        return QByteArray();
    }

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) {
        return QByteArray();
    }

    const auto *bytes = reinterpret_cast<const unsigned char *>(data.constData());
    QByteArray signature;
    size_t sigLen = 0;
    bool ok = false;

    if (EVP_DigestSignInit(ctx, nullptr, nullptr, nullptr, privateKey) == 1 && EVP_DigestSign(ctx, nullptr, &sigLen, bytes, data.size()) == 1) {
        signature.resize(sigLen);
        if (EVP_DigestSign(ctx, reinterpret_cast<unsigned char *>(signature.data()), &sigLen, bytes, data.size()) == 1) {
            signature.resize(sigLen);
            ok = true;
        }
    }

    EVP_MD_CTX_free(ctx);
    return ok ? signature : QByteArray();
}

EVP_PKEY *loadPublicKeyPem(const QByteArray &pem)
{
    BIO *bio = BIO_new_mem_buf(pem.constData(), pem.size());
    if (!bio) {
        return nullptr;
    }

    EVP_PKEY *pkey = PEM_read_bio_PUBKEY(bio, nullptr, nullptr, nullptr);
    BIO_free_all(bio);
    return pkey;
}

bool ed25519Verify(EVP_PKEY *publicKey, const QByteArray &data, const QByteArray &signature)
{
    if (!publicKey) {
        return false;
    }

    EVP_MD_CTX *ctx = EVP_MD_CTX_new();
    if (!ctx) {
        return false;
    }

    bool ok = EVP_DigestVerifyInit(ctx, nullptr, nullptr, nullptr, publicKey) == 1
        && EVP_DigestVerify(ctx,
                            reinterpret_cast<const unsigned char *>(signature.constData()),
                            signature.size(),
                            reinterpret_cast<const unsigned char *>(data.constData()),
                            data.size())
            == 1;

    EVP_MD_CTX_free(ctx);
    return ok;
}

QByteArray x25519DeriveShared(EVP_PKEY *privateKey, const QByteArray &peerEphPublicKey)
{
    if (!privateKey || peerEphPublicKey.isEmpty()) {
        return QByteArray();
    }

    EVP_PKEY *peerKey =
        EVP_PKEY_new_raw_public_key(EVP_PKEY_X25519, nullptr, reinterpret_cast<const unsigned char *>(peerEphPublicKey.constData()), peerEphPublicKey.size());
    if (!peerKey) {
        return QByteArray();
    }

    QByteArray shared;
    EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(privateKey, nullptr);
    if (ctx && EVP_PKEY_derive_init(ctx) == 1 && EVP_PKEY_derive_set_peer(ctx, peerKey) == 1) {
        size_t len = 0;
        if (EVP_PKEY_derive(ctx, nullptr, &len) == 1) {
            shared.resize(len);
            if (EVP_PKEY_derive(ctx, reinterpret_cast<unsigned char *>(shared.data()), &len) != 1) {
                shared.clear();
            } else {
                shared.resize(len);
            }
        }
    }

    EVP_PKEY_CTX_free(ctx);
    EVP_PKEY_free(peerKey);
    return shared;
}

QByteArray hkdfSha256(const QByteArray &ikm, const QByteArray &salt, const QByteArray &info, int length)
{
    if (length <= 0) {
        return QByteArray();
    }

    EVP_KDF *kdf = EVP_KDF_fetch(nullptr, "HKDF", nullptr);
    if (!kdf) {
        return QByteArray();
    }

    EVP_KDF_CTX *ctx = EVP_KDF_CTX_new(kdf);
    EVP_KDF_free(kdf);
    if (!ctx) {
        return QByteArray();
    }

    OSSL_PARAM params[5];
    int i = 0;
    params[i++] = OSSL_PARAM_construct_utf8_string(OSSL_KDF_PARAM_DIGEST, const_cast<char *>("SHA256"), 0);
    params[i++] = OSSL_PARAM_construct_octet_string(OSSL_KDF_PARAM_KEY, const_cast<char *>(ikm.constData()), ikm.size());
    if (!salt.isEmpty()) {
        params[i++] = OSSL_PARAM_construct_octet_string(OSSL_KDF_PARAM_SALT, const_cast<char *>(salt.constData()), salt.size());
    }
    if (!info.isEmpty()) {
        params[i++] = OSSL_PARAM_construct_octet_string(OSSL_KDF_PARAM_INFO, const_cast<char *>(info.constData()), info.size());
    }
    params[i] = OSSL_PARAM_construct_end();

    QByteArray out(length, Qt::Uninitialized);
    if (EVP_KDF_derive(ctx, reinterpret_cast<unsigned char *>(out.data()), length, params) != 1) {
        out.clear();
    }

    EVP_KDF_CTX_free(ctx);
    return out;
}

QByteArray aesGcmEncrypt(const QByteArray &key, const QByteArray &iv, const QByteArray &plaintext)
{
    if (key.size() != 32 || iv.isEmpty()) {
        return QByteArray();
    }

    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return QByteArray();
    }

    QByteArray out(plaintext.size() + 16, Qt::Uninitialized);
    bool ok = false;
    int len = 0;
    int total = 0;

    if (EVP_EncryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) == 1 && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, iv.size(), nullptr) == 1
        && EVP_EncryptInit_ex(ctx,
                              nullptr,
                              nullptr,
                              reinterpret_cast<const unsigned char *>(key.constData()),
                              reinterpret_cast<const unsigned char *>(iv.constData()))
            == 1
        && EVP_EncryptUpdate(ctx,
                             reinterpret_cast<unsigned char *>(out.data()),
                             &len,
                             reinterpret_cast<const unsigned char *>(plaintext.constData()),
                             plaintext.size())
            == 1) {
        total = len;
        if (EVP_EncryptFinal_ex(ctx, reinterpret_cast<unsigned char *>(out.data()) + total, &len) == 1) {
            total += len;
            if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_GET_TAG, 16, reinterpret_cast<unsigned char *>(out.data()) + total) == 1) {
                total += 16;
                out.resize(total);
                ok = true;
            }
        }
    }

    EVP_CIPHER_CTX_free(ctx);
    return ok ? out : QByteArray();
}

QByteArray aesGcmDecrypt(const QByteArray &key, const QByteArray &iv, const QByteArray &ctTag)
{
    if (key.size() != 32 || iv.isEmpty() || ctTag.size() < 16) {
        return QByteArray();
    }

    const int ctLen = ctTag.size() - 16;
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    if (!ctx) {
        return QByteArray();
    }

    QByteArray out(ctLen, Qt::Uninitialized);
    bool ok = false;
    int len = 0;
    int total = 0;

    if (EVP_DecryptInit_ex(ctx, EVP_aes_256_gcm(), nullptr, nullptr, nullptr) == 1 && EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_IVLEN, iv.size(), nullptr) == 1
        && EVP_DecryptInit_ex(ctx,
                              nullptr,
                              nullptr,
                              reinterpret_cast<const unsigned char *>(key.constData()),
                              reinterpret_cast<const unsigned char *>(iv.constData()))
            == 1
        && EVP_DecryptUpdate(ctx, reinterpret_cast<unsigned char *>(out.data()), &len, reinterpret_cast<const unsigned char *>(ctTag.constData()), ctLen)
            == 1) {
        total = len;
        if (EVP_CIPHER_CTX_ctrl(ctx, EVP_CTRL_GCM_SET_TAG, 16, const_cast<char *>(ctTag.constData()) + ctLen) == 1) {
            if (EVP_DecryptFinal_ex(ctx, reinterpret_cast<unsigned char *>(out.data()) + total, &len) == 1) {
                total += len;
                out.resize(total);
                ok = true;
            }
        }
    }

    EVP_CIPHER_CTX_free(ctx);
    return ok ? out : QByteArray();
}

} // namespace KTabletopCrypto

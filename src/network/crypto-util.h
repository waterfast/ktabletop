#pragma once

#include <QByteArray>
#include <QString>

#include <openssl/evp.h>

namespace KTabletopCrypto
{

// Server starts: load ed25519 key pairs, if not exists then generate one
EVP_PKEY *generateEd25519KeyPairs();
bool writeKeyPair(const QString &privPath, const QString &pubPath, EVP_PKEY *pkey);
EVP_PKEY *loadPrivateKey(const QString &path);

// Handshake stage 1: Client generate nonce -> send to server
QByteArray generateNonce(int length = 32);

// Handshake stage 2: Server generates ephemeral keys, sign (text || nonce || eph_pub) with my ed25519 priv key
//   then send my ed25519 public key, signature and my eph_pub key to client.
EVP_PKEY *generateX25519KeyPairs();
QByteArray x25519RawPublicKey(EVP_PKEY *pkey);
QByteArray ed25519Sign(EVP_PKEY *privateKey, const QByteArray &data);
// Then client side parse ed25519 public key, and use it to verify the signature.
EVP_PKEY *loadPublicKeyPem(const QByteArray &pem);
bool ed25519Verify(EVP_PKEY *publicKey, const QByteArray &data, const QByteArray &signature);

// Handshake stage 3 and establish: Client sends its ephemeral public key to server,
//   then both side derive an AES key by local private key and peer public key plus HKDF
QByteArray x25519DeriveShared(EVP_PKEY *privateKey, const QByteArray &peerEphPublicKey);
QByteArray hkdfSha256(const QByteArray &ikm, const QByteArray &salt, const QByteArray &info, int length);

// After established, packet.data will be encrypted by AES-256-GCM
QByteArray aesGcmEncrypt(const QByteArray &key, const QByteArray &iv, const QByteArray &plaintext);
QByteArray aesGcmDecrypt(const QByteArray &key, const QByteArray &iv, const QByteArray &ctTag);

} // namespace KTabletopCrypto

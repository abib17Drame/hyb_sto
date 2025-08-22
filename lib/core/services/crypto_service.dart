import 'package:pointycastle/export.dart' as pc;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:asn1lib/asn1lib.dart';

// Modèle pour contenir la paire de clés
class PaireDeCles {
  final pc.RSAPublicKey clePublique;
  final pc.RSAPrivateKey clePrivee;

  PaireDeCles(this.clePublique, this.clePrivee);
}

// Service pour gérer les opérations de cryptographie
class CryptoService {

  // Génère une nouvelle paire de clés RSA
  PaireDeCles genererPaireDeClesRSA() {
    final keyGen = pc.RSAKeyGenerator()
      ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
        _getSecureRandom(),
      ));

    final pair = keyGen.generateKeyPair();
    return PaireDeCles(pair.publicKey as pc.RSAPublicKey, pair.privateKey as pc.RSAPrivateKey);
  }

  // Encode une clé publique au format PEM PKCS#1
  String encoderClePubliqueEnPem(pc.RSAPublicKey clePublique) {
    var algorithmSeq = ASN1Sequence();
    var algorithmAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x6, 0x9, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0xd, 0x1, 0x1, 0x1]));
    var paramsAsn1Obj = ASN1Object.fromBytes(Uint8List.fromList([0x5, 0x0]));
    algorithmSeq.add(algorithmAsn1Obj);
    algorithmSeq.add(paramsAsn1Obj);

    var publicKeySeq = ASN1Sequence();
    publicKeySeq.add(ASN1Integer(clePublique.modulus!));
    publicKeySeq.add(ASN1Integer(clePublique.exponent!));
    var publicKeyBitString = ASN1BitString(publicKeySeq.encodedBytes);

    var topLevelSeq = ASN1Sequence();
    topLevelSeq.add(algorithmSeq);
    topLevelSeq.add(publicKeyBitString);
    var dataBase64 = base64.encode(topLevelSeq.encodedBytes);

    return """-----BEGIN PUBLIC KEY-----\n$dataBase64\n-----END PUBLIC KEY-----""";
  }

  // Encode une clé privée au format PEM PKCS#1
  String encoderClePriveeEnPem(pc.RSAPrivateKey clePrivee) {
    var version = ASN1Integer(BigInt.from(0));
    var modulus = ASN1Integer(clePrivee.n!);
    var publicExponent = ASN1Integer(clePrivee.exponent!);
    var privateExponent = ASN1Integer(clePrivee.d!);
    var prime1 = ASN1Integer(clePrivee.p!);
    var prime2 = ASN1Integer(clePrivee.q!);
    var exponent1 = ASN1Integer(clePrivee.d! % (clePrivee.p! - BigInt.from(1)));
    var exponent2 = ASN1Integer(clePrivee.d! % (clePrivee.q! - BigInt.from(1)));
    var coefficient = ASN1Integer(clePrivee.q!.modInverse(clePrivee.p!));

    var topLevelSeq = ASN1Sequence();
    topLevelSeq.add(version);
    topLevelSeq.add(modulus);
    topLevelSeq.add(publicExponent);
    topLevelSeq.add(privateExponent);
    topLevelSeq.add(prime1);
    topLevelSeq.add(prime2);
    topLevelSeq.add(exponent1);
    topLevelSeq.add(exponent2);
    topLevelSeq.add(coefficient);

    var dataBase64 = base64.encode(topLevelSeq.encodedBytes);
    return """-----BEGIN RSA PRIVATE KEY-----\n$dataBase64\n-----END RSA PRIVATE KEY-----""";
  }

  // Fournit un générateur de nombres aléatoires sécurisé
  pc.SecureRandom _getSecureRandom() {
    final secureRandom = pc.FortunaRandom();
    final seedSource = Random.secure();
    final seeds = <int>[];
    for (int i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(255));
    }
    secureRandom.seed(pc.KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}

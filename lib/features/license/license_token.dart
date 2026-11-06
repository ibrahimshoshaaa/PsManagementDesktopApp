import 'dart:convert';

import 'package:cryptography/cryptography.dart';

const licenseClockTolerance = Duration(minutes: 2);
const licensePublicKey = String.fromEnvironment('PS_LICENSE_PUBLIC_KEY');

enum LicenseProblem {
  unconfigured,
  invalid,
  otherDevice,
  expired,
  clock,
}

class LicenseException implements Exception {
  const LicenseException(this.problem);
  final LicenseProblem problem;
}

Future<DateTime> verifyLicense({
  required String token,
  required String deviceId,
  required DateTime now,
  String publicKey = licensePublicKey,
}) async {
  final List<int> key;
  try {
    key = base64Url.decode(base64Url.normalize(publicKey));
    if (key.length != 32) throw const FormatException();
  } on FormatException {
    throw const LicenseException(LicenseProblem.unconfigured);
  }

  final parts = token.trim().split('.');
  if (parts.length != 3 || parts.first != 'PS1' || token.length > 2048) {
    throw const LicenseException(LicenseProblem.invalid);
  }
  try {
    final body = base64Url.decode(base64Url.normalize(parts[1]));
    final signature = base64Url.decode(base64Url.normalize(parts[2]));
    if (signature.length != 64) throw const FormatException();
    final trusted = await Ed25519().verify(
      utf8.encode('PS1.${parts[1]}'),
      signature: Signature(signature, publicKey: SimplePublicKey(key, type: KeyPairType.ed25519)),
    );
    if (!trusted) throw const FormatException();

    final claims = jsonDecode(utf8.decode(body));
    if (claims is! Map || claims['product'] != 'ps-desktop-offline') {
      throw const FormatException();
    }
    final issued = DateTime.fromMillisecondsSinceEpoch((claims['iat'] as int) * 1000, isUtc: true);
    final expires = DateTime.fromMillisecondsSinceEpoch((claims['exp'] as int) * 1000, isUtc: true);
    if (!expires.isAfter(issued)) throw const FormatException();
    if (claims['device'] != deviceId) throw const LicenseException(LicenseProblem.otherDevice);
    if (issued.isAfter(now.add(licenseClockTolerance))) {
      throw const LicenseException(LicenseProblem.clock);
    }
    if (!expires.isAfter(now)) throw const LicenseException(LicenseProblem.expired);
    return expires;
  } on LicenseException {
    rethrow;
  } catch (_) {
    throw const LicenseException(LicenseProblem.invalid);
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

Future<String> readLicenseDeviceId() async {
  if (!Platform.isWindows) throw UnsupportedError('Windows device ID required');
  final result = await Process.run('reg.exe', [
    'query',
    r'HKLM\SOFTWARE\Microsoft\Cryptography',
    '/v',
    'MachineGuid',
    '/reg:64',
  ]).timeout(const Duration(seconds: 6));
  final guid = RegExp(
    r'MachineGuid\s+REG_SZ\s+\{?([a-f0-9-]{36})\}?',
    caseSensitive: false,
  ).firstMatch(result.stdout.toString())?.group(1);
  if (result.exitCode != 0 || guid == null) throw StateError('Windows device ID unavailable');
  return sha256.convert(utf8.encode('ps-desktop-offline:v1:${guid.toLowerCase()}'))
      .toString().substring(0, 32).toUpperCase();
}

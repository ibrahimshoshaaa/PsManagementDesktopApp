import 'package:flutter_test/flutter_test.dart';
import 'package:psapp_flutter/features/license/license_token.dart';

const _key = 'bD9kPyUSSF-_WrwGIG2MI0LjFUTWQGEC6jdDeJdBwAA';
const _token = 'PS1.eyJwcm9kdWN0IjoicHMtZGVza3RvcC1vZmZsaW5lIiwiZGV2aWNlIjoiQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUFBQUEiLCJpYXQiOjE3OTM5MjMyMDAsImV4cCI6MTc5NDUyODAwMH0.oyh7W5xt9Xnli1yfzZQnc-E-QhUKAmt9JIQ7oYmlY2b4n2A6w3ep1TA6lp4rJCBfzLDxUfbTK7GxXWlAZ6HqDQ';
const _device = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

void main() {
  test('accepts issuer code on its device during the signed period', () async {
    final expiration = await verifyLicense(
      token: _token,
      deviceId: _device,
      now: DateTime.utc(2026, 11, 7),
      publicKey: _key,
    );
    expect(expiration, DateTime.utc(2026, 11, 13));
  });

  test('rejects copied, expired, altered, and early activation codes', () async {
    Future<DateTime> check({String code = _token, String device = _device, DateTime? now}) =>
        verifyLicense(token: code, deviceId: device, now: now ?? DateTime.utc(2026, 11, 7), publicKey: _key);

    Matcher problem(LicenseProblem reason) => isA<LicenseException>().having((error) => error.problem, 'problem', reason);

    await expectLater(check(device: 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB'), throwsA(problem(LicenseProblem.otherDevice)));
    await expectLater(check(now: DateTime.utc(2026, 11, 13)), throwsA(problem(LicenseProblem.expired)));
    await expectLater(check(now: DateTime.utc(2026, 11, 5)), throwsA(problem(LicenseProblem.clock)));
    await expectLater(check(code: _token.replaceFirst('PS1.', 'PS1.A')), throwsA(problem(LicenseProblem.invalid)));
  });
}

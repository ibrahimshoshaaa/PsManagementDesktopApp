import 'package:drift/drift.dart' show Value;

import '../../data/local/database.dart';
import 'license_token.dart';

class LicenseStore {
  const LicenseStore(this.database);

  final AppDatabase database;

  Future<DateTime?> check(String deviceId, {String? activationCode}) {
    return database.transaction(() async {
      final row = await (database.select(database.desktopLicenses)
            ..where((table) => table.id.equals(0)))
          .getSingleOrNull();
      final token = activationCode?.trim() ?? row?.token;
      if (token == null) return null;

      final now = DateTime.now().toUtc();
      final nowMs = now.millisecondsSinceEpoch;
      final lastSeenMs = row?.lastSeenUtcMs ?? nowMs;
      if (lastSeenMs - nowMs > licenseClockTolerance.inMilliseconds) {
        throw const LicenseException(LicenseProblem.clock);
      }
      final effectiveMs = nowMs > lastSeenMs ? nowMs : lastSeenMs;
      final expires = await verifyLicense(
        token: token,
        deviceId: deviceId,
        now: DateTime.fromMillisecondsSinceEpoch(effectiveMs, isUtc: true),
      );
      await database.into(database.desktopLicenses).insertOnConflictUpdate(
        DesktopLicensesCompanion.insert(id: const Value(0), token: token, lastSeenUtcMs: effectiveMs),
      );
      return expires;
    });
  }
}

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<Directory> getAppBaseDir() async {
  final support = await getApplicationSupportDirectory();
  final directory = Directory(p.join(support.path, 'Offline'));
  return directory.create(recursive: true);
}

LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final directory = await getAppBaseDir();
    return NativeDatabase.createInBackground(
      File(p.join(directory.path, 'ps_app_offline.sqlite')),
    );
  });
}

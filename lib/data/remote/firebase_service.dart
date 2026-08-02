import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ═══════════════════════════════════════════════════════════════════════════
// FirebaseService (Desktop) — منقولة بالظبط من lib/services/firebase_service.dart
// بتاع تطبيق الموبايل (PsManagementMobileApp) عشان الديسكتوب يتكلم مع نفس
// الـ Firebase Realtime Database بنفس البروتوكول تمامًا (REST + SSE يدوي،
// مش الـ Firebase SDK الأصلي — الموبايل نفسه بيستخدم REST+SSE يدوي زي ده بالظبط).
//
// أي حاجة هنا لازم تفضل مطابقة لنسخة الموبايل. لو عدّلت حاجة في الموبايل،
// عدّل هنا كمان (وبالعكس).
//
// المسارات:
//   realtime/devices_state      ← حالة الأجهزة (SSE - فوري)
//   realtime/tables_state       ← حالة التربيزات (SSE - فوري)
//   realtime/drink_tables_state ← حالة تربيزات المشروبات (SSE - فوري)
//   static/                     ← أسعار ومنيو وإعدادات (push عند التعديل، PATCH مش SET)
//   records/history             ← السجلات (append فقط عبر POST)
//   records/daily_summary       ← ملخص المخزون اليومي
//   records/shifts_history      ← الشيفتات المقفولة
//   records/open_shifts         ← الشيفتات المفتوحة حاليًا (قفل بين الأجهزة)
//   archives/ + archive_details/{id} ← أرشيف يومي (إجماليات + تفاصيل منفصلة)
//   yearly_archives/            ← أرشيف سنوي
//   subscription                ← بيانات الاشتراك/التفعيل
//   tournaments                 ← البطولات (on-demand)
//   customer_orders             ← طلبات العملاء
//   activity_logs               ← سجل التدقيق (audit log) — fire & forget
// ═══════════════════════════════════════════════════════════════════════════

class FirebaseService {
  // ══════════════════════════════════════════════════════════════════════════
  // MULTI-PROJECT CONFIG — نفس القيم بالظبط بتاعة الموبايل (نفس الداتابيز!)
  // ══════════════════════════════════════════════════════════════════════════
  static const _projects = <String, Map<String, String>>{
    'ps1_': {
      'url': 'https://ps-harifa-default-rtdb.firebaseio.com',
      'secret': 'loFnECpWdlhEHnzGdPW1VoWKbZPepbgrqDVjTnEY',
    },
    'ps2_': {
      'url': 'https://psmanagementapp-default-rtdb.firebaseio.com',
      'secret': 'uy6vaerRBXq497rXIltP2F5NJCn75dyev9DeHeSF',
    },
  };

  static const _defaultUrl = 'https://ps-harifa-default-rtdb.firebaseio.com';
  static const _defaultSecret = 'loFnECpWdlhEHnzGdPW1VoWKbZPepbgrqDVjTnEY';

  static Map<String, String> _configFor(String? shopId) {
    if (shopId != null && shopId.isNotEmpty) {
      final lower = shopId.toLowerCase();
      for (final entry in _projects.entries) {
        if (lower.startsWith(entry.key.toLowerCase())) return entry.value;
      }
    }
    return {'url': _defaultUrl, 'secret': _defaultSecret};
  }

  static String? _currentShopId;
  static void setShopId(String? id) => _currentShopId = id;
  static String? get currentShopId => _currentShopId;

  static String _url(String path) {
    final cfg = _configFor(_currentShopId);
    return '${cfg["url"]}/$path.json?auth=${cfg["secret"]}';
  }

  static String _urlWithQuery(String path, Map<String, String> params) {
    final cfg = _configFor(_currentShopId);
    final base = '${cfg["url"]}/$path.json?auth=${cfg["secret"]}';
    if (params.isEmpty) return base;
    final extra = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base&$extra';
  }

  // ─── CRUD الأساسي ──────────────────────────────────────────────────────────

  static Future<dynamic> get(String path) async {
    try {
      final r = await http.get(Uri.parse(_url(path))).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (e) {
      // ignore: avoid_print
      print('Firebase GET error [$path]: $e');
    }
    return null;
  }

  static Future<bool> set(String path, dynamic data) async {
    try {
      final r = await http
          .put(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('Firebase SET error [$path]: $e');
      return false;
    }
  }

  static Future<bool> patch(String path, dynamic data) async {
    try {
      final r = await http
          .patch(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('Firebase PATCH error [$path]: $e');
      return false;
    }
  }

  static Future<bool> post(String path, dynamic data) async {
    try {
      final r = await http
          .post(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('Firebase POST error [$path]: $e');
      return false;
    }
  }

  static Future<String?> push(String path, dynamic data) async {
    try {
      final r = await http
          .post(Uri.parse(_url(path)), body: jsonEncode(data))
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return jsonDecode(r.body)['name'];
    } catch (e) {
      // ignore: avoid_print
      print('Firebase PUSH error [$path]: $e');
    }
    return null;
  }

  static Future<bool> delete(String path) async {
    try {
      final r = await http.delete(Uri.parse(_url(path))).timeout(const Duration(seconds: 10));
      return r.statusCode == 200;
    } catch (e) {
      // ignore: avoid_print
      print('Firebase DELETE error [$path]: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // مسارات المحل
  // ═══════════════════════════════════════════════════════════════════════════

  static String devicesStatePath(String shopId) => 'shops/$shopId/realtime/devices_state';
  static String tablesStatePath(String shopId) => 'shops/$shopId/realtime/tables_state';
  static String drinkTablesStatePath(String shopId) => 'shops/$shopId/realtime/drink_tables_state';
  static String tablesPath(String shopId) => 'shops/$shopId/operational/tables';
  static String drinkTablesPath(String shopId) => 'shops/$shopId/operational/drink_tables';
  static String staticDataPath(String shopId) => 'shops/$shopId/static';
  static String pricesPath(String shopId) => 'shops/$shopId/static/prices';
  static String menuPath(String shopId) => 'shops/$shopId/static/menu';
  static String inventoryPath(String shopId) => 'shops/$shopId/static/inventory';
  static String settingsPath(String shopId) => 'shops/$shopId/static/settings';
  static String cashiersPath(String shopId) => 'shops/$shopId/static/cashiers';
  static String debtsPath(String shopId) => 'shops/$shopId/static/debts';
  static String historyPath(String shopId) => 'shops/$shopId/records/history';
  static String dailySummaryPath(String shopId) => 'shops/$shopId/records/daily_summary';
  static String shiftsHistoryPath(String shopId) => 'shops/$shopId/records/shifts_history';
  static String openShiftsPath(String shopId) => 'shops/$shopId/records/open_shifts';
  static String shopArchivePath(String shopId) => 'shops/$shopId/archives';
  static String shopArchiveDetailsPath(String shopId) => 'shops/$shopId/archive_details';
  static String shopArchiveDetailPath(String shopId, String archiveId) =>
      'shops/$shopId/archive_details/$archiveId';
  static String shopYearlyArchivePath(String shopId) => 'shops/$shopId/yearly_archives';
  static String shopSubscriptionPath(String shopId) => 'shops/$shopId/subscription';
  static String shopTournamentsPath(String shopId) => 'shops/$shopId/tournaments';
  static String customerOrdersPath(String shopId) => 'shops/$shopId/customer_orders';
  static String activityLogsPath(String shopId) => 'shops/$shopId/activity_logs';

  // ═══════════════════════════════════════════════════════════════════════════
  // Push — نفس أسماء وسلوك الموبايل بالظبط (بما فيها الـ PATCH الجزئي
  // لجهاز/تربيزة واحدة، وحذف session_log من الـ realtime sync)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<bool> pushDevicesStateSlim(
      String shopId, List<Map<String, dynamic>> devicesState, String senderId) async {
    final slim = devicesState.map((d) {
      final copy = Map<String, dynamic>.from(d);
      copy.remove('session_log');
      return copy;
    }).toList();
    return set(devicesStatePath(shopId), {
      'devices': slim,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  static Future<bool> pushSingleDeviceState(
      String shopId, int deviceIndex, Map<String, dynamic> deviceData, String senderId) async {
    final slim = Map<String, dynamic>.from(deviceData)..remove('session_log');
    return patch(devicesStatePath(shopId), {
      'devices/$deviceIndex': slim,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  static Future<bool> pushTablesState(
      String shopId, List<Map<String, dynamic>> tables, String senderId) async {
    return set(tablesStatePath(shopId), {
      'tables': tables,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  static Future<bool> pushDrinkTablesState(
      String shopId, List<Map<String, dynamic>> drinkTables, String senderId) async {
    return set(drinkTablesStatePath(shopId), {
      'drink_tables': drinkTables,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  static Future<bool> pushSingleDrinkTable(
      String shopId, int index, Map<String, dynamic> drinkTableData, String senderId) async {
    return patch(drinkTablesStatePath(shopId), {
      'drink_tables/$index': drinkTableData,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'sender_id': senderId,
    });
  }

  static Future<bool> pushTables(String shopId, List<Map<String, dynamic>> tables) =>
      set(tablesPath(shopId), tables);

  static Future<bool> pushDrinkTables(String shopId, List<Map<String, dynamic>> drinkTables) =>
      set(drinkTablesPath(shopId), drinkTables);

  /// PATCH مش SET — عشان منمسحش حقول بيكتبها تطبيق تاني (الموبايل) مش
  /// موجودة في الـ payload بتاع الديسكتوب.
  static Future<bool> pushStaticData(String shopId, Map<String, dynamic> staticData,
      [String? senderId]) async {
    final data = Map<String, dynamic>.from(staticData);
    if (senderId != null) data['_sender_id'] = senderId;
    return patch(staticDataPath(shopId), data);
  }

  static Future<bool> appendSingleHistoryRecord(String shopId, Map<String, dynamic> record) =>
      post(historyPath(shopId), record);

  static Future<bool> pushOpenShifts(String shopId, Map<String, dynamic> openShifts,
      [String? senderId]) async {
    final data = Map<String, dynamic>.from(openShifts);
    if (senderId != null) data['_sender_id'] = senderId;
    return set(openShiftsPath(shopId), data);
  }

  static Future<bool> pushShiftsHistory(String shopId, List<Map<String, dynamic>> shifts) =>
      set(shiftsHistoryPath(shopId), shifts);

  static Future<bool> pushDebts(String shopId, List<Map<String, dynamic>> debts) =>
      set(debtsPath(shopId), debts);

  static Future<bool> pushTournaments(String shopId, List<Map<String, dynamic>> tournaments) =>
      set(shopTournamentsPath(shopId), tournaments);

  static Future<String?> pushArchive({
    required String shopId,
    required String date,
    required double totalTime,
    required double totalBuffet,
    required double totalOverall,
  }) {
    return push(shopArchivePath(shopId), {
      'date': date,
      'total_time': totalTime,
      'total_buffet': totalBuffet,
      'total_overall': totalOverall,
    });
  }

  // ─── Archive reads ───────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>?> getArchiveDetails(
      String shopId, String archiveId) async {
    try {
      final data = await get(shopArchiveDetailPath(shopId, archiveId));
      if (data == null || data is! Map) return null;
      final records = data['records'];
      if (records == null) return [];
      if (records is List) {
        return records.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList();
      }
      return [];
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getArchivesList(String shopId) async {
    try {
      final data = await get(shopArchivePath(shopId));
      if (data == null) return [];
      if (data is Map) {
        return data.entries.map((e) {
          final m = Map<String, dynamic>.from(e.value as Map);
          m['_id'] = e.key;
          return m;
        }).toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a['date']?.toString() ?? '');
            final db = DateTime.tryParse(b['date']?.toString() ?? '');
            if (da == null || db == null) return 0;
            return db.compareTo(da);
          });
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Pull — نفس منطق bandwidth optimization بتاع الموبايل بالظبط:
  // static + realtime بس بيتحملوا مباشرة، والباقي (history/debts/tournaments/
  // shifts_history) on-demand فقط.
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<Map<String, dynamic>>?> pullDevicesState(String shopId) async {
    try {
      final data = await get(devicesStatePath(shopId));
      if (data == null || data is! Map) return null;
      final devices = data['devices'];
      if (devices is List) {
        return devices.map((d) => Map<String, dynamic>.from(d as Map)).toList();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getRecentHistory(String shopId, {int limit = 20}) async {
    try {
      final url = _urlWithQuery(historyPath(shopId), {
        'limitToLast': limit.toString(),
        'orderBy': r'"$key"',
      });
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body);
      if (body == null) return [];
      if (body is List) {
        return body.whereType<Map>().map((h) => Map<String, dynamic>.from(h)).toList();
      }
      if (body is Map) {
        return body.values.whereType<Map>().map((h) => Map<String, dynamic>.from(h)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHistoryOnDemand(String shopId, {int limit = 50}) =>
      getRecentHistory(shopId, limit: limit);

  static Future<List<Map<String, dynamic>>> fetchShiftsHistoryOnDemand(String shopId) async {
    try {
      final url = _urlWithQuery(shiftsHistoryPath(shopId), {
        'limitToLast': '50',
        'orderBy': r'"$key"',
      });
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return [];
      final body = jsonDecode(r.body);
      if (body == null) return [];
      if (body is List) {
        return body.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList();
      }
      if (body is Map) {
        return body.values.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchTournamentsOnDemand(String shopId) async {
    try {
      final data = await get(shopTournamentsPath(shopId));
      if (data == null) return [];
      if (data is List) {
        return data.whereType<Map>().map((t) => Map<String, dynamic>.from(t)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> fetchDebtsOnDemand(String shopId) async {
    try {
      final data = await get(debtsPath(shopId));
      if (data == null) return [];
      if (data is List) {
        return data.whereType<Map>().map((d) => Map<String, dynamic>.from(d)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getAllOpenShifts(String shopId) async {
    try {
      final data = await get(openShiftsPath(shopId));
      if (data == null || data is! Map) return {};
      return Map<String, dynamic>.from(data);
    } catch (_) {
      return {};
    }
  }

  /// نفس حيلة الموبايل: بيقارن وقت الجهاز بوقت سيرفر Firebase (من هيدر Date)
  /// عشان يكتشف لو حد غيّر ساعة الجهاز يحايل على انتهاء الاشتراك.
  static Future<Map<String, dynamic>?> getSubscriptionWithTimestamp(String shopId) async {
    try {
      final cfg = _configFor(_currentShopId);
      final subFuture =
          http.get(Uri.parse(_url(shopSubscriptionPath(shopId)))).timeout(const Duration(seconds: 10));
      final timeFuture = http
          .get(Uri.parse('${cfg["url"]}/.json?shallow=true&auth=${cfg["secret"]}'))
          .timeout(const Duration(seconds: 10));

      final results = await Future.wait([subFuture, timeFuture]);
      final subResponse = results[0];
      final timeResponse = results[1];
      if (subResponse.statusCode != 200) return null;

      final subData = jsonDecode(subResponse.body);
      if (subData == null || subData is! Map) return null;
      final result = Map<String, dynamic>.from(subData);

      final dateHeader = timeResponse.headers['date'];
      if (dateHeader != null) {
        try {
          result['_server_time_ms'] = DateTime.parse(dateHeader).millisecondsSinceEpoch;
        } catch (_) {
          result['_server_time_ms'] = DateTime.now().millisecondsSinceEpoch;
        }
      } else {
        result['_server_time_ms'] = DateTime.now().millisecondsSinceEpoch;
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSubscription(String shopId) async {
    final cfg = _configFor(shopId);
    final path = shopSubscriptionPath(shopId);
    final url = '${cfg["url"]}/$path.json?auth=${cfg["secret"]}';
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        if (data == null || data is! Map) return null;
        return Map<String, dynamic>.from(data);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SSE Listeners — نفس منطق الموبايل بالظبط، بما فيه التعامل مع الـ patch
  // الجزئي لجهاز/تربيزة واحدة، ومنع تكرار المعالجة لو إحنا اللي بعتنا (senderId)
  // ═══════════════════════════════════════════════════════════════════════════

  static StreamSubscription<dynamic> listenToDevices(
    String shopId, {
    required void Function(Map<String, dynamic> rawData, List<Map<String, dynamic>> devices) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      devicesStatePath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final eventPath = payload['path'] as String?;
        final eventData = payload['data'];

        if (eventPath != null && eventPath.startsWith('/devices/') && eventData is Map) {
          try {
            final parts = eventPath.split('/');
            if (parts.length >= 3) {
              final idx = int.tryParse(parts[2]);
              if (idx != null) {
                final deviceData = Map<String, dynamic>.from(eventData)..remove('session_log');
                final rootSenderId = payload['sender_id']?.toString() ?? '';
                onData({
                  'sender_id': rootSenderId,
                  'single_device_index': idx,
                  'devices': [deviceData],
                }, [deviceData]);
              }
            }
          } catch (_) {}
          return;
        }

        if (eventData != null && eventData is Map) {
          final devicesList = eventData['devices'];
          if (devicesList is List) {
            try {
              final typed = devicesList.map((d) {
                if (d == null) return <String, dynamic>{};
                final copy = Map<String, dynamic>.from(d as Map);
                copy.remove('session_log');
                return copy;
              }).toList();
              onData(Map<String, dynamic>.from(eventData), typed);
            } catch (_) {}
          }
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToTables(
    String shopId, {
    required void Function(Map<String, dynamic> rawData, List<Map<String, dynamic>> tables) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      tablesStatePath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final eventData = payload['data'];
        if (eventData == null || eventData is! Map) return;
        final tables = eventData['tables'];
        if (tables == null || tables is! List) return;
        try {
          final typed =
              tables.map((t) => t != null ? Map<String, dynamic>.from(t as Map) : <String, dynamic>{}).toList();
          onData(Map<String, dynamic>.from(eventData), typed);
        } catch (_) {}
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToDrinkTables(
    String shopId, {
    String? senderId,
    required void Function(Map<String, dynamic> rawData, List<Map<String, dynamic>> drinkTables) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      drinkTablesStatePath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final eventPath = payload['path'] as String?;
        final eventData = payload['data'];

        if (eventPath != null && eventPath.startsWith('/drink_tables/') && eventData is Map) {
          try {
            final parts = eventPath.split('/');
            if (parts.length >= 3) {
              final idx = int.tryParse(parts[2]);
              if (idx != null) {
                final patchSenderId = payload['sender_id']?.toString() ?? '';
                if (senderId != null && patchSenderId == senderId) return;
                final tableData = Map<String, dynamic>.from(eventData);
                onData({
                  'sender_id': patchSenderId,
                  'single_drink_table_index': idx,
                }, [tableData]);
              }
            }
          } catch (_) {}
          return;
        }

        if (eventData == null || eventData is! Map) return;
        if (senderId != null && eventData['sender_id'] == senderId) return;
        final drinkTables = eventData['drink_tables'];
        if (drinkTables == null || drinkTables is! List) return;
        try {
          final typed = drinkTables
              .map((t) => t != null ? Map<String, dynamic>.from(t as Map) : <String, dynamic>{})
              .toList();
          onData(Map<String, dynamic>.from(eventData), typed);
        } catch (_) {}
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static void _sortHistoryByDate(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final aVal = a['date'] ?? a['timestamp'] ?? a['created_at'];
      final bVal = b['date'] ?? b['timestamp'] ?? b['created_at'];
      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return -1;
      if (bVal == null) return 1;
      if (aVal is num && bVal is num) return aVal.compareTo(bVal);
      return aVal.toString().compareTo(bVal.toString());
    });
  }

  /// استخدمها بس للأدمن (زي الموبايل) — مش في المزامنة العادية للكاشيرين.
  static StreamSubscription<dynamic> listenToHistory(
    String shopId, {
    int limit = 20,
    required void Function(List<Map<String, dynamic>> history) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    final fullUrl = _urlWithQuery(historyPath(shopId), {
      'limitToLast': limit.toString(),
      'orderBy': r'"$key"',
    });
    return _listenRaw(
      fullUrl,
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final data = payload['data'];
        if (data == null) {
          onData([]);
          return;
        }
        if (data is Map) {
          try {
            final typed = data.values.map((h) => Map<String, dynamic>.from(h as Map)).toList();
            _sortHistoryByDate(typed);
            onData(typed);
          } catch (_) {}
        } else if (data is List) {
          try {
            final typed =
                data.map((h) => h != null ? Map<String, dynamic>.from(h as Map) : <String, dynamic>{}).toList();
            _sortHistoryByDate(typed);
            onData(typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToDailySummary(
    String shopId, {
    required void Function(Map<String, int> summary) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      dailySummaryPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final data = payload['data'];
        if (data == null) {
          onData({});
          return;
        }
        if (data is Map) {
          try {
            final typed = Map<String, int>.from(data.map((k, v) => MapEntry(k.toString(), (v as num).toInt())));
            onData(typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToShiftsHistory(
    String shopId, {
    required void Function(List<Map<String, dynamic>> shifts) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      shiftsHistoryPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final data = payload['data'];
        if (data == null) {
          onData([]);
          return;
        }
        if (data is List) {
          try {
            final typed =
                data.map((s) => s != null ? Map<String, dynamic>.from(s as Map) : <String, dynamic>{}).toList();
            onData(typed);
          } catch (_) {}
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToStatic(
    String shopId, {
    String? senderId,
    required void Function(Map<String, dynamic> data) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      staticDataPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final raw = payload['data'];
        if (raw == null || raw is! Map) return;
        try {
          final data = Map<String, dynamic>.from(raw);
          if (senderId != null && data['_sender_id'] == senderId) return;
          data.remove('_sender_id');
          onData(data);
        } catch (_) {}
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  static StreamSubscription<dynamic> listenToOpenShifts(
    String shopId, {
    String? senderId,
    required void Function(Map<String, dynamic> openShifts) onData,
    void Function(Object error)? onError,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    return listen(
      openShiftsPath(shopId),
      onData: (payload) {
        if (payload == null || payload is! Map) return;
        final raw = payload['data'];
        if (raw is Map) {
          final data = Map<String, dynamic>.from(raw);
          if (senderId != null && data['_sender_id'] == senderId) return;
          data.remove('_sender_id');
          onData(data);
        } else {
          onData({});
        }
      },
      onError: onError,
      retryDelay: retryDelay,
    );
  }

  // ─── SSE Core — نفس تنفيذ الموبايل حرفيًا ───────────────────────────────────

  static StreamSubscription<dynamic> listen(
    String path, {
    required void Function(dynamic data) onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    final controller = StreamController<dynamic>.broadcast();
    bool cancelled = false;

    Future<void> connect() async {
      while (!cancelled) {
        http.Client? client;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(_url(path)));
          request.headers['Accept'] = 'text/event-stream';
          request.headers['Cache-Control'] = 'no-cache';
          final response = await client.send(request);

          if (response.statusCode != 200) {
            client.close();
            await Future.delayed(retryDelay);
            continue;
          }

          var buffer = StringBuffer();
          await for (final chunk in response.stream.transform(utf8.decoder)) {
            if (cancelled) break;
            buffer.write(chunk);
            final raw = buffer.toString();
            final blocks = raw.split('\n\n');
            for (var i = 0; i < blocks.length - 1; i++) {
              _processSSEBlock(blocks[i], controller);
            }
            buffer = StringBuffer(blocks.last);
          }
        } catch (e) {
          if (!cancelled) onError?.call(e);
        } finally {
          client?.close();
        }
        if (!cancelled) await Future.delayed(retryDelay);
      }
      if (!controller.isClosed) controller.close();
      onDone?.call();
    }

    connect();
    final subscription = controller.stream.listen(onData, onError: onError);
    return _CancellableSubscription(subscription, onCancel: () => cancelled = true);
  }

  static StreamSubscription<dynamic> _listenRaw(
    String fullUrl, {
    required void Function(dynamic data) onData,
    void Function(Object error)? onError,
    void Function()? onDone,
    Duration retryDelay = const Duration(seconds: 2),
  }) {
    final controller = StreamController<dynamic>.broadcast();
    bool cancelled = false;

    Future<void> connect() async {
      while (!cancelled) {
        http.Client? client;
        try {
          client = http.Client();
          final request = http.Request('GET', Uri.parse(fullUrl));
          request.headers['Accept'] = 'text/event-stream';
          request.headers['Cache-Control'] = 'no-cache';
          final response = await client.send(request);

          if (response.statusCode != 200) {
            client.close();
            await Future.delayed(retryDelay);
            continue;
          }

          var buffer = StringBuffer();
          await for (final chunk in response.stream.transform(utf8.decoder)) {
            if (cancelled) break;
            buffer.write(chunk);
            final raw = buffer.toString();
            final blocks = raw.split('\n\n');
            for (var i = 0; i < blocks.length - 1; i++) {
              _processSSEBlock(blocks[i], controller);
            }
            buffer = StringBuffer(blocks.last);
          }
        } catch (e) {
          if (!cancelled) onError?.call(e);
        } finally {
          client?.close();
        }
        if (!cancelled) await Future.delayed(retryDelay);
      }
      if (!controller.isClosed) controller.close();
      onDone?.call();
    }

    connect();
    final subscription = controller.stream.listen(onData, onError: onError);
    return _CancellableSubscription(subscription, onCancel: () => cancelled = true);
  }

  static void _processSSEBlock(String block, StreamController<dynamic> controller) {
    String? eventType;
    String? dataLine;
    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        eventType = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLine = line.substring(5).trim();
      }
    }
    if ((eventType == 'put' || eventType == 'patch') && dataLine != null) {
      try {
        final parsed = jsonDecode(dataLine);
        if (!controller.isClosed) {
          controller.add({'event': eventType, 'path': parsed['path'], 'data': parsed['data']});
        }
      } catch (_) {}
    }
  }
}

class _CancellableSubscription<T> implements StreamSubscription<T> {
  final StreamSubscription<T> _inner;
  final void Function() onCancel;

  _CancellableSubscription(this._inner, {required this.onCancel});

  @override
  Future<void> cancel() {
    onCancel();
    return _inner.cancel();
  }

  @override
  bool get isPaused => _inner.isPaused;
  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);
  @override
  void resume() => _inner.resume();
  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);
  @override
  void onError(Function? handleError) => _inner.onError(handleError);
  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);
  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture(futureValue);
}

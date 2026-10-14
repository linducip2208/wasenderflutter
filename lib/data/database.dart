/// SQLite lokal: schema terkontrol + migrasi + repository + backup/restore.
/// TIDAK ada enkripsi penuh (jujur): file DB biasa + material sensitif
/// (sesi WA, payload lisensi) disimpan di flutter_secure_storage.
/// Jangan mengklaim "encrypted database".
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

class AppDatabase {
  static const dbName = 'wasender_wabadak.db';
  static const latestVersion = 4;
  Database? _db;

  Database get db {
    final d = _db;
    if (d == null) throw StateError('Database belum dibuka. Panggil open().');
    return d;
  }

  Future<String> dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, dbName);
  }

  Future<Database> open({
    DatabaseFactory? factory,
    String? pathOverride,
  }) async {
    if (_db != null) return _db!;
    final path = pathOverride ?? await dbPath();
    final f = factory ?? databaseFactory;
    _db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: latestVersion,
        onCreate: (d, v) async {
          await _createV1(d);
          await _migrateV2(d);
          await _migrateV3(d);
          await _migrateV4(d);
          await d.insert('schema_migrations', {
            'version': latestVersion,
            'applied_at': DateTime.now().toUtc().toIso8601String(),
          });
        },
        onUpgrade: (d, oldV, newV) async {
          if (oldV < 2) await _migrateV2(d);
          if (oldV < 3) await _migrateV3(d);
          if (oldV < 4) await _migrateV4(d);
          await d.insert('schema_migrations', {
            'version': newV,
            'applied_at': DateTime.now().toUtc().toIso8601String(),
          });
        },
      ),
    );
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Penanganan DB rusak: pindahkan file korup ke berkas cadangan
  /// bertimestamp lalu buat database baru yang kosong.
  Future<void> recoverIfCorrupt(Future<void> Function() opener) async {
    try {
      await opener();
    } catch (e) {
      debugPrint('DB open gagal, recovery: $e');
      try {
        final path = await dbPath();
        final f = File(path);
        if (await f.exists()) {
          await f.rename(
            '$path.corrupt-${DateTime.now().millisecondsSinceEpoch}.bak',
          );
        }
      } catch (_) {}
      _db = null;
      await opener();
    }
  }

  static Future<void> _createV1(DatabaseExecutor d) async {
    await d.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations(
        version INTEGER PRIMARY KEY, applied_at TEXT NOT NULL)''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS contacts(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, msisdn TEXT NOT NULL,
        note TEXT DEFAULT '', labels TEXT DEFAULT '[]',
        consented INTEGER DEFAULT 0, suppressed INTEGER DEFAULT 0,
        archived INTEGER DEFAULT 0, created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL)''');
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_msisdn ON contacts(msisdn)',
    );
    await d.execute('''
      CREATE TABLE IF NOT EXISTS contact_groups(
        id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL)''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS contact_group_members(
        group_id TEXT NOT NULL, contact_id TEXT NOT NULL,
        PRIMARY KEY(group_id, contact_id))''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS message_templates(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, body TEXT NOT NULL,
        category TEXT DEFAULT 'general', created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL)''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS conversations(
        id TEXT PRIMARY KEY, contact_id TEXT, chat_jid TEXT NOT NULL,
        title TEXT NOT NULL, archived INTEGER DEFAULT 0,
        unread INTEGER DEFAULT 0, last_at TEXT,
        created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''');
    await d.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_conv_jid ON conversations(chat_jid)',
    );
    await d.execute('''
      CREATE TABLE IF NOT EXISTS messages(
        id TEXT PRIMARY KEY, conversation_id TEXT NOT NULL,
        direction TEXT NOT NULL, body TEXT DEFAULT '',
        media_path TEXT, mime TEXT, status TEXT DEFAULT 'pending',
        error TEXT DEFAULT '', at TEXT NOT NULL)''');
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_msg_conv ON messages(conversation_id, at)',
    );
    await d.execute('''
      CREATE TABLE IF NOT EXISTS campaigns(
        id TEXT PRIMARY KEY, name TEXT NOT NULL, template_id TEXT,
        body TEXT NOT NULL, status TEXT DEFAULT 'draft',
        scheduled_at TEXT, created_at TEXT NOT NULL)''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS campaign_recipients(
        id TEXT PRIMARY KEY, campaign_id TEXT NOT NULL,
        contact_id TEXT NOT NULL, msisdn TEXT NOT NULL,
        rendered_body TEXT DEFAULT '', status TEXT DEFAULT 'pending',
        attempts INTEGER DEFAULT 0, last_error TEXT DEFAULT '',
        updated_at TEXT NOT NULL,
        UNIQUE(campaign_id, contact_id))''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS message_queue(
        id TEXT PRIMARY KEY, campaign_id TEXT, contact_id TEXT,
        msisdn TEXT NOT NULL, body TEXT NOT NULL, media_path TEXT,
        status TEXT DEFAULT 'pending', attempts INTEGER DEFAULT 0,
        max_attempts INTEGER DEFAULT 3, next_at TEXT,
        last_error TEXT DEFAULT '', created_at TEXT NOT NULL)''');
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_queue_status ON message_queue(status, next_at)',
    );
    await d.execute('''
      CREATE TABLE IF NOT EXISTS delivery_attempts(
        id TEXT PRIMARY KEY, queue_id TEXT NOT NULL, at TEXT NOT NULL,
        result TEXT NOT NULL, detail TEXT DEFAULT '')''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS local_settings(
        key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
    await d.execute('''
      CREATE TABLE IF NOT EXISTS local_audit_logs(
        id TEXT PRIMARY KEY, at TEXT NOT NULL, actor TEXT DEFAULT 'user',
        action TEXT NOT NULL, detail TEXT DEFAULT '')''');
  }

  static Future<void> _migrateV2(DatabaseExecutor d) async {
    // FTS ringan untuk pencarian pesan (fallback LIKE bila FTS5 absen).
    try {
      await d.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
          body, content='messages', content_rowid='rowid')''');
    } catch (_) {}
  }

  static Future<void> _migrateV3(DatabaseExecutor d) async {
    try {
      await d.execute(
        'ALTER TABLE contacts ADD COLUMN source TEXT DEFAULT "manual"',
      );
    } catch (_) {}
  }

  static Future<void> _migrateV4(DatabaseExecutor d) async {
    // Dedup dipindah ke lapisan kode (upsert per-msisdn) agar duplikat
    // warisan tetap terdeteksi via duplicates(); index unik dihapus.
    try {
      await d.execute('DROP INDEX IF EXISTS idx_contacts_msisdn');
    } catch (_) {}
    await d.execute(
      'CREATE INDEX IF NOT EXISTS idx_contacts_msisdn ON contacts(msisdn)',
    );
  }

  // ---------- Backup & restore ----------
  Future<String> exportBackupJson() async {
    final tables = [
      'contacts',
      'contact_groups',
      'contact_group_members',
      'message_templates',
      'conversations',
      'messages',
      'campaigns',
      'campaign_recipients',
      'message_queue',
      'delivery_attempts',
      'local_settings',
    ];
    final out = <String, dynamic>{};
    for (final t in tables) {
      out[t] = await db.query(t);
    }
    out['exported_at'] = DateTime.now().toUtc().toIso8601String();
    out['app'] = 'wasender_wabadak';
    out['version'] = 1;
    return jsonEncode(out);
  }

  Future<void> importBackupJson(String jsonStr) async {
    final j = jsonDecode(jsonStr) as Map<String, dynamic>;
    if (j['app'] != 'wasender_wabadak') {
      throw FormatException('File backup bukan milik Wasender+Wabadak.');
    }
    await db.transaction((txn) async {
      for (final t in [
        'delivery_attempts',
        'message_queue',
        'campaign_recipients',
        'messages',
        'conversations',
        'campaigns',
        'message_templates',
        'contact_group_members',
        'contact_groups',
        'contacts',
        'local_settings',
      ]) {
        final rows = (j[t] as List?) ?? [];
        await txn.delete(t);
        for (final r in rows) {
          await txn.insert(
            t,
            Map<String, Object?>.from(r as Map),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  Future<void> audit(String action, String detail) async {
    await db.insert('local_audit_logs', {
      'id': newId(),
      'at': DateTime.now().toUtc().toIso8601String(),
      'action': action,
      'detail': detail.length > 2000 ? detail.substring(0, 2000) : detail,
    });
  }
}

// ===================== Repositories =====================

class ContactRepo {
  final AppDatabase adb;
  ContactRepo(this.adb);

  Future<List<Map<String, dynamic>>> list({
    String query = '',
    String? groupId,
    int limit = 50,
    int offset = 0,
  }) async {
    if (groupId != null) {
      return adb.db.rawQuery(
        '''
        SELECT c.* FROM contacts c
        JOIN contact_group_members m ON m.contact_id = c.id
        WHERE m.group_id = ? AND (c.name LIKE ? OR c.msisdn LIKE ?)
        ORDER BY c.name LIMIT ? OFFSET ?''',
        [groupId, '%$query%', '%$query%', limit, offset],
      );
    }
    if (query.isEmpty) {
      return adb.db.query(
        'contacts',
        orderBy: 'name',
        limit: limit,
        offset: offset,
      );
    }
    return adb.db.query(
      'contacts',
      where: 'name LIKE ? OR msisdn LIKE ? OR note LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> count() async =>
      Sqflite.firstIntValue(
        await adb.db.rawQuery('SELECT COUNT(*) FROM contacts'),
      ) ??
      0;

  Future<void> upsert(Map<String, dynamic> c) async {
    // Dedup per-msisdn di lapisan kode: baris lama diperbarui, bukan ganda.
    final msisdn = '${c['msisdn']}';
    final ex = await adb.db.query(
      'contacts',
      columns: ['id'],
      where: 'msisdn = ?',
      whereArgs: [msisdn],
      limit: 1,
    );
    if (ex.isEmpty) {
      await adb.db.insert('contacts', c);
      return;
    }
    final row = Map<String, dynamic>.from(c)..['id'] = '${ex.first['id']}';
    await adb.db.update(
      'contacts',
      row,
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<bool> existsMsisdn(String msisdn) async {
    final r = await adb.db.query(
      'contacts',
      columns: ['id'],
      where: 'msisdn = ?',
      whereArgs: [msisdn],
      limit: 1,
    );
    return r.isNotEmpty;
  }

  Future<void> remove(String id) async =>
      adb.db.delete('contacts', where: 'id = ?', whereArgs: [id]);

  Future<List<Map<String, dynamic>>> duplicates() async {
    return adb.db.rawQuery('''
      SELECT msisdn, COUNT(*) n FROM contacts GROUP BY msisdn HAVING n > 1''');
  }
}

class GroupRepo {
  final AppDatabase adb;
  GroupRepo(this.adb);

  Future<List<Map<String, dynamic>>> list() async {
    final g = await adb.db.query('contact_groups', orderBy: 'name');
    final out = <Map<String, dynamic>>[];
    for (final row in g) {
      final m = Map<String, dynamic>.from(row);
      final c = await adb.db.rawQuery(
        'SELECT COUNT(*) n FROM contact_group_members WHERE group_id = ?',
        [row['id']],
      );
      m['member_count'] = (c.first['n'] as int?) ?? 0;
      out.add(m);
    }
    return out;
  }

  Future<void> create(String name) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await adb.db.insert('contact_groups', {
      'id': newId(),
      'name': name.trim(),
      'created_at': now,
    });
  }

  Future<void> rename(String id, String name) async {
    await adb.db.update(
      'contact_groups',
      {'name': name.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> remove(String id) async {
    await adb.db.transaction((txn) async {
      await txn.delete(
        'contact_group_members',
        where: 'group_id = ?',
        whereArgs: [id],
      );
      await txn.delete('contact_groups', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<Set<String>> memberIds(String groupId) async {
    final r = await adb.db.query(
      'contact_group_members',
      columns: ['contact_id'],
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return r.map((e) => '${e['contact_id']}').toSet();
  }

  Future<void> setMembers(String groupId, Set<String> contactIds) async {
    await adb.db.transaction((txn) async {
      await txn.delete(
        'contact_group_members',
        where: 'group_id = ?',
        whereArgs: [groupId],
      );
      for (final cid in contactIds) {
        await txn.insert('contact_group_members', {
          'group_id': groupId,
          'contact_id': cid,
        });
      }
    });
  }
}

class TemplateRepo {
  final AppDatabase adb;
  TemplateRepo(this.adb);
  Future<List<Map<String, dynamic>>> list() =>
      adb.db.query('message_templates', orderBy: 'name');
  Future<void> upsert(Map<String, dynamic> t) async => adb.db.insert(
    'message_templates',
    t,
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  Future<void> remove(String id) async =>
      adb.db.delete('message_templates', where: 'id = ?', whereArgs: [id]);
}

class CampaignRepo {
  final AppDatabase adb;
  CampaignRepo(this.adb);
  Future<List<Map<String, dynamic>>> list() =>
      adb.db.query('campaigns', orderBy: 'created_at DESC');
  Future<Map<String, dynamic>?> get(String id) async {
    final r = await adb.db.query(
      'campaigns',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, int>> summary(String campaignId) async {
    final rows = await adb.db.rawQuery(
      '''
      SELECT status, COUNT(*) n FROM campaign_recipients
      WHERE campaign_id = ? GROUP BY status''',
      [campaignId],
    );
    final m = {'sent': 0, 'failed': 0, 'pending': 0, 'sending': 0};
    for (final r in rows) {
      m['${r['status']}'] =
          (m['${r['status']}'] ?? 0) + ((r['n'] as int?) ?? 0);
    }
    return m;
  }
}

class QueueRepo {
  final AppDatabase adb;
  QueueRepo(this.adb);

  Future<List<Map<String, dynamic>>> pending({int limit = 20}) => adb.db.query(
    'message_queue',
    where: 'status IN (?,?)',
    whereArgs: ['pending', 'sending'],
    orderBy: 'created_at',
    limit: limit,
  );

  Future<List<Map<String, dynamic>>> list({int limit = 100, int offset = 0}) =>
      adb.db.query(
        'message_queue',
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

  Future<void> setStatus(
    String id,
    String status, {
    String error = '',
    int? attempts,
  }) async {
    final map = <String, Object?>{'status': status, 'last_error': error};
    if (attempts != null) map['attempts'] = attempts;
    await adb.db.update('message_queue', map, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> pauseAll() async => adb.db.update(
    'message_queue',
    {'status': 'pending'},
    where: 'status = ?',
    whereArgs: ['sending'],
  );

  Future<void> cancelPending() async => adb.db.update(
    'message_queue',
    {'status': 'cancelled'},
    where: 'status IN (?,?)',
    whereArgs: ['pending', 'sending'],
  );

  /// Resume manual: item failed kembali ke pending, percobaan diulang
  /// dari awal. Jujur dicatat sebagai aksi pengguna.
  Future<void> resume(String id) async {
    await adb.db.update(
      'message_queue',
      {
        'status': 'pending',
        'attempts': 0,
        'last_error': '',
        'next_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> attempts(String queueId) => adb.db.query(
    'delivery_attempts',
    where: 'queue_id = ?',
    whereArgs: [queueId],
    orderBy: 'at DESC',
    limit: 50,
  );

  Future<int> dueCount() async {
    final now = DateTime.now().toUtc().toIso8601String();
    return Sqflite.firstIntValue(
          await adb.db.rawQuery(
            "SELECT COUNT(*) FROM message_queue WHERE status = 'pending' "
            'AND (next_at IS NULL OR next_at <= ?)',
            [now],
          ),
        ) ??
        0;
  }
}

class InboxRepo extends ChangeNotifier {
  final AppDatabase adb;
  InboxRepo(this.adb);

  Future<List<Map<String, dynamic>>> conversations({
    bool archived = false,
    String query = '',
  }) {
    final w = archived ? '(c.archived = 1)' : '(c.archived = 0)';
    if (query.isEmpty) {
      return adb.db.rawQuery('''
        SELECT c.*, ct.name AS contact_name FROM conversations c
        LEFT JOIN contacts ct ON ct.id = c.contact_id
        WHERE $w ORDER BY COALESCE(c.last_at, c.created_at) DESC LIMIT 100''');
    }
    return adb.db.rawQuery(
      '''
      SELECT c.*, ct.name AS contact_name FROM conversations c
      LEFT JOIN contacts ct ON ct.id = c.contact_id
      WHERE $w AND (c.title LIKE ? OR ct.name LIKE ?)
      ORDER BY COALESCE(c.last_at, c.created_at) DESC LIMIT 100''',
      ['%$query%', '%$query%'],
    );
  }

  Future<List<Map<String, dynamic>>> thread(String convId) => adb.db.query(
    'messages',
    where: 'conversation_id = ?',
    whereArgs: [convId],
    orderBy: 'at',
    limit: 500,
  );

  Future<List<Map<String, dynamic>>> searchMessages(String q) => adb.db.query(
    'messages',
    where: 'body LIKE ?',
    whereArgs: ['%$q%'],
    orderBy: 'at DESC',
    limit: 100,
  );

  Future<String> ensureConversation({
    String? contactId,
    required String chatJid,
    required String title,
  }) async {
    final ex = await adb.db.query(
      'conversations',
      where: 'chat_jid = ?',
      whereArgs: [chatJid],
      limit: 1,
    );
    if (ex.isNotEmpty) return '${ex.first['id']}';
    final id = newId();
    final now = DateTime.now().toUtc().toIso8601String();
    await adb.db.insert('conversations', {
      'id': id,
      'contact_id': contactId,
      'chat_jid': chatJid,
      'title': title,
      'created_at': now,
      'updated_at': now,
    });
    return id;
  }

  Future<void> addMessage({
    required String conversationId,
    required String direction,
    required String body,
    String status = 'sent',
    String mediaPath = '',
    String mime = '',
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await adb.db.insert('messages', {
      'id': newId(),
      'conversation_id': conversationId,
      'direction': direction,
      'body': body,
      'media_path': mediaPath,
      'mime': mime,
      'status': status,
      'at': now,
    });
    await adb.db.update(
      'conversations',
      {
        'last_at': now,
        'updated_at': now,
        if (direction == 'inbound') 'unread': 1,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );
    notifyListeners();
  }

  Future<void> markRead(String convId) async {
    await adb.db.update(
      'conversations',
      {'unread': 0},
      where: 'id = ?',
      whereArgs: [convId],
    );
    notifyListeners();
  }

  Future<void> setArchived(String convId, bool v) async {
    await adb.db.update(
      'conversations',
      {'archived': v ? 1 : 0},
      where: 'id = ?',
      whereArgs: [convId],
    );
    notifyListeners();
  }
}

class SettingsRepo {
  final AppDatabase adb;
  SettingsRepo(this.adb);
  Future<String?> get(String k) async {
    final r = await adb.db.query(
      'local_settings',
      where: 'key = ?',
      whereArgs: [k],
      limit: 1,
    );
    return r.isEmpty ? null : '${r.first['value']}';
  }

  Future<void> set(String k, String v) async => adb.db.insert(
    'local_settings',
    {'key': k, 'value': v},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

/// Queue worker: retry dengan backoff, hormati batas percobaan.
/// Pengiriman aktual via share intent/deep-link (dibuka dari UI); worker
/// menandai percobaan dan menjadwalkan ulang. Tidak pernah mengklaim
/// delivered/read tanpa receipt nyata.
class QueueWorker {
  final AppDatabase adb;
  QueueWorker(this.adb);

  Duration backoff(int attempts) {
    final s = [30, 120, 600][attempts.clamp(0, 2)];
    return Duration(seconds: s);
  }

  Future<void> recordAttempt(
    String queueId,
    String result,
    String detail,
  ) async {
    await adb.db.insert('delivery_attempts', {
      'id': newId(),
      'queue_id': queueId,
      'at': DateTime.now().toUtc().toIso8601String(),
      'result': result,
      'detail': detail,
    });
  }

  Future<void> markShared(String queueId) async {
    // Pengguna menyelesaikan share ke WA resmi → status sent (bukan delivered).
    await adb.db.update(
      'message_queue',
      {'status': 'sent', 'last_error': ''},
      where: 'id = ?',
      whereArgs: [queueId],
    );
    await recordAttempt(queueId, 'shared', 'Dibuka via aplikasi WA resmi.');
  }

  Future<void> markFailed(String queueId, String error) async {
    final rows = await adb.db.query(
      'message_queue',
      where: 'id = ?',
      whereArgs: [queueId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final attempts = ((rows.first['attempts'] as int?) ?? 0) + 1;
    final maxA = ((rows.first['max_attempts'] as int?) ?? 3);
    if (attempts >= maxA) {
      await adb.db.update(
        'message_queue',
        {'status': 'failed', 'attempts': attempts, 'last_error': error},
        where: 'id = ?',
        whereArgs: [queueId],
      );
    } else {
      final next = DateTime.now()
          .toUtc()
          .add(backoff(attempts))
          .toIso8601String();
      await adb.db.update(
        'message_queue',
        {
          'status': 'pending',
          'attempts': attempts,
          'last_error': error,
          'next_at': next,
        },
        where: 'id = ?',
        whereArgs: [queueId],
      );
    }
    await recordAttempt(queueId, 'failed', error);
  }
}

/// Impor CSV kontak: header name,phone[,note,group]; validasi + sanitasi.
class CsvImportResult {
  final int imported;
  final int skipped;
  final List<String> errors;
  const CsvImportResult(this.imported, this.skipped, this.errors);
}

String? _validateMsisdn(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = '62${d.substring(1)}';
  if (!d.startsWith('62')) return 'harus diawali 08/62';
  if (d.length < 10 || d.length > 15) return 'panjang 10-15 digit';
  return null;
}

String _normMsisdn(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = '62${d.substring(1)}';
  return d;
}

Future<CsvImportResult> importContactsCsv(
  AppDatabase adb,
  String csvText,
) async {
  final lines = const LineSplitter().convert(csvText);
  if (lines.isEmpty) {
    return const CsvImportResult(0, 0, ['File kosong.']);
  }
  final header = lines.first
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .toList();
  final ni = header.indexOf('name');
  final pi = header.indexOf('phone');
  if (ni < 0 || pi < 0) {
    return const CsvImportResult(0, 0, [
      'Header wajib: name,phone (opsional: note,group).',
    ]);
  }
  final noteI = header.indexOf('note');
  var imported = 0, skipped = 0;
  final errors = <String>[];
  final now = DateTime.now().toUtc().toIso8601String();
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    // Parser CSV sederhana yang menghormati tanda kutip.
    final cells = _splitCsv(line);
    try {
      final name = (ni < cells.length ? cells[ni] : '').trim();
      final phone = (pi < cells.length ? cells[pi] : '').trim();
      final note = (noteI >= 0 && noteI < cells.length ? cells[noteI] : '')
          .trim();
      if (name.isEmpty || phone.isEmpty) {
        skipped++;
        errors.add('Baris ${i + 1}: nama/nomor kosong.');
        continue;
      }
      final bad = _validateMsisdn(phone);
      if (bad != null) {
        skipped++;
        errors.add('Baris ${i + 1}: nomor tidak valid ($bad).');
        continue;
      }
      final msisdn = _normMsisdn(phone);
      if (await ContactRepo(adb).existsMsisdn(msisdn)) {
        skipped++;
        errors.add('Baris ${i + 1}: duplikat nomor $msisdn, dilewati.');
        continue;
      }
      await adb.db.insert('contacts', {
        'id': newId(),
        'name': name.length > 200 ? name.substring(0, 200) : name,
        'msisdn': msisdn,
        'note': note.length > 500 ? note.substring(0, 500) : note,
        'source': 'csv',
        'created_at': now,
        'updated_at': now,
      });
      imported++;
    } catch (e) {
      skipped++;
      errors.add('Baris ${i + 1}: $e');
    }
  }
  await adb.audit('csv_import', 'imported=$imported skipped=$skipped');
  return CsvImportResult(imported, skipped, errors.take(20).toList());
}

List<String> _splitCsv(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQ = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') {
      if (inQ && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQ = !inQ;
      }
    } else if (c == ',' && !inQ) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(c);
    }
  }
  out.add(buf.toString());
  return out;
}

/// Ekspor CSV generik dari rows.
String toCsv(List<String> header, List<List<dynamic>> rows) {
  String esc(dynamic v) {
    final s = '$v';
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  final b = StringBuffer()..writeln(header.map(esc).join(','));
  for (final r in rows) {
    b.writeln(r.map(esc).join(','));
  }
  return b.toString();
}

/// Helper SharedPreferences untuk pengaturan sederhana.
Future<int> offlineCacheHours() async {
  final p = await SharedPreferences.getInstance();
  return p.getInt('offline_cache_hours') ?? 24;
}

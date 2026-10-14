import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wasender_wabadak/data/database.dart';

Future<AppDatabase> _open() async {
  sqfliteFfiInit();
  final adb = AppDatabase();
  await adb.open(
    factory: databaseFactoryFfi,
    pathOverride: inMemoryDatabasePath,
  );
  // In-memory FFI dipakai ulang antar test: bersihkan semua tabel.
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
    'local_audit_logs',
  ]) {
    await adb.db.delete(t);
  }
  return adb;
}

void main() {
  test('schema dibuat lengkap + migrasi tercatat', () async {
    final adb = await _open();
    final tables = await adb.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
    );
    final names = tables.map((t) => '${t['name']}').toSet();
    for (final t in [
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
      'local_audit_logs',
      'schema_migrations',
    ]) {
      expect(names, contains(t), reason: 'tabel $t hilang');
    }
    final cols = await adb.db.rawQuery('PRAGMA table_info(contacts)');
    expect(cols.map((c) => '${c['name']}'), contains('source'));
    await adb.close();
  });

  test('kontak: upsert dedup per-msisdn, cari, duplikat warisan', () async {
    final adb = await _open();
    final repo = ContactRepo(adb);
    final now = DateTime.now().toUtc().toIso8601String();
    Map<String, dynamic> c(String id, String msisdn) => {
      'id': id,
      'name': 'Nama $id',
      'msisdn': msisdn,
      'created_at': now,
      'updated_at': now,
    };
    await repo.upsert(c('1', '628111'));
    await repo.upsert(c('2', '628111')); // msisdn sama -> update, bukan ganda
    expect(await repo.count(), 1);
    expect((await repo.list(query: 'Nama 2')).length, 1);
    // Data warisan yang digandakan manual tetap terdeteksi:
    await adb.db.insert('contacts', c('3', '628222'));
    await adb.db.insert('contacts', c('4', '628222'));
    final dups = await repo.duplicates();
    expect(dups.map((d) => '${d['msisdn']}'), contains('628222'));
    await repo.remove('1');
    expect(await repo.count(), 2);
    await adb.close();
  });

  test('impor CSV valid + invalid per baris', () async {
    final adb = await _open();
    const csvText =
        'name,phone,note\n'
        'Budi,08123456789,VIP\n'
        'Budi Lagi,08123456789,duplikat\n'
        'Tanpa Nomor,,\n'
        'Salah,123,xx\n'
        '"Sari, Q",628987654321,ok\n';
    final res = await importContactsCsv(adb, csvText);
    expect(res.imported, 2);
    expect(res.skipped, 3);
    expect(res.errors.length, 3);
    expect(await ContactRepo(adb).count(), 2);
    const bad = 'nama,telepon\nBudi,08123\n';
    final res2 = await importContactsCsv(adb, bad);
    expect(res2.imported, 0);
    expect(res2.errors, isNotEmpty);
    await adb.close();
  });

  test('queue worker: retry backoff lalu failed', () async {
    final adb = await _open();
    final now = DateTime.now().toUtc().toIso8601String();
    await adb.db.insert('message_queue', {
      'id': 'q1',
      'msisdn': '628111',
      'body': 'halo',
      'status': 'pending',
      'attempts': 0,
      'max_attempts': 3,
      'created_at': now,
    });
    final w = QueueWorker(adb);
    await w.markFailed('q1', 'err-1');
    var row = (await adb.db.query(
      'message_queue',
      where: 'id=?',
      whereArgs: ['q1'],
    )).first;
    expect(row['status'], 'pending');
    expect(row['attempts'], 1);
    expect(row['next_at'], isNotNull);
    await w.markFailed('q1', 'err-2');
    await w.markFailed('q1', 'err-3');
    row = (await adb.db.query(
      'message_queue',
      where: 'id=?',
      whereArgs: ['q1'],
    )).first;
    expect(row['status'], 'failed');
    expect(row['attempts'], 3);
    final attempts = await adb.db.query('delivery_attempts');
    expect(attempts.length, 3);
    await w.markShared('q1');
    row = (await adb.db.query(
      'message_queue',
      where: 'id=?',
      whereArgs: ['q1'],
    )).first;
    expect(row['status'], 'sent');
    await adb.close();
  });

  test('kampanye summary + backup round-trip', () async {
    final adb = await _open();
    final now = DateTime.now().toUtc().toIso8601String();
    await adb.db.insert('campaigns', {
      'id': 'camp1',
      'name': 'Promo',
      'body': 'Halo {{nama}}',
      'status': 'queued',
      'created_at': now,
    });
    await adb.db.insert('campaign_recipients', {
      'id': 'r1',
      'campaign_id': 'camp1',
      'contact_id': 'c1',
      'msisdn': '628111',
      'status': 'sent',
      'updated_at': now,
    });
    await adb.db.insert('campaign_recipients', {
      'id': 'r2',
      'campaign_id': 'camp1',
      'contact_id': 'c2',
      'msisdn': '628222',
      'status': 'pending',
      'updated_at': now,
    });
    final sum = await CampaignRepo(adb).summary('camp1');
    expect(sum['sent'], 1);
    expect(sum['pending'], 1);

    final json = await adb.exportBackupJson();
    await adb.db.delete('campaign_recipients');
    await adb.importBackupJson(json);
    final sum2 = await CampaignRepo(adb).summary('camp1');
    expect(sum2['sent'], 1);
    expect(sum2['pending'], 1);
    await adb.close();
  });

  test('grup: CRUD + anggota + filter penerima', () async {
    final adb = await _open();
    final groups = GroupRepo(adb);
    final contacts = ContactRepo(adb);
    final now = DateTime.now().toUtc().toIso8601String();
    await contacts.upsert({
      'id': 'g1',
      'name': 'A',
      'msisdn': '628001',
      'created_at': now,
      'updated_at': now,
    });
    await contacts.upsert({
      'id': 'g2',
      'name': 'B',
      'msisdn': '628002',
      'created_at': now,
      'updated_at': now,
    });
    await groups.create('VIP');
    var list = await groups.list();
    expect(list.length, 1);
    expect(list.first['member_count'], 0);
    await groups.setMembers('${list.first['id']}', {'g1'});
    list = await groups.list();
    expect(list.first['member_count'], 1);
    final filtered = await contacts.list(groupId: '${list.first['id']}');
    expect(filtered.length, 1);
    expect('${filtered.first['msisdn']}', '628001');
    await groups.rename('${list.first['id']}', 'VIP Plus');
    list = await groups.list();
    expect('${list.first['name']}', 'VIP Plus');
    await groups.remove('${list.first['id']}');
    expect(await groups.list(), isEmpty);
    await adb.close();
  });

  test('queue resume mengembalikan failed ke pending', () async {
    final adb = await _open();
    final now = DateTime.now().toUtc().toIso8601String();
    await adb.db.insert('message_queue', {
      'id': 'qr1',
      'msisdn': '628111',
      'body': 'x',
      'status': 'failed',
      'attempts': 3,
      'last_error': 'boom',
      'created_at': now,
    });
    await QueueRepo(adb).resume('qr1');
    final row = (await adb.db.query(
      'message_queue',
      where: 'id=?',
      whereArgs: ['qr1'],
    )).first;
    expect(row['status'], 'pending');
    expect(row['attempts'], 0);
    expect(await QueueRepo(adb).dueCount(), 1);
    await adb.close();
  });

  test('inbox: conversation + thread + arsip', () async {
    final adb = await _open();
    final repo = InboxRepo(adb);
    final id = await repo.ensureConversation(
      chatJid: '628111@s.whatsapp.net',
      title: 'Budi',
    );
    final same = await repo.ensureConversation(
      chatJid: '628111@s.whatsapp.net',
      title: 'Budi',
    );
    expect(same, id);
    await repo.addMessage(
      conversationId: id,
      direction: 'inbound',
      body: 'halo kak',
    );
    expect((await repo.thread(id)).length, 1);
    expect((await repo.conversations()).length, 1);
    expect((await repo.searchMessages('halo')).length, 1);
    await repo.markRead(id);
    await repo.setArchived(id, true);
    expect((await repo.conversations()).length, 0);
    expect((await repo.conversations(archived: true)).length, 1);
    await adb.close();
  });
}

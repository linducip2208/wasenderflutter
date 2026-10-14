/// Hasil operasi yang eksplisit: success / failure dengan pesan aman-log
/// (tidak boleh membawa token, isi pesan, atau QR).
library;

sealed class OpResult<T> {
  const OpResult();
}

class Ok<T> extends OpResult<T> {
  final T value;
  const Ok(this.value);
}

class Fail<T> extends OpResult<T> {
  final String code;
  final String message;
  const Fail(this.code, this.message);
}

/// Validasi nomor WhatsApp Indonesia: digit saja, 08xx atau 62xx.
String? validateMsisdn(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  var d = digits;
  if (d.startsWith('0')) d = '62${d.substring(1)}';
  if (!d.startsWith('62')) return 'Nomor harus diawali 08 atau 62';
  if (d.length < 10 || d.length > 15) {
    return 'Panjang nomor harus 10–15 digit';
  }
  if (!RegExp(r'^62\d+$').hasMatch(d)) return 'Nomor hanya boleh berisi digit';
  return null;
}

String normalizeMsisdn(String raw) {
  var d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = '62${d.substring(1)}';
  return d;
}

/// Render template {{nama}} {{var}} — tanpa mengeksekusi kode.
String renderTemplate(String body, Map<String, String> vars) {
  var out = body;
  vars.forEach((k, v) {
    out = out.replaceAll('{{$k}}', v);
    out = out.replaceAll('{{ $k }}', v);
  });
  return out;
}

Set<String> templateVars(String body) {
  final re = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');
  return re.allMatches(body).map((m) => m.group(1)!).toSet();
}

/// Sanitasi satu cell CSV: potong whitespace, batasi panjang, buang kontrol.
String sanitizeCsvCell(String cell, {int maxLen = 500}) {
  var s = cell.trim().replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
  if (s.length > maxLen) s = s.substring(0, maxLen);
  return s;
}

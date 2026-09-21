// moment_shim.dart — tiny duration formatting helper so we avoid extra deps.
String fmtMinutes(int msAgo) {
  if (msAgo < 0) msAgo = 0;
  final m = msAgo ~/ 60000;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  final h = m ~/ 60;
  if (h < 24) return '${h}h ago';
  return '${h ~/ 24}d ago';
}

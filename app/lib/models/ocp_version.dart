// Minor versions below this are considered EOL and hidden from the UI.
// Mirrors `ACTIVE_MINOR_MINIMUM` in scraper/sources/ocp_versions.py.
const int kOcpActiveMinorMinimum = 14;

class OcpVersion {
  final String id;
  final String minorVersion;
  final String latestStable;
  final DateTime updatedAt;

  const OcpVersion({
    required this.id,
    required this.minorVersion,
    required this.latestStable,
    required this.updatedAt,
  });

  factory OcpVersion.fromJson(Map<String, dynamic> json) {
    return OcpVersion(
      id: json['id'] as String,
      minorVersion: json['minor_version'] as String,
      latestStable: json['latest_stable'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  int get minorInt => int.parse(minorVersion.split('.')[1]);
}

class WdpaSiteCandidateDto {
  const WdpaSiteCandidateDto({
    required this.siteId,
    required this.nameEnglish,
    required this.name,
  });

  factory WdpaSiteCandidateDto.fromFeature(Map<String, dynamic> feature) {
    final attributes = _asMap(feature['attributes']);
    final siteId = _readInt(attributes['site_id']);
    if (siteId == null) {
      throw const FormatException('Missing site_id.');
    }

    return WdpaSiteCandidateDto(
      siteId: siteId,
      nameEnglish: _readString(attributes['name_eng']) ?? '',
      name: _readString(attributes['name']) ?? '',
    );
  }

  final int siteId;
  final String nameEnglish;
  final String name;

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  static int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static String? _readString(Object? value) {
    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (value is num) {
      return value.toString();
    }
    return null;
  }
}

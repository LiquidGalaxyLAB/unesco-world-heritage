class UnescoSitesNetworkException implements Exception {
  const UnescoSitesNetworkException(this.message);

  final String message;

  @override
  String toString() => 'UnescoSitesNetworkException: $message';
}

class UnescoSitesParseException implements Exception {
  const UnescoSitesParseException(this.message);

  final String message;

  @override
  String toString() => 'UnescoSitesParseException: $message';
}

class UnescoSitesEmptyResultException implements Exception {
  const UnescoSitesEmptyResultException(this.message);

  final String message;

  @override
  String toString() => 'UnescoSitesEmptyResultException: $message';
}

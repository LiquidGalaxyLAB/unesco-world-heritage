abstract class UnescoSitesException implements Exception {
  const UnescoSitesException(this.message);

  final String message;
}

class UnescoSitesNetworkException extends UnescoSitesException {
  const UnescoSitesNetworkException(super.message);

  @override
  String toString() => 'UnescoSitesNetworkException: $message';
}

class UnescoSitesParseException extends UnescoSitesException {
  const UnescoSitesParseException(super.message);

  @override
  String toString() => 'UnescoSitesParseException: $message';
}

class UnescoSitesEmptyResultException extends UnescoSitesException {
  const UnescoSitesEmptyResultException(super.message);

  @override
  String toString() => 'UnescoSitesEmptyResultException: $message';
}

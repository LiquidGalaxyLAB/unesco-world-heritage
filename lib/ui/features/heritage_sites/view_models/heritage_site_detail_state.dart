import '../../../../domain/models/heritage_site.dart';

class HeritageSiteDetailState {
  const HeritageSiteDetailState({
    this.site,
    this.isLoading = false,
    this.isNotFound = false,
    this.errorMessage,
  });

  final HeritageSite? site;
  final bool isLoading;
  final bool isNotFound;
  final String? errorMessage;

  HeritageSiteDetailState copyWith({
    HeritageSite? site,
    bool? isLoading,
    bool? isNotFound,
    String? errorMessage,
    bool clearSite = false,
    bool clearError = false,
  }) {
    return HeritageSiteDetailState(
      site: clearSite ? null : site ?? this.site,
      isLoading: isLoading ?? this.isLoading,
      isNotFound: isNotFound ?? this.isNotFound,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

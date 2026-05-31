import 'package:flutter/foundation.dart';

import '../../../../domain/repositories/unesco_sites_repository.dart';
import 'heritage_site_detail_state.dart';

class HeritageSiteDetailViewModel extends ChangeNotifier {
  HeritageSiteDetailViewModel(this._repository);

  final UnescoSitesRepository _repository;

  HeritageSiteDetailState _state =
      const HeritageSiteDetailState(isLoading: true);
  HeritageSiteDetailState get state => _state;

  Future<void> loadSite(int propertyId) async {
    _state = _state.copyWith(
      isLoading: true,
      isNotFound: false,
      clearSite: true,
      clearError: true,
    );
    notifyListeners();

    try {
      final site = await _repository.getSiteById(propertyId);
      if (site == null) {
        _state = _state.copyWith(
          isLoading: false,
          isNotFound: true,
          clearSite: true,
        );
      } else {
        _state = _state.copyWith(site: site, isLoading: false);
      }
    } catch (_) {
      _state = _state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load UNESCO heritage site details.',
      );
    }

    notifyListeners();
  }

  void clearError() {
    _state = _state.copyWith(clearError: true);
    notifyListeners();
  }
}

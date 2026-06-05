enum HeritageCategory {
  cultural,
  natural,
  mixed,
  unknown;

  static HeritageCategory fromRaw(String value) {
    switch (value.trim().toLowerCase()) {
      case 'cultural':
        return HeritageCategory.cultural;
      case 'natural':
        return HeritageCategory.natural;
      case 'mixed':
        return HeritageCategory.mixed;
      default:
        return HeritageCategory.unknown;
    }
  }
}

class HeritageSite {
  const HeritageSite({
    required this.propertyId,
    required this.name,
    required this.country,
    required this.category,
    required this.rawCategory,
    required this.latitude,
    required this.longitude,
    required this.isoCodes,
    required this.description,
    required this.dateInscribed,
    required this.mainImageUrl,
    required this.imageUrls,
  });

  final int propertyId;
  final String name;
  final String country;
  final HeritageCategory category;
  final String rawCategory;
  final double latitude;
  final double longitude;
  final String isoCodes;
  final String description;
  final String dateInscribed;
  final String mainImageUrl;
  final List<String> imageUrls;
}

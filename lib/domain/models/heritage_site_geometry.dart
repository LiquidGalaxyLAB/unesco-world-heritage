class HeritageGeoPoint {
  const HeritageGeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class HeritagePolygonGeometry {
  const HeritagePolygonGeometry({
    required this.rings,
    this.isFallbackCircle = false,
  });

  final List<List<HeritageGeoPoint>> rings;
  final bool isFallbackCircle;

  bool get isEmpty => rings.isEmpty;
}

class HeritageSiteGeometry {
  const HeritageSiteGeometry({
    required this.propertyId,
    required this.boundary,
    this.buffer,
  });

  final int propertyId;
  final HeritagePolygonGeometry boundary;
  final HeritagePolygonGeometry? buffer;
}

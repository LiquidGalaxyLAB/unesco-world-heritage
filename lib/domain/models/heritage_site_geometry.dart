class HeritageGeoPoint {
  const HeritageGeoPoint({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class HeritagePolygonGeometry {
  const HeritagePolygonGeometry({
    required this.rings,
  });

  final List<List<HeritageGeoPoint>> rings;

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

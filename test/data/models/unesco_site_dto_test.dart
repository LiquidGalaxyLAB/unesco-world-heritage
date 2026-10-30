import 'package:flutter_test/flutter_test.dart';
import 'package:unesco_world_heritage/data/models/unesco_site_dto.dart';

void main() {
  group('UnescoSiteDto.fromRecord', () {
    test('parses a complete UNESCO record', () {
      final dto = UnescoSiteDto.fromRecord({
        'id_no': 123,
        'name_en': 'Machu Picchu',
        'states_name_en': 'Peru',
        'category': 'Cultural',
        'latitude': -13.1631,
        'longitude': -72.5450,
        'iso_codes': 'PE',
        'description_en': 'A historic Inca citadel.',
        'short_description_en': 'Historic Inca citadel.',
        'date_inscribed': '1983',
        'main_image_url': 'https://example.com/machu-picchu.jpg',
        'region': 'Latin America and the Caribbean',
        'danger': 'false',
      });

      expect(dto.propertyId, 123);
      expect(dto.name, 'Machu Picchu');
      expect(dto.country, 'Peru');
      expect(dto.rawCategory, 'Cultural');
      expect(dto.latitude, -13.1631);
      expect(dto.longitude, -72.5450);
      expect(dto.isoCodes, 'PE');
      expect(dto.description, 'A historic Inca citadel.');
      expect(dto.shortDescription, 'Historic Inca citadel.');
      expect(dto.dateInscribed, '1983');
      expect(dto.mainImageUrl, 'https://example.com/machu-picchu.jpg');
      expect(dto.region, 'Latin America and the Caribbean');
      expect(dto.isDanger, isFalse);
      expect(dto.imageUrls, ['https://example.com/machu-picchu.jpg']);
    });

    test('converts numeric strings and nested coordinates', () {
      final dto = UnescoSiteDto.fromRecord({
        'id_no': '123',
        'name_en': 'Test Site',
        'states_names': ['Test Country', 'Second Country'],
        'category': 'Natural',
        'coordinates': {'lat': '-13.1631', 'lon': '-72.5450'},
      });

      expect(dto.propertyId, 123);
      expect(dto.country, 'Test Country, Second Country');
      expect(dto.latitude, -13.1631);
      expect(dto.longitude, -72.5450);
    });

    test('removes supported formatting tags from the site name', () {
      final dto = UnescoSiteDto.fromRecord({
        'id_no': 123,
        'name_en': '<strong>Machu Picchu</strong>',
        'states_name_en': 'Peru',
        'category': 'Cultural',
        'latitude': -13.1631,
        'longitude': -72.5450,
      });

      expect(dto.name, 'Machu Picchu');
    });

    test('normalizes and deduplicates image URLs', () {
      final dto = UnescoSiteDto.fromRecord({
        'id_no': 123,
        'name_en': 'Test Site',
        'states_name_en': 'Test Country',
        'category': 'Cultural',
        'latitude': 1.0,
        'longitude': 2.0,
        'main_image_url': '//example.com/main.jpg',
        'images_urls': [
          '//example.com/main.jpg',
          'https://example.com/second.jpg',
          'none',
          'not-a-url',
        ],
      });

      expect(dto.mainImageUrl, 'https://example.com/main.jpg');
      expect(dto.imageUrls, [
        'https://example.com/main.jpg',
        'https://example.com/second.jpg',
      ]);
    });

    test('throws when the property ID is missing', () {
      expect(
        () => UnescoSiteDto.fromRecord({
          'name_en': 'Test Site',
          'states_name_en': 'Test Country',
          'category': 'Cultural',
          'latitude': 1.0,
          'longitude': 2.0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when the name is missing', () {
      expect(
        () => UnescoSiteDto.fromRecord({
          'id_no': 123,
          'states_name_en': 'Test Country',
          'category': 'Cultural',
          'latitude': 1.0,
          'longitude': 2.0,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('throws when coordinates are missing', () {
      expect(
        () => UnescoSiteDto.fromRecord({
          'id_no': 123,
          'name_en': 'Test Site',
          'states_name_en': 'Test Country',
          'category': 'Cultural',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('UnescoSiteDto.fromFeature', () {
    test('parses an ArcGIS feature using geometry coordinates', () {
      final dto = UnescoSiteDto.fromFeature({
        'attributes': {
          'property_id': '456',
          'property_name_en': 'Great Barrier Reef',
          'property_states_name_en': 'Australia',
          'property_category': 'Natural',
          'property_iso3': 'AUS',
          'property_short_description_en': 'A natural site.',
          'property_inscribed': '1981',
          'property_region': 'Asia-Pacific',
          'in_danger': 'false',
        },
        'geometry': {'x': 151.25, 'y': -18.28},
      });

      expect(dto.propertyId, 456);
      expect(dto.name, 'Great Barrier Reef');
      expect(dto.country, 'Australia');
      expect(dto.rawCategory, 'Natural');
      expect(dto.latitude, -18.28);
      expect(dto.longitude, 151.25);
      expect(dto.isoCodes, 'AUS');
      expect(dto.shortDescription, 'A natural site.');
      expect(dto.description, 'A natural site.');
      expect(dto.dateInscribed, '1981');
      expect(dto.region, 'Asia-Pacific');
      expect(dto.isDanger, isFalse);
    });

    test('uses the centroid when geometry coordinates are absent', () {
      final dto = UnescoSiteDto.fromFeature({
        'attributes': {
          'property_id': 789,
          'property_name_en': 'Centroid Site',
          'property_states_name_en': 'Test Country',
          'property_category': 'Mixed',
        },
        'centroid': {'x': 20.0, 'y': 10.0},
      });

      expect(dto.latitude, 10.0);
      expect(dto.longitude, 20.0);
    });

    test(
      'uses the first geometry ring point as a final coordinate fallback',
      () {
        final dto = UnescoSiteDto.fromFeature({
          'attributes': {
            'property_id': 790,
            'property_name_en': 'Ring Site',
            'property_states_name_en': 'Test Country',
            'property_category': 'Cultural',
          },
          'geometry': {
            'rings': [
              [
                [30.0, 40.0],
                [31.0, 41.0],
              ],
            ],
          },
        });

        expect(dto.latitude, 40.0);
        expect(dto.longitude, 30.0);
      },
    );

    test('throws when an ArcGIS feature lacks required fields', () {
      expect(
        () => UnescoSiteDto.fromFeature({
          'attributes': {
            'property_id': 456,
            'property_name_en': 'Incomplete Site',
          },
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'google_maps_config.dart';

class LocationPlaceItem {
  final String? placeId;
  final String displayName;
  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  const LocationPlaceItem({
    this.placeId,
    required this.displayName,
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  factory LocationPlaceItem.fromJson(Map<String, dynamic> json) {
    final displayName = json['display_name'] as String? ?? '';
    final parts = displayName.split(',');
    final title = parts.isNotEmpty ? parts.first.trim() : displayName;
    final subtitle = parts.length > 1
        ? parts.sublist(1).join(',').trim()
        : '';

    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;

    return LocationPlaceItem(
      placeId: json['place_id']?.toString(),
      displayName: displayName,
      title: title,
      subtitle: subtitle,
      latitude: lat,
      longitude: lon,
    );
  }

  factory LocationPlaceItem.fromGooglePrediction(Map<String, dynamic> json) {
    final description = json['description'] as String? ?? '';
    final structured = json['structured_formatting'] as Map<String, dynamic>?;
    final title = structured?['main_text'] as String? ?? description;
    final subtitle = structured?['secondary_text'] as String? ?? '';
    final placeId = json['place_id'] as String?;

    return LocationPlaceItem(
      placeId: placeId,
      displayName: description,
      title: title,
      subtitle: subtitle,
      latitude: 0.0, // Diambil via getPlaceDetails saat dipilih
      longitude: 0.0,
    );
  }

  LocationPlaceItem copyWith({
    double? latitude,
    double? longitude,
    String? displayName,
  }) {
    return LocationPlaceItem(
      placeId: placeId,
      displayName: displayName ?? this.displayName,
      title: title,
      subtitle: subtitle,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class LocationSearchService {
  LocationSearchService._();
  static final LocationSearchService instance = LocationSearchService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'User-Agent': 'ManggaPOS-App/1.0 (contact@manggapos.com)',
        'Accept': 'application/json',
      },
    ),
  );

  /// Search places: menggunakan Google Places API jika API Key tersedia,
  /// atau OpenStreetMap Nominatim dengan location bias ke lokasi user.
  Future<List<LocationPlaceItem>> searchPlaces(
    String query, {
    double? userLat,
    double? userLng,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    if (GoogleMapsConfig.hasApiKey) {
      return _searchGooglePlaces(trimmed, userLat: userLat, userLng: userLng);
    } else {
      return _searchOsmPlaces(trimmed, userLat: userLat, userLng: userLng);
    }
  }

  /// 1. Google Places API (New) Autocomplete (Akurasi Tinggi & Prioritas Lokasi User)
  Future<List<LocationPlaceItem>> _searchGooglePlaces(
    String query, {
    double? userLat,
    double? userLng,
  }) async {
    try {
      final body = <String, dynamic>{
        'input': query,
        'includedRegionCodes': ['id'],
        'languageCode': 'id',
      };

      // Location bias: utamakan radius 50km dari lokasi user (misal Indramayu / Jawa Barat)
      if (userLat != null && userLng != null) {
        body['locationBias'] = {
          'circle': {
            'center': {
              'latitude': userLat,
              'longitude': userLng,
            },
            'radius': 50000.0,
          },
        };
      }

      final response = await _dio.post(
        'https://places.googleapis.com/v1/places:autocomplete',
        options: Options(
          headers: {
            'X-Goog-Api-Key': GoogleMapsConfig.apiKey,
            'Content-Type': 'application/json',
          },
        ),
        data: body,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map
            ? response.data as Map
            : jsonDecode(response.data.toString()) as Map;

        final suggestions = (data['suggestions'] as List?) ?? [];
        final items = <LocationPlaceItem>[];

        for (final s in suggestions) {
          final pred = s['placePrediction'] as Map<String, dynamic>?;
          if (pred == null) continue;

          final placeId = pred['placeId'] as String?;
          final fullText = pred['text']?['text'] as String? ?? '';
          final structured = pred['structuredFormat'] as Map<String, dynamic>?;
          final title = structured?['mainText']?['text'] as String? ?? fullText;
          final subtitle = structured?['secondaryText']?['text'] as String? ?? '';

          items.add(
            LocationPlaceItem(
              placeId: placeId,
              displayName: fullText,
              title: title,
              subtitle: subtitle,
              latitude: 0.0,
              longitude: 0.0,
            ),
          );
        }

        if (items.isNotEmpty) return items;
      }
    } catch (e) {
      debugPrint('[LocationSearchService] Google Places API (New) error: $e. Fallback to OSM.');
    }
    // Fallback ke OSM jika terjadi exception
    return _searchOsmPlaces(query, userLat: userLat, userLng: userLng);
  }

  /// Ambil koordinat detail tempat dari Google Places API (New)
  Future<LocationPlaceItem?> getPlaceDetails(LocationPlaceItem item) async {
    if (item.latitude != 0.0 && item.longitude != 0.0) {
      return item;
    }

    if (!GoogleMapsConfig.hasApiKey || item.placeId == null) {
      return item;
    }

    try {
      final response = await _dio.get(
        'https://places.googleapis.com/v1/places/${item.placeId}',
        queryParameters: {
          'languageCode': 'id',
        },
        options: Options(
          headers: {
            'X-Goog-Api-Key': GoogleMapsConfig.apiKey,
            'X-Goog-FieldMask': 'id,displayName,formattedAddress,location',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is Map
            ? response.data as Map
            : jsonDecode(response.data.toString()) as Map;

        final loc = data['location'] as Map<String, dynamic>?;
        if (loc != null) {
          final lat = (loc['latitude'] as num?)?.toDouble() ?? 0.0;
          final lng = (loc['longitude'] as num?)?.toDouble() ?? 0.0;
          final formatted = data['formattedAddress'] as String? ?? item.displayName;

          return item.copyWith(
            latitude: lat,
            longitude: lng,
            displayName: formatted,
          );
        }
      }
    } catch (e) {
      debugPrint('[LocationSearchService] getPlaceDetails Places (New) error: $e');
    }
    return item;
  }

  /// 2. OpenStreetMap Nominatim dengan Viewbox Bias Lokal
  Future<List<LocationPlaceItem>> _searchOsmPlaces(
    String query, {
    double? userLat,
    double? userLng,
  }) async {
    try {
      final params = <String, dynamic>{
        'q': query,
        'format': 'json',
        'addressdetails': '1',
        'limit': '10',
        'countrycodes': 'id',
      };

      // Jika lokasi user diketahui, pasang viewbox sekitar 1 derajat (~110 km)
      // agar tidak melompat ke pulau lain (misal dari Indramayu ke Lampung)
      if (userLat != null && userLng != null) {
        final left = userLng - 1.0;
        final right = userLng + 1.0;
        final top = userLat + 1.0;
        final bottom = userLat - 1.0;
        params['viewbox'] = '$left,$top,$right,$bottom';
        params['bounded'] = '0'; // Prioritaskan area ini
      }

      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: params,
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is List
            ? response.data as List
            : jsonDecode(response.data.toString()) as List;

        return data
            .map((item) => LocationPlaceItem.fromJson(Map<String, dynamic>.from(item as Map)))
            .where((item) => item.latitude != 0.0 && item.longitude != 0.0)
            .toList();
      }
    } catch (e) {
      debugPrint('[LocationSearchService] OSM search error: $e');
    }
    return const [];
  }

  /// Reverse geocode (lat, lon to address)
  Future<String?> reverseGeocode(double lat, double lon) async {
    // 1. Coba Google Geocoding API terlebih dahulu jika ada key
    if (GoogleMapsConfig.hasApiKey) {
      try {
        final response = await _dio.get(
          'https://maps.googleapis.com/maps/api/geocode/json',
          queryParameters: {
            'latlng': '$lat,$lon',
            'key': GoogleMapsConfig.apiKey,
            'language': 'id',
          },
        );
        if (response.statusCode == 200 && response.data != null) {
          final data = response.data is Map
              ? response.data as Map
              : jsonDecode(response.data.toString()) as Map;
          final results = (data['results'] as List?) ?? [];
          if (results.isNotEmpty) {
            return results.first['formatted_address'] as String?;
          }
        }
      } catch (e) {
        debugPrint('[LocationSearchService] Google reverse geocode error: $e');
      }
    }

    // 2. Fallback ke OSM
    try {
      final response = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat.toString(),
          'lon': lon.toString(),
          'format': 'json',
          'addressdetails': '1',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final map = response.data is Map
            ? response.data as Map
            : jsonDecode(response.data.toString()) as Map;
        return map['display_name'] as String?;
      }
    } catch (e) {
      debugPrint('[LocationSearchService] OSM reverse geocode error: $e');
    }
    return null;
  }
}

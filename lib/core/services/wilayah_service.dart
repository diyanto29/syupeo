import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class WilayahItem {
  final String code;
  final String name;

  const WilayahItem({required this.code, required this.name});

  factory WilayahItem.fromJson(Map<String, dynamic> json) {
    return WilayahItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class WilayahSelection {
  final WilayahItem? province;
  final WilayahItem? regency;
  final WilayahItem? district;
  final WilayahItem? village;

  const WilayahSelection({
    this.province,
    this.regency,
    this.district,
    this.village,
  });

  String get formattedText {
    final parts = [
      if (village != null) village!.name,
      if (district != null) district!.name,
      if (regency != null) regency!.name,
      if (province != null) province!.name,
    ];
    return parts.join(', ');
  }

  bool get hasSelection => province != null;
}

class WilayahService {
  WilayahService._();
  static final WilayahService instance = WilayahService._();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final Map<String, List<WilayahItem>> _cache = {};

  Future<List<WilayahItem>> getProvinces() async {
    const key = 'provinces';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final response = await _dio.get('https://wilayah.id/api/provinces.json');
      final list = _parseList(response.data);
      _cache[key] = list;
      return list;
    } catch (e) {
      debugPrint('[WilayahService] getProvinces error: $e');
      return [];
    }
  }

  Future<List<WilayahItem>> getRegencies(String provinceCode) async {
    final key = 'regencies_$provinceCode';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final response = await _dio.get('https://wilayah.id/api/regencies/$provinceCode.json');
      final list = _parseList(response.data);
      _cache[key] = list;
      return list;
    } catch (e) {
      debugPrint('[WilayahService] getRegencies error: $e');
      return [];
    }
  }

  Future<List<WilayahItem>> getDistricts(String regencyCode) async {
    final key = 'districts_$regencyCode';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final response = await _dio.get('https://wilayah.id/api/districts/$regencyCode.json');
      final list = _parseList(response.data);
      _cache[key] = list;
      return list;
    } catch (e) {
      debugPrint('[WilayahService] getDistricts error: $e');
      return [];
    }
  }

  Future<List<WilayahItem>> getVillages(String districtCode) async {
    final key = 'villages_$districtCode';
    if (_cache.containsKey(key)) return _cache[key]!;

    try {
      final response = await _dio.get('https://wilayah.id/api/villages/$districtCode.json');
      final list = _parseList(response.data);
      _cache[key] = list;
      return list;
    } catch (e) {
      debugPrint('[WilayahService] getVillages error: $e');
      return [];
    }
  }

  List<WilayahItem> _parseList(dynamic data) {
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .map((e) => WilayahItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => WilayahItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}


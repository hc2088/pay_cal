import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/payroll_models.dart';

class CityCatalog {
  CityCatalog(List<CityReference> cities) : cities = List.unmodifiable(cities) {
    if (cities.map((c) => c.id).toSet().length != cities.length ||
        !cities.any((c) => c.id == 'bj')) {
      throw const FormatException('城市目录缺少北京或存在重复标识');
    }
  }
  final List<CityReference> cities;
  CityReference get beijing => cities.firstWhere((c) => c.id == 'bj');
  CityReference byId(String id) => cities.firstWhere((c) => c.id == id);
  static Future<CityCatalog> load() async {
    final j = objectMap(
      jsonDecode(
        await rootBundle.loadString('assets/policies/city_references.json'),
      ),
    );
    if (j['schema'] != 'city-reference-1' || j['verified'] != false) {
      throw const FormatException('参考库格式错误');
    }
    final cities = (j['cities'] as List)
        .map((e) => CityReference.fromJson(objectMap(e)))
        .toList();
    // Reference assets can never silently acquire verified-policy status.
    if (cities.any((c) => c.periods.any((p) => p.verified))) {
      throw const FormatException('参考库混入正式规则');
    }
    return CityCatalog(cities);
  }

  List<CityReference> search(String query) {
    final q = query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return cities
        .where(
          (c) =>
              q.isEmpty ||
              c.search.toLowerCase().replaceAll(' ', '').contains(q),
        )
        .toList();
  }
}

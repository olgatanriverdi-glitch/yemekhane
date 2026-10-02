import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'models.dart';

/// Veriyi sırayla dener: internet -> önbellek -> uygulamayla gelen kopya. Böylece çevrimdışıyken de menü görünür.
class Depo {
  Future<String> _oku(String yol) async {
    final prefs = await SharedPreferences.getInstance();
    if (veriTabanUrl.isNotEmpty) {
      try {
        final r = await http
            .get(Uri.parse('$veriTabanUrl/$yol'))
            .timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          final govde = utf8.decode(r.bodyBytes);
          jsonDecode(govde); // bozuk veriyi önbelleğe yazma
          await prefs.setString('onbellek/$yol', govde);
          return govde;
        }
      } catch (_) {}
    }
    final onbellek = prefs.getString('onbellek/$yol');
    if (onbellek != null) return onbellek;
    return rootBundle.loadString('assets/data/$yol');
  }

  Future<List<Universite>> universiteler() async {
    final j = jsonDecode(await _oku('index.json')) as Map<String, dynamic>;
    return (j['universities'] as List)
        .map((e) => Universite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Menu> menu(String universiteId) async {
    final j = jsonDecode(await _oku('$universiteId/menu.json'))
        as Map<String, dynamic>;
    return Menu.fromJson(j);
  }

  /// Günün fotoğrafının adresi (yalnızca internet adresi tanımlıysa).
  String? fotoUrl(String universiteId, String? foto) =>
      (foto == null || veriTabanUrl.isEmpty)
          ? null
          : '$veriTabanUrl/$universiteId/$foto';

  Future<String?> seciliUniversite() async =>
      (await SharedPreferences.getInstance()).getString('universite');
  Future<void> universiteSec(String id) async =>
      (await SharedPreferences.getInstance()).setString('universite', id);
}

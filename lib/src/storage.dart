import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Persistance fichier unique `filstock_data.json` dans le répertoire de
/// documents applicatif (sandbox de l'app sur Android et iOS).
///
/// Sur le web (utilisé seulement pour les tests rapides), la persistance est
/// désactivée — l'app fonctionne en mémoire.
class Storage {
  static const String _fileName = 'filstock_data.json';

  Future<File?> _file() async {
    if (kIsWeb) return null;
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<Map<String, dynamic>> load() async {
    try {
      final f = await _file();
      if (f == null || !await f.exists()) return {};
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    try {
      final f = await _file();
      if (f == null) return;
      await f.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Storage.save error: $e');
    }
  }
}

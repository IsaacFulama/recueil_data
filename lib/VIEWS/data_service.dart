import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../VIEWS/home.dart';
import 'package:untitled13/models/cantique.dart';

class DataService {
  // Remplace par ton URL JSON (ex: GitHub Raw ou Firebase)
  static const String remoteUrl = "https://ton-serveur.com/api/cantiques.json";

  // CHARGEMENT INTELLIGENT
  static Future<List<Cantique>> fetchCantiques() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // 1. Tenter de récupérer les nouvelles données sur le serveur
      final response = await http.get(Uri.parse(remoteUrl)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        // 2. Si ça marche, on sauvegarde en local pour la prochaine fois (Maintenance auto)
        prefs.setString('cached_cantiques', response.body);
        return _parseCantiques(response.body);
      }
    } catch (e) {
      print("Mode Offline : Chargement du cache");
    }

    // 3. Si pas d'internet, on utilise la dernière version sauvegardée
    String? localData = prefs.getString('cached_cantiques');
    if (localData != null) return _parseCantiques(localData);

    return []; // Liste vide si premier lancement sans internet
  }

  static List<Cantique> _parseCantiques(String jsonStr) {
    final List<dynamic> data = jsonDecode(jsonStr);
    return data.map((item) => Cantique(
      id: item['id'],
      titre: item['titre'],
      auteur: item['auteur'],
      paroles: item['paroles'],
      isFavorite: false,
    )).toList();
  }
}
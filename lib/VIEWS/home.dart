import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:untitled13/VIEWS/PageParoles.dart';
import 'package:untitled13/VIEWS/generer_programme.dart';
import 'package:untitled13/VIEWS/scanner_programme.dart';
import '../models/cantique.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Cantique> _tousLesChants = [];
  List<Cantique> _chantsAffiches = [];
  bool _isLoading = true;
  int _currentTab = 0;
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _alphabet = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  // --- SYNC INTELLIGENTE : VERSIONING & ÉCONOMIE DE BANDE PASSANTE ---
  Future<void> _chargerDonnees() async {
    final prefs = await SharedPreferences.getInstance();

    const urlVersion = "https://raw.githubusercontent.com/IsaacFulama/recueil_data/main/version.json";
    const urlCantiques = "https://raw.githubusercontent.com/IsaacFulama/recueil_data/main/cantiques.json";

    int localVersion = prefs.getInt('version_catalogue') ?? 0;
    String? cache = prefs.getString('cache_chants');

    try {
      // 1. On télécharge d'abord le micro-fichier de contrôle de version (1 Ko)
      final responseVersion = await http.get(Uri.parse(urlVersion)).timeout(const Duration(seconds: 4));

      if (responseVersion.statusCode == 200) {
        final dataVersion = jsonDecode(responseVersion.body);
        int cloudVersion = dataVersion['version'] ?? 1;

        // 2. Stratégie de mise à jour : Uniquement si le cloud est plus récent ou si le cache est vide
        if (cloudVersion > localVersion || cache == null) {
          debugPrint("🔄 Nouvelle version du catalogue détectée ($cloudVersion). Téléchargement...");

          final responseChants = await http.get(Uri.parse(urlCantiques)).timeout(const Duration(seconds: 7));
          if (responseChants.statusCode == 200) {
            await prefs.setString('cache_chants', responseChants.body);
            await prefs.setInt('version_catalogue', cloudVersion);
            _initialiserListe(responseChants.body);
            return;
          }
        } else {
          debugPrint("✅ L'application est déjà à jour (Version $localVersion). Utilisation du cache.");
        }
      }
    } catch (e) {
      debugPrint("Info: Mode hors-ligne ou latence réseau ($e). Chargement du cache local.");
    }

    // Chargement de secours depuis la mémoire du téléphone si internet échoue ou est inutile
    if (cache != null) {
      _initialiserListe(cache);
    } else {
      setState(() {
        _isLoading = false;
        _tousLesChants = [];
        _chantsAffiches = [];
      });
    }
  }

  void _initialiserListe(String jsonStr) {
    try {
      final List decoded = jsonDecode(jsonStr);
      setState(() {
        _tousLesChants = decoded.map((item) => Cantique.fromJson(item)).toList();
        _tousLesChants.sort((a, b) => a.titre.compareTo(b.titre));
        _chantsAffiches = _tousLesChants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint("Erreur de formatage du fichier JSON: $e");
    }
  }

  void _filtrer(String query) {
    setState(() {
      _chantsAffiches = _tousLesChants.where((c) {
        final matchesQuery = c.titre.toLowerCase().contains(query.toLowerCase()) ||
            c.auteur.toLowerCase().contains(query.toLowerCase());
        final matchesTab = _currentTab == 0 || c.isFavorite;
        return matchesQuery && matchesTab;
      }).toList();
    });
  }

  void _scrollToLetter(String letter) {
    int index = _chantsAffiches.indexWhere((c) => c.titre.toUpperCase().startsWith(letter));
    if (index != -1) {
      _scrollController.animateTo(
          index * 92.0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Rechercher un chant...", border: InputBorder.none),
          onChanged: _filtrer,
        )
            : const Text("Mon Recueil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
        actions: [
          // Bouton Rechercher
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.redAccent),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) { _searchController.clear(); _filtrer(""); }
            }),
          ),

          // Bouton Scanner un programme (Chef de chœur)
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
              tooltip: "Scanner un programme",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ScannerProgrammePage(tousLesChants: _tousLesChants)),
              ),
            ),

          // Bouton Créer un programme (Chef de chœur)
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.green),
              tooltip: "Créer un programme",
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => GenererProgrammePage(tousLesChants: _tousLesChants)),
              ),
            ),

          // Forcer la Synchronisation manuelle
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            tooltip: "Synchroniser",
            onPressed: _chargerDonnees,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Stack(
        children: [
          _chantsAffiches.isEmpty
              ? const Center(child: Text("Aucun cantique disponible"))
              : ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 45, 80),
            itemCount: _chantsAffiches.length,
            itemBuilder: (context, index) => _buildCard(_chantsAffiches[index]),
          ),
          if (!_isSearching && _currentTab == 0) _buildAlphabetIndex(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) {
          setState(() { _currentTab = i; _filtrer(_searchController.text); });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Chants'),
          NavigationDestination(icon: Icon(Icons.favorite_outline), label: 'Favoris'),
        ],
      ),
    );
  }

  Widget _buildCard(Cantique c) {
    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Hero(
          tag: 'hero-${c.id}',
          child: CircleAvatar(
            backgroundColor: Colors.redAccent.withOpacity(0.1),
            child: const Icon(Icons.music_note, color: Colors.redAccent),
          ),
        ),
        title: Text(c.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(c.auteur),
        trailing: IconButton(
          icon: Icon(c.isFavorite ? Icons.favorite : Icons.favorite_border, color: c.isFavorite ? Colors.red : Colors.grey),
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => c.isFavorite = !c.isFavorite);
          },
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PageParoles(cantique: c))),
      ),
    );
  }

  Widget _buildAlphabetIndex() {
    return Align(
      alignment: Alignment.centerRight,
      child: SizedBox(
        width: 30,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _alphabet.length,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => _scrollToLetter(_alphabet[i]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                  _alphabet[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent)
              ),
            ),
          ),
        ),
      ),
    );
  }
}
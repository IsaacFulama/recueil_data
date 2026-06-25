import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
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
  bool _churchMode = false; // Mode Énergie Église Révolutionnaire

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _alphabet = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  // Activer/Désactiver le mode église (gestion de l'éveil de l'écran)
  void _toggleChurchMode() {
    setState(() {
      _churchMode = !_churchMode;
      WakelockPlus.toggle(enable: _churchMode);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_churchMode
            ? "💡 Mode Culte Activé : L'écran restera allumé et l'énergie est optimisée !"
            : "Mode standard restauré."),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _churchMode ? Colors.green : Colors.black87,
      ),
    );
  }

  Future<void> _chargerDonnees() async {
    final prefs = await SharedPreferences.getInstance();
    const urlVersion = "https://raw.githubusercontent.com/IsaacFulama/recueil_data/main/version.json";
    const urlCantiques = "https://raw.githubusercontent.com/IsaacFulama/recueil_data/main/cantiques.json";

    int localVersion = prefs.getInt('version_catalogue') ?? 0;
    String? cache = prefs.getString('cache_chants');

    try {
      final responseVersion = await http.get(Uri.parse(urlVersion)).timeout(const Duration(seconds: 4));
      if (responseVersion.statusCode == 200) {
        final dataVersion = jsonDecode(responseVersion.body);
        int cloudVersion = dataVersion['version'] ?? 1;

        if (cloudVersion > localVersion || cache == null) {
          final responseChants = await http.get(Uri.parse(urlCantiques)).timeout(const Duration(seconds: 7));
          if (responseChants.statusCode == 200) {
            await prefs.setString('cache_chants', responseChants.body);
            await prefs.setInt('version_catalogue', cloudVersion);
            _initialiserListe(responseChants.body);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Mode hors-ligne activé.");
    }

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
          index * 88.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.decelerate
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Thème dynamique local selon le mode Église
    final backgroundColor = _churchMode ? const Color(0xFF000000) : const Color(0xFFF4F6F9);
    final cardColor = _churchMode ? const Color(0xFF121212) : Colors.white;
    final textColor = _churchMode ? Colors.white70 : Colors.black87;
    final titleColor = _churchMode ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
            : CustomScrollView(
          controller: _scrollController,
          slivers: [
            // Header Moderne et Innovant
            SliverAppBar(
              expandedHeight: 140.0,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: _churchMode ? const Color(0xFF121212) : Colors.white,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: false,
                titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                title: _isSearching
                    ? null
                    : Text(
                    _currentTab == 0 ? "Mon Recueil" : "Mes Favoris",
                    style: TextStyle(color: titleColor, fontWeight: FontWeight.w900, fontSize: 24)
                ),
                background: _isSearching ? null : Padding(
                  padding: const EdgeInsets.only(left: 20, top: 25),
                  child: Text(
                    "${_tousLesChants.length} cantiques disponibles à la louange",
                    style: TextStyle(color: _churchMode ? Colors.grey : Colors.grey[600], fontSize: 13),
                  ),
                ),
              ),
              actions: [
                // Bouton Révolutionnaire Mode Église
                IconButton(
                  icon: Icon(
                      _churchMode ? Icons.flash_on : Icons.flash_off_outlined,
                      color: _churchMode ? Colors.amber : Colors.grey
                  ),
                  tooltip: "Mode Culte (Énergie & Éveil)",
                  onPressed: _toggleChurchMode,
                ),
                IconButton(
                  icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.deepPurple),
                  onPressed: () => setState(() {
                    _isSearching = !_isSearching;
                    if (!_isSearching) { _searchController.clear(); _filtrer(""); }
                  }),
                ),
                if (!_isSearching) ...[
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScannerProgrammePage(tousLesChants: _tousLesChants))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.playlist_add, color: Colors.green),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GenererProgrammePage(tousLesChants: _tousLesChants))),
                  ),
                ],
              ],
            ),

            // Barre de recherche intégrée si active
            if (_isSearching)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: cardColor,
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: TextStyle(color: titleColor),
                    decoration: InputDecoration(
                      hintText: "Rechercher un titre ou un auteur...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: _churchMode ? const Color(0xFF1E1E1E) : const Color(0xFFF1F5F9),
                    ),
                    onChanged: _filtrer,
                  ),
                ),
              ),

            // Liste des Chants stylisée
            if (_chantsAffiches.isEmpty)
              const SliverFillRemaining(child: Center(child: Text("Aucun cantique trouvé")))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 50, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildPremiumCard(_chantsAffiches[index], cardColor, titleColor, textColor),
                    childCount: _chantsAffiches.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: (!_isSearching && _currentTab == 0 && !_isLoading && _chantsAffiches.isNotEmpty)
          ? Padding(
              padding: const EdgeInsets.only(top: 150, bottom: 50),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 35,
                  child: _buildAlphabetIndex(),
                ),
              ),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: _churchMode ? Colors.white10 : Colors.black, width: 0.5))
        ),
        child: NavigationBar(
          backgroundColor: _churchMode ? const Color(0xFF121212) : Colors.white,
          indicatorColor: Colors.deepPurple.withOpacity(0.15),
          selectedIndex: _currentTab,
          onDestinationSelected: (i) {
            setState(() { _currentTab = i; _filtrer(_searchController.text); });
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined, color: _churchMode ? Colors.white60 : Colors.black54),
              selectedIcon: const Icon(Icons.music_note, color: Colors.deepPurple),
              label: 'Cantiques',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded, color: _churchMode ? Colors.white60 : Colors.black54),
              selectedIcon: const Icon(Icons.favorite_rounded, color: Colors.red),
              label: 'Favoris',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumCard(Cantique c, Color cardColor, Color titleColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _churchMode ? [] : [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Hero(
          tag: 'hero-${c.id}',
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.deepPurple),
          ),
        ),
        title: Text(c.titre, style: TextStyle(fontWeight: FontWeight.bold, color: titleColor, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(c.auteur, style: TextStyle(color: textColor, fontSize: 13)),
        ),
        trailing: IconButton(
          icon: Icon(c.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: c.isFavorite ? Colors.red : Colors.grey),
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
    return Container(
      decoration: BoxDecoration(
        color: _churchMode ? const Color(0xFF1E1E1E) : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _alphabet.length,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _scrollToLetter(_alphabet[i]),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text(
                _alphabet[i],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple)
            ),
          ),
        ),
      ),
    );
  }
}
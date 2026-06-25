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

class _Tokens {
  static const Color bgLight       = Color(0xFFF8F7FF);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color textPrimLight = Color(0xFF1A1235);
  static const Color textSecLight  = Color(0xFF6B7280);
  static const Color dividerLight  = Color(0xFFEDE9FE);
  static const Color bgDark        = Color(0xFF09090F);
  static const Color surfaceDark   = Color(0xFF13121C);
  static const Color textPrimDark  = Color(0xFFF3F0FF);
  static const Color textSecDark   = Color(0xFF9CA3AF);
  static const Color dividerDark   = Color(0xFF1E1B2E);
  static const Color violet        = Color(0xFF7C3AED);
  static const Color violetDeep    = Color(0xFF4A1D96);
  static const Color gold          = Color(0xFFF59E0B);
  static const Color red           = Color(0xFFEF4444);
  static const Color green         = Color(0xFF10B981);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<Cantique> _tousLesChants  = [];
  List<Cantique> _chantsAffiches = [];
  bool _isLoading   = true;
  int  _currentTab  = 0;
  bool _isSearching = false;
  bool _churchMode  = false;

  // Variables de diagnostic en direct
  String _debugLog = "Pas encore de scan lancé.";
  String _rawJsonReceived = "";

  final TextEditingController _searchController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();
  late AnimationController    _syncAnim;

  Color get _bg        => _churchMode ? _Tokens.bgDark        : _Tokens.bgLight;
  Color get _surface   => _churchMode ? _Tokens.surfaceDark   : _Tokens.surfaceLight;
  Color get _textPrim  => _churchMode ? _Tokens.textPrimDark : _Tokens.textPrimLight;
  Color get _textSec   => _churchMode ? _Tokens.textSecDark   : _Tokens.textSecLight;

  @override
  void initState() {
    super.initState();
    _syncAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _briserLeCacheEtForcerLaSync();
  }

  @override
  void dispose() {
    _syncAnim.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // CETTE FONCTION FORCE GITHUB À IGNORER LE CACHE DU TÉLÉPHONE ET DE L'APPLICATION
  Future<void> _briserLeCacheEtForcerLaSync() async {
    setState(() {
      _isLoading = true;
      _debugLog = "🚀 Lancement du diagnostic forcé...\n";
    });
    _syncAnim.repeat();

    final prefs = await SharedPreferences.getInstance();

    // 1. On efface le cache local existant pour partir à zéro
    await prefs.remove('cache_chants');
    await prefs.remove('version_catalogue');

    // Timestamp dynamique unique pour empêcher le navigateur/GitHub de renvoyer une ancienne réponse
    final int forceRefreshTimestamp = DateTime.now().millisecondsSinceEpoch;

    const repoBase = "https://raw.githubusercontent.com/IsaacFulama/recueil_data/main";
    final urlVersion = "$repoBase/version.json?nocache=$forceRefreshTimestamp";
    final urlChants  = "$repoBase/cantiques.json?nocache=$forceRefreshTimestamp";

    setState(() {
      _debugLog += "🌐 Tentative de lecture de version.json...\nURL: $urlVersion\n";
    });

    try {
      final resVersion = await http.get(Uri.parse(urlVersion)).timeout(const Duration(seconds: 5));
      setState(() {
        _debugLog += "📥 Réponse version.json reçue ! Code HTTP: ${resVersion.statusCode}\nContenu: ${resVersion.body}\n";
      });

      setState(() {
        _debugLog += "🌐 Tentative de lecture de cantiques.json...\nURL: $urlChants\n";
      });

      final resChants = await http.get(Uri.parse(urlChants)).timeout(const Duration(seconds: 8));
      setState(() {
        _debugLog += "📥 Réponse cantiques.json reçue ! Code HTTP: ${resChants.statusCode}\n";
        _rawJsonReceived = resChants.body;
      });

      if (resChants.statusCode == 200) {
        final decoded = jsonDecode(resChants.body);
        if (decoded is List) {
          await prefs.setString('cache_chants', resChants.body);
          setState(() {
            _tousLesChants = decoded.map((e) => Cantique.fromJson(e)).toList()
              ..sort((a, b) => a.titre.compareTo(b.titre));
            _chantsAffiches = List.from(_tousLesChants);
            _debugLog += "✅ Succès ! ${_tousLesChants.length} chants chargés en mémoire.\n";
            _isLoading = false;
          });
        } else {
          throw "Le fichier de chants reçu n'est pas un tableau (List JSON).";
        }
      } else {
        throw "GitHub a répondu avec une erreur de code ${resChants.statusCode}";
      }

    } catch (e) {
      setState(() {
        _debugLog += "❌ ERREUR CRITIQUE : $e\n";
        _isLoading = false;
      });
      _injecterSecours();
    }

    _syncAnim.stop();
    _syncAnim.reset();
  }

  void _injecterSecours() {
    setState(() {
      _tousLesChants = [
        Cantique(
          id: "0",
          titre: "Échec de la connexion",
          auteur: "Regardez le panneau de diagnostic ci-dessous",
          paroles: "Aucun chant n'a pu être téléchargé.",
        )
      ];
      _chantsAffiches = _tousLesChants;
    });
  }

  void _filtrer(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _chantsAffiches = _tousLesChants.where((c) {
        final matchesSearch = q.isEmpty || c.titre.toLowerCase().contains(q) || c.auteur.toLowerCase().contains(q);
        final matchesTab = _currentTab == 0 || c.isFavorite;
        return matchesSearch && matchesTab;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Text("Outil de Diagnostic", style: TextStyle(color: _textPrim)),
        backgroundColor: _surface,
        actions: [
          RotationTransition(
            turns: _syncAnim,
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _Tokens.violet),
              onPressed: _briserLeCacheEtForcerLaSync,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // PANNEAU DE DIAGNOSTIC EN TEMPS RÉEL (Tout en haut de l'écran)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, color: Colors.greenAccent, size: 16),
                    SizedBox(width: 8),
                    Text("CONSOLE LOGS :", style: TextStyle(color: Colors.greenAccent, fontFamily: "monospace", fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _debugLog,
                  style: const TextStyle(color: Colors.white, fontFamily: "monospace", fontSize: 11),
                ),
                if (_rawJsonReceived.isNotEmpty) ...[
                  const Divider(color: Colors.white30),
                  const Text("DÉBUT DU TEXTE REÇU :", style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(
                    _rawJsonReceived.length > 150 ? "${_rawJsonReceived.substring(0, 150)}..." : _rawJsonReceived,
                    style: const TextStyle(color: Colors.grey, fontFamily: "monospace", fontSize: 10),
                  ),
                ]
              ],
            ),
          ),

          // LA LISTE DES CHANTS (si elle arrive à charger)
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: _chantsAffiches.length,
                  itemBuilder: (ctx, i) {
                    final c = _chantsAffiches[i];
                    return ListTile(
                      leading: const CircleAvatar(backgroundColor: _Tokens.violet, child: Icon(Icons.music_note, color: Colors.white)),
                      title: Text(c.titre, style: TextStyle(color: _textPrim, fontWeight: FontWeight.bold)),
                      subtitle: Text(c.auteur, style: TextStyle(color: _textSec)),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
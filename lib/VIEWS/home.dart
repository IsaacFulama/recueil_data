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

// ─────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────
class _Tokens {
  // Light
  static const Color bgLight       = Color(0xFFF8F7FF);
  static const Color surfaceLight  = Color(0xFFFFFFFF);
  static const Color textPrimLight = Color(0xFF1A1235);
  static const Color textSecLight  = Color(0xFF6B7280);
  static const Color dividerLight  = Color(0xFFEDE9FE);

  // Dark (church mode)
  static const Color bgDark        = Color(0xFF09090F);
  static const Color surfaceDark   = Color(0xFF13121C);
  static const Color textPrimDark  = Color(0xFFF3F0FF);
  static const Color textSecDark   = Color(0xFF9CA3AF);
  static const Color dividerDark   = Color(0xFF1E1B2E);

  // Accents
  static const Color violet        = Color(0xFF7C3AED);
  static const Color violetDeep    = Color(0xFF4A1D96);
  static const Color gold          = Color(0xFFF59E0B);
  static const Color red           = Color(0xFFEF4444);
  static const Color green         = Color(0xFF10B981);

  // Radius
  static const double r12 = 12;
  static const double r16 = 16;
  static const double r20 = 20;
}

// ─────────────────────────────────────────────
//  HOME PAGE
// ─────────────────────────────────────────────
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

  // Diagnostic
  bool   _hasError     = false;
  String _errorDetails = "";
  String _statusMsg    = "";
  int    _cloudVersion = 0;

  // Contrôleurs
  final TextEditingController _searchController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();
  late AnimationController    _syncAnim;

  final List<String> _alphabet = "#ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

  // ── Getters thème ──────────────────────────
  Color get _bg        => _churchMode ? _Tokens.bgDark       : _Tokens.bgLight;
  Color get _surface   => _churchMode ? _Tokens.surfaceDark  : _Tokens.surfaceLight;
  Color get _textPrim  => _churchMode ? _Tokens.textPrimDark : _Tokens.textPrimLight;
  Color get _textSec   => _churchMode ? _Tokens.textSecDark  : _Tokens.textSecLight;

  @override
  void initState() {
    super.initState();
    _syncAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _chargerDonnees();
  }

  @override
  void dispose() {
    _syncAnim.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Church mode ────────────────────────────
  void _toggleChurchMode() {
    HapticFeedback.mediumImpact();
    setState(() => _churchMode = !_churchMode);
    WakelockPlus.toggle(enable: _churchMode);
  }

  // ── Chargement ─────────────────────────────
  Future<void> _chargerDonnees() async {
    setState(() { _isLoading = true; _hasError = false; });
    _syncAnim.repeat();

    final prefs      = await SharedPreferences.getInstance();
    final int ts     = DateTime.now().millisecondsSinceEpoch;
    const repoBase   = "https://raw.githubusercontent.com/IsaacFulama/recueil_data/main";
    final urlVersion = "$repoBase/version.json?t=$ts";
    final urlChants  = "$repoBase/cantiques.json?t=$ts";

    int    localVersion = prefs.getInt('version_catalogue') ?? 0;
    String? cache       = prefs.getString('cache_chants');

    try {
      final resVersion = await http
          .get(Uri.parse(urlVersion))
          .timeout(const Duration(seconds: 6));

      if (resVersion.statusCode != 200) {
        throw "Serveur GitHub — statut ${resVersion.statusCode} (version.json)";
      }

      _cloudVersion = (jsonDecode(resVersion.body)['version'] as num?)?.toInt() ?? 1;

      if (_cloudVersion > localVersion || cache == null) {
        final resChants = await http
            .get(Uri.parse(urlChants))
            .timeout(const Duration(seconds: 10));

        if (resChants.statusCode != 200) {
          throw "Téléchargement impossible — statut ${resChants.statusCode}";
        }

        final decoded = jsonDecode(resChants.body);
        if (decoded is! List) throw "cantiques.json : structure inattendue (pas une liste)";

        await prefs.setString('cache_chants', resChants.body);
        await prefs.setInt('version_catalogue', _cloudVersion);
        cache = resChants.body;
        _statusMsg = "Catalogue mis à jour — v$_cloudVersion";
      } else {
        _statusMsg = "v$localVersion · À jour";
      }
    } catch (e) {
      setState(() { _hasError = true; _errorDetails = e.toString(); });
      debugPrint("🚨 Sync: $e");
    }

    _syncAnim.stop();
    _syncAnim.reset();

    if (cache != null) {
      _initialiserListe(cache);
    } else {
      _injecterSecours();
    }
  }

  void _initialiserListe(String jsonStr) {
    try {
      final List decoded = jsonDecode(jsonStr);
      setState(() {
        _tousLesChants = decoded.map((e) => Cantique.fromJson(e)).toList()
          ..sort((a, b) => a.titre.compareTo(b.titre));
        _chantsAffiches = _tousLesChants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorDetails = "Décodage JSON : $e";
        _isLoading = false;
      });
      _injecterSecours();
    }
  }

  void _injecterSecours() {
    setState(() {
      _tousLesChants = [
        Cantique(
          id: "0",
          titre: "Mode hors-ligne activé",
          auteur: "Aucune connexion disponible",
          paroles: "Vérifiez votre connexion puis appuyez sur ↻ pour réessayer.",
        )
      ];
      _chantsAffiches = _tousLesChants;
      _isLoading = false;
    });
  }

  // ── Filtrage ───────────────────────────────
  void _filtrer(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _chantsAffiches = _tousLesChants.where((c) {
        final match = q.isEmpty ||
            c.titre.toLowerCase().contains(q) ||
            c.auteur.toLowerCase().contains(q);
        final fav   = _currentTab == 0 || c.isFavorite;
        return match && fav;
      }).toList();
    });
  }

  void _scrollToLetter(String letter) {
    final idx = _chantsAffiches
        .indexWhere((c) => c.titre.toUpperCase().startsWith(letter));
    if (idx != -1) {
      _scrollController.animateTo(
        idx * 80.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // ── BUILD ──────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _churchMode
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: _isLoading
              ? _buildLoader()
              : Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildAppBar(),
                  if (_hasError) _buildErrorBanner(),
                  if (_isSearching) _buildSearchBar(),
                  _buildStats(),
                  _buildList(),
                  // bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
              // Alphabet index flottant
              if (!_isSearching && _currentTab == 0)
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 80,
                  width: 26,
                  child: _buildAlphabetIndex(),
                ),
            ],
          ),
        ),
        bottomNavigationBar: _buildNavBar(),
      ),
    );
  }

  // ── Loader ─────────────────────────────────
  Widget _buildLoader() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_Tokens.violet, _Tokens.violetDeep],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(
            color: _Tokens.violet,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            "Chargement du recueil…",
            style: TextStyle(color: _textSec, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: _surface,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        centerTitle: false,
        title: _isSearching
            ? null
            : Text(
          _currentTab == 0 ? "Mon Recueil" : "Favoris",
          style: TextStyle(
            color: _textPrim,
            fontWeight: FontWeight.w900,
            fontSize: 26,
            letterSpacing: -0.5,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: _churchMode ? _Tokens.dividerDark : _Tokens.dividerLight),
      ),
      actions: [
        // Church mode
        _ActionBtn(
          icon: _churchMode ? Icons.bedtime_rounded : Icons.bedtime_off_outlined,
          color: _churchMode ? _Tokens.gold : _textSec,
          tooltip: _churchMode ? "Quitter le mode église" : "Mode église",
          onTap: _toggleChurchMode,
        ),
        // Recherche
        _ActionBtn(
          icon: _isSearching ? Icons.close_rounded : Icons.search_rounded,
          color: _Tokens.violet,
          tooltip: "Rechercher",
          onTap: () => setState(() {
            _isSearching = !_isSearching;
            if (!_isSearching) { _searchController.clear(); _filtrer(""); }
          }),
        ),
        if (!_isSearching) ...[
          _ActionBtn(
            icon: Icons.qr_code_scanner_rounded,
            color: Colors.blueAccent,
            tooltip: "Scanner un programme",
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => ScannerProgrammePage(tousLesChants: _tousLesChants))),
          ),
          _ActionBtn(
            icon: Icons.playlist_add_rounded,
            color: _Tokens.green,
            tooltip: "Créer un programme",
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => GenererProgrammePage(tousLesChants: _tousLesChants))),
          ),
        ],
        // Sync
        RotationTransition(
          turns: _syncAnim,
          child: _ActionBtn(
            icon: Icons.sync_rounded,
            color: _textSec,
            tooltip: "Synchroniser",
            onTap: _chargerDonnees,
          ),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Bannière erreur ────────────────────────
  Widget _buildErrorBanner() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F0),
          borderRadius: BorderRadius.circular(_Tokens.r12),
          border: Border.all(color: _Tokens.red.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _Tokens.red, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Synchronisation échouée — mode hors-ligne",
                    style: TextStyle(color: _Tokens.red, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorDetails,
                    style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _chargerDonnees,
                    child: const Text(
                      "Réessayer →",
                      style: TextStyle(color: _Tokens.red, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barre de recherche ─────────────────────
  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        color: _surface,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: _textPrim, fontSize: 15),
          cursorColor: _Tokens.violet,
          decoration: InputDecoration(
            hintText: "Titre ou auteur…",
            hintStyle: TextStyle(color: _textSec),
            prefixIcon: const Icon(Icons.search_rounded, color: _Tokens.violet, size: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            filled: true,
            fillColor: _churchMode ? _Tokens.dividerDark : _Tokens.bgLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(_Tokens.r12),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: _filtrer,
        ),
      ),
    );
  }

  // ── Stats ──────────────────────────────────
  Widget _buildStats() {
    final favCount = _tousLesChants.where((c) => c.isFavorite).length;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
        child: Row(
          children: [
            _Chip(
              label: "${_chantsAffiches.length} affiché${_chantsAffiches.length > 1 ? 's' : ''}",
              color: _Tokens.violet,
              bg: _Tokens.violet.withOpacity(0.08),
              textColor: _churchMode ? _Tokens.textPrimDark : _Tokens.textPrimLight,
            ),
            const SizedBox(width: 8),
            if (favCount > 0)
              _Chip(
                label: "$favCount favori${favCount > 1 ? 's' : ''}",
                color: _Tokens.red,
                bg: _Tokens.red.withOpacity(0.08),
                textColor: _churchMode ? _Tokens.textPrimDark : _Tokens.textPrimLight,
              ),
            const Spacer(),
            if (_statusMsg.isNotEmpty)
              Text(
                _statusMsg,
                style: TextStyle(color: _textSec, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  // ── Liste principale ───────────────────────
  Widget _buildList() {
    if (_chantsAffiches.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded, size: 48, color: _textSec),
              const SizedBox(height: 12),
              Text(
                _currentTab == 1
                    ? "Aucun favori pour l'instant"
                    : "Aucun résultat trouvé",
                style: TextStyle(color: _textSec, fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                _currentTab == 1
                    ? "Appuyez sur ♡ pour ajouter un cantique"
                    : "Essayez un autre terme de recherche",
                style: TextStyle(color: _textSec, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 44, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (ctx, i) => _CantiqueCard(
            cantique: _chantsAffiches[i],
            churchMode: _churchMode,
            surface: _surface,
            textPrim: _textPrim,
            textSec: _textSec,
            onFavToggle: () => setState(() => _chantsAffiches[i].isFavorite = !_chantsAffiches[i].isFavorite),
            onTap: () {
              if (_chantsAffiches[i].id != "0") {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => PageParoles(cantique: _chantsAffiches[i]),
                    transitionsBuilder: (_, anim, __, child) =>
                        FadeTransition(opacity: anim, child: child),
                    transitionDuration: const Duration(milliseconds: 250),
                  ),
                );
              }
            },
          ),
          childCount: _chantsAffiches.length,
        ),
      ),
    );
  }

  // ── Alphabet ───────────────────────────────
  Widget _buildAlphabetIndex() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: _churchMode
              ? _Tokens.surfaceDark.withOpacity(0.9)
              : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_churchMode ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _alphabet.length,
          itemBuilder: (_, i) => GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _scrollToLetter(_alphabet[i]);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(
                _alphabet[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: _Tokens.violet.withOpacity(0.7),
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Navigation ─────────────────────────────
  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(
          color: _churchMode ? _Tokens.dividerDark : _Tokens.dividerLight,
          width: 1,
        )),
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: _currentTab,
        indicatorColor: _Tokens.violet.withOpacity(0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() { _currentTab = i; _filtrer(_searchController.text); });
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.music_note_outlined, color: _textSec),
            selectedIcon: const Icon(Icons.music_note_rounded, color: _Tokens.violet),
            label: "Cantiques",
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded, color: _textSec),
            selectedIcon: const Icon(Icons.favorite_rounded, color: _Tokens.red),
            label: "Favoris",
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CARTE CANTIQUE — widget séparé pour les perfs
// ─────────────────────────────────────────────
class _CantiqueCard extends StatelessWidget {
  final Cantique cantique;
  final bool churchMode;
  final Color surface, textPrim, textSec;
  final VoidCallback onTap, onFavToggle;

  const _CantiqueCard({
    required this.cantique,
    required this.churchMode,
    required this.surface,
    required this.textPrim,
    required this.textSec,
    required this.onTap,
    required this.onFavToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_Tokens.r16),
          splashColor: _Tokens.violet.withOpacity(0.06),
          highlightColor: _Tokens.violet.withOpacity(0.03),
          child: Ink(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(_Tokens.r16),
              boxShadow: churchMode
                  ? []
                  : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // ── Signet gauche (signature visuelle) ──
                Container(
                  width: 4,
                  height: 64,
                  decoration: BoxDecoration(
                    color: cantique.isFavorite ? _Tokens.gold : Colors.transparent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(_Tokens.r16),
                      bottomLeft: Radius.circular(_Tokens.r16),
                    ),
                  ),
                ),
                // ── Icône ──
                const SizedBox(width: 12),
                Hero(
                  tag: 'hero-${cantique.id}',
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _Tokens.violet.withOpacity(churchMode ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.music_note_rounded, color: _Tokens.violet, size: 20),
                  ),
                ),
                // ── Texte ──
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cantique.titre,
                          style: TextStyle(
                            color: textPrim,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cantique.auteur,
                          style: TextStyle(color: textSec, fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // ── Favori ──
                IconButton(
                  icon: Icon(
                    cantique.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: cantique.isFavorite ? _Tokens.gold : textSec,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onFavToggle();
                  },
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  WIDGETS UTILITAIRES
// ─────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: color, size: 22),
        onPressed: onTap,
        splashRadius: 20,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color, bg, textColor;

  const _Chip({
    required this.label,
    required this.color,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
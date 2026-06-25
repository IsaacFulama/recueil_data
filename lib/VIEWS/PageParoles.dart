import 'dart:async';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/cantique.dart';

class PageParoles extends StatefulWidget {
  final Cantique cantique;
  const PageParoles({super.key, required this.cantique});

  @override
  State<PageParoles> createState() => _PageParolesState();
}

class _PageParolesState extends State<PageParoles> {
  double _fontSize = 18.0;
  int _themeIndex = 0; // 0:Clair, 1:Sépia, 2:Sombre
  bool _isFull = false;
  bool _isAutoScrolling = false;

  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _scrollTimer?.cancel();
    super.dispose();
  }

  void _toggleAutoScroll() {
    setState(() {
      _isAutoScrolling = !_isAutoScrolling;
      if (_isAutoScrolling) {
        _scrollTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.offset + 0.5);
          }
        });
      } else {
        _scrollTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Color> bgColors = [Colors.white, const Color(0xFFF4ECD8), const Color(0xFF121212)];
    List<Color> txtColors = [Colors.black87, const Color(0xFF5B4636), Colors.white];

    return Scaffold(
      backgroundColor: bgColors[_themeIndex],
      appBar: _isFull ? null : AppBar(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        title: Text(widget.cantique.titre, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.remove), onPressed: () => setState(() => _fontSize -= 2)),
          IconButton(icon: const Icon(Icons.add), onPressed: () => setState(() => _fontSize += 2)),
          IconButton(
            icon: Icon(_themeIndex == 2 ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _themeIndex = (_themeIndex + 1) % 3),
          ),
          IconButton(icon: const Icon(Icons.fullscreen), onPressed: () => setState(() => _isFull = true)),
        ],
      ),
      body: GestureDetector(
        onDoubleTap: () => setState(() => _isFull = !_isFull),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(25, _isFull ? 60 : 20, 25, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!_isFull) ...[
                Center(
                  child: Hero(
                    tag: 'hero-${widget.cantique.id}',
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: const Icon(Icons.music_note, color: Colors.redAccent, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(widget.cantique.titre, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                Text("Auteur : ${widget.cantique.auteur}", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                const Divider(height: 30),
              ],
              Text(
                widget.cantique.paroles,
                style: TextStyle(fontSize: _fontSize, color: txtColors[_themeIndex], height: 1.6),
              ),
              if (_isFull)
                Center(child: TextButton(onPressed: () => setState(() => _isFull = false), child: const Text("Quitter le plein écran")))
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: _toggleAutoScroll,
        child: Icon(_isAutoScrolling ? Icons.pause : Icons.play_arrow, color: Colors.white),
      ),
    );
  }
}
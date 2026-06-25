import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:untitled13/models/cantique.dart';

class GenererProgrammePage extends StatefulWidget {
  final List<Cantique> tousLesChants;
  const GenererProgrammePage({super.key, required this.tousLesChants});

  @override
  State<GenererProgrammePage> createState() => _GenererProgrammePageState();
}

class _GenererProgrammePageState extends State<GenererProgrammePage> {
  final List<String> _selectedIds = [];
  String _qrData = "";

  void _genererQR() {
    if (_selectedIds.isEmpty) return;
    // On crée la chaîne magique : "CANTIQUE_PROG:id1,id2,id3..."
    setState(() {
      _qrData = "CANTIQUE_PROG:${_selectedIds.join(',')}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Créer un Programme", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _qrData.isNotEmpty ? _buildQrView() : _buildSelectionView(),
    );
  }

  Widget _buildSelectionView() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Sélectionnez les chants pour le culte de ce dimanche :",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: widget.tousLesChants.length,
            itemBuilder: (context, index) {
              final chant = widget.tousLesChants[index];
              final isSelected = _selectedIds.contains(chant.id);
              return CheckboxListTile(
                activeColor: Colors.redAccent,
                title: Text(chant.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(chant.auteur),
                value: isSelected,
                onChanged: (bool? val) {
                  setState(() {
                    if (val == true) {
                      _selectedIds.add(chant.id);
                    } else {
                      _selectedIds.remove(chant.id);
                    }
                  });
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.qr_code),
            label: Text("Générer le QR Code (${_selectedIds.length} chants)"),
            onPressed: _selectedIds.isEmpty ? null : _genererQR,
          ),
        )
      ],
    );
  }

  Widget _buildQrView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Programme Prêt !",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            const Text(
              "Demandez aux choristes ou aux fidèles de scanner ce code depuis leur application.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
              ),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 250.0,
                gapless: false,
              ),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              icon: const Icon(Icons.arrow_back, color: Colors.redAccent),
              label: const Text("Modifier la sélection", style: TextStyle(color: Colors.redAccent)),
              onPressed: () => setState(() => _qrData = ""),
            )
          ],
        ),
      ),
    );
  }
}
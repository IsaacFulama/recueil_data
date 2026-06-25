import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled13/models/cantique.dart';
import 'PageParoles.dart';

class ScannerProgrammePage extends StatefulWidget {
  final List<Cantique> tousLesChants;
  const ScannerProgrammePage({super.key, required this.tousLesChants});

  @override
  State<ScannerProgrammePage> createState() => _ScannerProgrammePageState();
}

class _ScannerProgrammePageState extends State<ScannerProgrammePage> {
  List<Cantique> _programmeScanne = [];
  bool _hasScanned = false;

  void _analyserCode(String code) {
    if (_hasScanned) return;

    if (code.startsWith("CANTIQUE_PROG:")) {
      setState(() {
        _hasScanned = true;
      });

      // Extraction des IDs (ex: "1,5,12")
      final idsRaw = code.replaceAll("CANTIQUE_PROG:", "");
      final List<String> ids = idsRaw.split(",");

      // Filtrage immédiat dans la mémoire locale
      List<Cantique> resultat = widget.tousLesChants.where((c) => ids.contains(c.id)).toList();

      // Réorganiser selon l'ordre choisi par le chef de chœur
      resultat.sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));

      setState(() {
        _programmeScanne = resultat;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_programmeScanne.isNotEmpty ? "Programme du Jour" : "Scanner un Programme"),
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
      ),
      body: _programmeScanne.isNotEmpty
          ? _buildListeProgramme()
          : _buildCameraScanner(),
    );
  }

  Widget _buildCameraScanner() {
    return Stack(
      children: [
        MobileScanner(
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              if (barcode.rawValue != null) {
                _analyserCode(barcode.rawValue!);
              }
            }
          },
        ),
        // Masque de visée pour guider l'utilisateur
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.redAccent, width: 4),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Text(
            "Cadrez le QR Code du Chef de Chœur",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, backgroundColor: Colors.black45),
          ),
        )
      ],
    );
  }

  Widget _buildListeProgramme() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _programmeScanne.length,
      itemBuilder: (context, index) {
        final chant = _programmeScanne[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              child: Text("${index + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            title: Text(chant.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(chant.auteur),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PageParoles(cantique: chant))),
          ),
        );
      },
    );
  }
}
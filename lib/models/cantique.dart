class Cantique {
  final String id;
  final String titre;
  final String paroles;
  final String auteur;
  bool isFavorite;

  Cantique({
    required this.id,
    required this.titre,
    required this.auteur,
    required this.paroles,
    this.isFavorite = false,
  });

  // Convertit le JSON du serveur en objet Dart
  factory Cantique.fromJson(Map<String, dynamic> json) {
    return Cantique(
      id: json['id'].toString(),
      titre: json['titre'] ?? "Sans titre",
      auteur: json['auteur'] ?? "Auteur inconnu",
      paroles: json['paroles'] ?? "",
    );
  }
}
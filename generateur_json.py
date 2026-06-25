import json
import os

FILENAME = "cantiques.json"

def charger_existants():
    if os.path.exists(FILENAME):
        try:
            with open(FILENAME, "r", encoding="utf-8") as f:
                return json.load(f)
        except:
            return []
    return []

def ajouter_cantique():
    cantiques = charger_existants()

    # Génération automatique de l'ID
    prochain_id = str(len(cantiques) + 1)

    print(f"--- AJOUT DU CANTIQUE N°{prochain_id} ---")
    titre = input("Titre du cantique : ").strip()
    auteur = input("Auteur (Appuie sur Entrée si inconnu) : ").strip()
    if not auteur:
        auteur = "Auteur inconnu"

    print("\nColle ou écris les paroles ci-dessous.")
    print("Quand tu as terminé, tape 'FIN' sur une nouvelle ligne et valide :\n")

    lignes_paroles = []
    while True:
        ligne = input()
        if ligne.strip() == "FIN":
            break
        lignes_paroles.append(ligne)

    paroles_formatees = "\n".join(lignes_paroles).strip()

    # Création du nouvel objet
    nouveau_chant = {
        "id": prochain_id,
        "titre": titre,
        "auteur": auteur,
        "paroles": paroles_formatees
    }

    cantiques.append(nouveau_chant)

    # Sauvegarde dans le fichier
    with open(FILENAME, "w", encoding="utf-8") as f:
        json.dump(cantiques, f, ensure_ascii=False, indent=2)

    print(f"\n✅ Le cantique '{titre}' a été ajouté avec succès dans {FILENAME} !")

if __name__ == "__main__":
    while True:
        ajouter_cantique()
        continuer = input("\nVoulez-vous ajouter un autre chant ? (o/n) : ").lower()
        if continuer != 'o':
            print("Au revoir !")
            break
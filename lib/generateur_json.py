import json
import os

FILENAME = "cantiques.json"
VERSION_FILE = "version.json"

def charger_existants():
    if os.path.exists(FILENAME):
        try:
            with open(FILENAME, "r", encoding="utf-8") as f:
                return json.load(f)
        except:
            return []
    return []

def incrementer_version():
    version = 1
    if os.path.exists(VERSION_FILE):
        try:
            with open(VERSION_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
                version = data.get("version", 1) + 1
        except:
            pass

    with open(VERSION_FILE, "w", encoding="utf-8") as f:
        json.dump({"version": version}, f, ensure_ascii=False, indent=2)
    print(f"🚀 Version du catalogue incrémentée automatiquement à : {version}")

def ajouter_cantique():
    cantiques = charger_existants()
    prochain_id = str(len(cantiques) + 1)

    print(f"\n--- AJOUT DU CANTIQUE N°{prochain_id} ---")
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

    nouveau_chant = {
        "id": prochain_id,
        "titre": titre,
        "auteur": auteur,
        "paroles": paroles_formatees
    }

    cantiques.append(nouveau_chant)

    with open(FILENAME, "w", encoding="utf-8") as f:
        json.dump(cantiques, f, ensure_ascii=False, indent=2)

    print(f"✅ Le cantique '{titre}' a été ajouté localement avec succès !")
    incrementer_version()

if __name__ == "__main__":
    while True:
        ajouter_cantique()
        continuer = input("\nVoulez-vous ajouter un autre chant ? (o/n) : ").lower()
        if continuer != 'o':
            print("Au revoir !")
            break
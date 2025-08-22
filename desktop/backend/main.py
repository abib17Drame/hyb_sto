# -*- coding: utf-8 -*-

import os
import socket
import hashlib
import datetime
import json
import shutil
from typing import Optional, List, Dict
import sys # Added for os.name

from fastapi import FastAPI, Query, WebSocket, WebSocketDisconnect, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
import uvicorn

# --- Gestionnaire de Connexions WebSocket ---
class GestionnaireConnexions:
    def __init__(self):
        self.connexions_actives: List[WebSocket] = []
        self.connexions_par_appareil: Dict[str, List[WebSocket]] = {}
        self.appareil_par_ws: Dict[WebSocket, str] = {}

    async def connecter_pour_appareil(self, websocket: WebSocket, id_appareil: str):
        await websocket.accept()
        self.connexions_actives.append(websocket)
        self.connexions_par_appareil.setdefault(id_appareil, []).append(websocket)
        self.appareil_par_ws[websocket] = id_appareil

    def deconnecter(self, websocket: WebSocket):
        if websocket in self.connexions_actives:
            self.connexions_actives.remove(websocket)
        id_appareil = self.appareil_par_ws.pop(websocket, None)
        if id_appareil:
            liste = self.connexions_par_appareil.get(id_appareil, [])
            if websocket in liste:
                liste.remove(websocket)
            if not liste:
                self.connexions_par_appareil.pop(id_appareil, None)

    async def envoyer_message_personnel(self, message: str, websocket: WebSocket):
        await websocket.send_text(message)

    async def fermer_connexions_pour_appareil(self, id_appareil: str, code: int = 1008, message: Optional[str] = None):
        sockets = list(self.connexions_par_appareil.get(id_appareil, []))
        for ws in sockets:
            try:
                if message is not None:
                    await ws.send_text(message)
            except Exception:
                pass
            try:
                await ws.close(code=code)
            except Exception:
                pass
            self.deconnecter(ws)

gestionnaire = GestionnaireConnexions()

# --- Configuration de l'application FastAPI ---
application_fastapi = FastAPI(title="API du Stockage Hybride Desktop")
application_fastapi.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"],
)

# --- "Base de données" en mémoire ---
# Valeur par défaut du répertoire de base si aucun paramètre n'a encore été défini
REPERTOIRE_DE_BASE_DEFAUT = os.path.join(os.path.expanduser("~"), "HybridStorage")
appareils_appaires_db = {}
cle_privee_serveur = None
parametres_db = {
    "stockage": {"dossier_principal": REPERTOIRE_DE_BASE_DEFAUT},
    "application": {"lancement_demarrage": True, "theme": "systeme"},
    # Utilise le port de l'environnement (par défaut 8001) pour correspondre au lancement Electron
    "reseau": {"port_ecoute": int(os.environ.get("FASTAPI_PORT", "8001"))},
}

def _obtenir_ip_locale() -> str:
    """Retourne l'adresse IP locale (LAN) de la machine hôte.
    Évite 127.0.0.1 en ouvrant un socket UDP non connecté.
    """
    ip = "127.0.0.1"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        # N'a pas besoin d'être joignable, on n'envoie rien
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
    except Exception:
        pass
    finally:
        try:
            s.close()
        except Exception:
            pass
    return ip

@application_fastapi.on_event("startup")
def au_demarrage():
    global cle_privee_serveur
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    if not os.path.exists(base_dir):
        os.makedirs(base_dir, exist_ok=True)
    cle_privee_serveur = rsa.generate_private_key(public_exponent=65537, key_size=2048)

# --- Modèles Pydantic ---
class AppareilClient(BaseModel):
    id_appareil: str
    nom_appareil: str
    cle_publique_pem: str

class ParametresStockage(BaseModel):
    dossier_principal: str
class ParametresApplication(BaseModel):
    lancement_demarrage: bool
    theme: str
class ParametresReseau(BaseModel):
    port_ecoute: int
class ParametresComplets(BaseModel):
    stockage: ParametresStockage
    application: ParametresApplication
    reseau: ParametresReseau

# --- Endpoints HTTP ---
@application_fastapi.get("/")
def lire_racine():
    return {"message": "Bienvenue !", "status": "running", "timestamp": datetime.datetime.now().isoformat()}

@application_fastapi.get("/api/v1/test")
def test_endpoint():
    """Endpoint de test simple"""
    return {
        "status": "ok",
        "message": "Serveur desktop fonctionne",
        "timestamp": datetime.datetime.now().isoformat(),
        "base_dir": parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    }

@application_fastapi.get("/api/v1/appairage/generer-code")
def generer_code_appairage():
    cle_publique = cle_privee_serveur.public_key()
    pem_cle_publique = cle_publique.public_bytes(encoding=serialization.Encoding.PEM, format=serialization.PublicFormat.SubjectPublicKeyInfo)
    der_cle_publique = cle_publique.public_bytes(encoding=serialization.Encoding.DER, format=serialization.PublicFormat.SubjectPublicKeyInfo)
    hachage = hashlib.sha256(der_cle_publique).hexdigest()
    empreinte_formatee = ':'.join(hachage[i:i+2] for i in range(0, 32, 2)).upper()
    ip_locale = _obtenir_ip_locale()
    api_port = parametres_db.get("reseau", {}).get("port_ecoute", 8001)
    grpc_port = int(os.environ.get("GRPC_PORT", "50051"))
    donnees_qr = {
        "nom_hote": socket.gethostname(),
        "ip": ip_locale,
        "api_port": api_port,
        "grpc_port": grpc_port,
        "cle_publique_pem": pem_cle_publique.decode('utf-8'),
    }
    return {"donnees_pour_qr": donnees_qr, "empreinte_securite": empreinte_formatee}

@application_fastapi.post("/api/v1/appairage/completer")
def completer_appairage(appareil_client: AppareilClient):
    appareils_appaires_db[appareil_client.id_appareil] = appareil_client.dict()
    return {"statut": "succes"}

@application_fastapi.get("/api/v1/appareils")
def lister_appareils():
    return list(appareils_appaires_db.values())

@application_fastapi.delete("/api/v1/appareils/{id_appareil}")
async def revoquer_appareil(id_appareil: str):
    if id_appareil in appareils_appaires_db:
        del appareils_appaires_db[id_appareil]
        # Notifie et ferme les connexions actives de cet appareil
        payload = json.dumps({"action": "revoked", "statut": "erreur", "message": "Appareil révoqué"})
        await gestionnaire.fermer_connexions_pour_appareil(id_appareil, code=4003, message=payload)
        return {"statut": "succes"}
    return {"statut": "erreur"}

def lister_fichiers_logique(chemin: str):
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    # S'assure que le dossier existe
    if not os.path.exists(base_dir):
        os.makedirs(base_dir, exist_ok=True)
    chemin_securise = os.path.normpath(os.path.join(base_dir, chemin.strip('/\\')))
    if not chemin_securise.startswith(os.path.normpath(base_dir)):
        raise ValueError("Accès non autorisé")
    contenu = []
    for nom in os.listdir(chemin_securise):
        chemin_complet = os.path.join(chemin_securise, nom)
        stats = os.stat(chemin_complet)
        contenu.append({
            "nom": nom, "chemin": os.path.join(chemin, nom),
            "type": "dossier" if os.path.isdir(chemin_complet) else "fichier",
            "tailleOctets": stats.st_size,
            "modifieLe": datetime.datetime.fromtimestamp(stats.st_mtime).isoformat()
        })
    return {"chemin_actuel": chemin, "contenu": contenu}

@application_fastapi.get("/api/v1/fichiers/lister")
def lister_fichiers_http(chemin: Optional[str] = Query(default="/")):
    try:
        return lister_fichiers_logique(chemin)
    except Exception as e:
        return {"erreur": str(e)}

@application_fastapi.delete("/api/v1/fichiers/supprimer")
def supprimer_fichier_ou_dossier(chemin: str = Query(default="/")):
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    chemin_securise = os.path.normpath(os.path.join(base_dir, chemin.strip('/\\')))
    if not chemin_securise.startswith(os.path.normpath(base_dir)):
        return {"statut": "erreur", "message": "Accès non autorisé"}
    try:
        if os.path.isdir(chemin_securise):
            # Suppression récursive du dossier
            import shutil
            shutil.rmtree(chemin_securise)
        elif os.path.exists(chemin_securise):
            os.remove(chemin_securise)
        else:
            return {"statut": "erreur", "message": "Chemin introuvable"}
        return {"statut": "succes"}
    except Exception as e:
        return {"statut": "erreur", "message": str(e)}

@application_fastapi.post("/api/v1/fichiers/renommer")
def renommer_fichier_ou_dossier(payload: dict):
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    source = os.path.normpath(os.path.join(base_dir, str(payload.get('source', '')).strip('/\\')))
    destination = os.path.normpath(os.path.join(base_dir, str(payload.get('destination', '')).strip('/\\')))
    if not source.startswith(os.path.normpath(base_dir)) or not destination.startswith(os.path.normpath(base_dir)):
        return {"statut": "erreur", "message": "Accès non autorisé"}
    try:
        os.renames(source, destination)
        return {"statut": "succes"}
    except Exception as e:
        return {"statut": "erreur", "message": str(e)}

@application_fastapi.post("/api/v1/fichiers/ouvrir")
def ouvrir_fichier(payload: dict | None = None, chemin: str | None = Query(default=None)):
    """Ouvre un fichier avec l'application par défaut du système"""
    # Accepte soit JSON body { path: ..., chemin: ... } soit query ?chemin=...
    path = None
    if payload:
        path = payload.get('path') or payload.get('chemin')
    if not path:
        path = chemin
    if not path:
        return {"statut": "erreur", "message": "Paramètre 'path' ou 'chemin' requis"}
    
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    chemin_complet = os.path.normpath(os.path.join(base_dir, str(path).strip('/\\')))
    
    print(f"[DEBUG OPEN FILE] base_dir={base_dir}")
    print(f"[DEBUG OPEN FILE] chemin={path}")
    print(f"[DEBUG OPEN FILE] chemin_complet={chemin_complet}")
    
    # Vérification de sécurité
    if not chemin_complet.startswith(os.path.normpath(base_dir)):
        return {"statut": "erreur", "message": "Accès non autorisé"}
    
    if not os.path.exists(chemin_complet):
        return {"statut": "erreur", "message": "Fichier introuvable"}
    
    try:
        # Ouvrir le fichier avec l'application par défaut
        if os.name == 'nt':  # Windows
            os.startfile(chemin_complet)
        elif os.name == 'posix':  # macOS et Linux
            import subprocess
            subprocess.run(['open', chemin_complet] if sys.platform == 'darwin' else ['xdg-open', chemin_complet])
        
        print(f"[SUCCESS] Fichier ouvert: {chemin_complet}")
        return {"statut": "succes", "message": f"Fichier ouvert: {os.path.basename(chemin_complet)}"}
    except Exception as e:
        print(f"[ERREUR] lors de l'ouverture: {e}")
        return {"statut": "erreur", "message": str(e)}

@application_fastapi.post("/api/v1/fichiers/open_file")
def open_file_alias(payload: dict | None = None, chemin: str | None = Query(default=None)):
    """Alias anglais pour compatibilité mobile; délègue à ouvrir_fichier."""
    return ouvrir_fichier(payload=payload, chemin=chemin)

@application_fastapi.post("/api/v1/fichiers/upload")
async def upload_fichier(file: UploadFile, chemin_destination: str = Form(default="/")):
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    chemin_complet = os.path.normpath(os.path.join(base_dir, chemin_destination.strip('/\\'), file.filename))
    
    print(f"[DEBUG UPLOAD] base_dir={base_dir}")
    print(f"[DEBUG UPLOAD] chemin_destination={chemin_destination}")
    print(f"[DEBUG UPLOAD] filename={file.filename}")
    print(f"[DEBUG UPLOAD] chemin_complet={chemin_complet}")
    
    # Vérification de sécurité
    if not chemin_complet.startswith(os.path.normpath(base_dir)):
        print(f"[ERREUR] Accès non autorisé - chemin_complet={chemin_complet}, base_dir={base_dir}")
        return {"statut": "erreur", "message": "Accès non autorisé"}
    
    try:
        # Créer le dossier de destination si nécessaire
        os.makedirs(os.path.dirname(chemin_complet), exist_ok=True)
        print(f"[SUCCESS] Dossier créé: {os.path.dirname(chemin_complet)}")
        
        # Sauvegarder le fichier
        with open(chemin_complet, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        print(f"[SUCCESS] Fichier sauvegardé: {chemin_complet}")
        return {"statut": "succes", "message": f"Fichier {file.filename} uploadé avec succès"}
    except Exception as e:
        print(f"[ERREUR] lors de l'upload: {e}")
        return {"statut": "erreur", "message": str(e)}

@application_fastapi.post("/api/v1/fichiers/upload-dossier")
async def upload_dossier(files: List[UploadFile], chemin_destination: str = Form(default="/")):
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    resultats = []
    
    for file in files:
        try:
            chemin_complet = os.path.normpath(os.path.join(base_dir, chemin_destination.strip('/\\'), file.filename))
            
            # Vérification de sécurité
            if not chemin_complet.startswith(os.path.normpath(base_dir)):
                resultats.append({"fichier": file.filename, "statut": "erreur", "message": "Accès non autorisé"})
                continue
            
            # Créer le dossier de destination si nécessaire
            os.makedirs(os.path.dirname(chemin_complet), exist_ok=True)
            
            # Sauvegarder le fichier
            with open(chemin_complet, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            
            resultats.append({"fichier": file.filename, "statut": "succes"})
        except Exception as e:
            resultats.append({"fichier": file.filename, "statut": "erreur", "message": str(e)})
    
    return {"resultats": resultats}

@application_fastapi.post("/api/v1/fichiers/creer-dossier")
def creer_dossier(payload: dict | None = None, chemin: str | None = Query(default=None)):
    """Crée un dossier dans le répertoire de stockage"""
    # Accepte { chemin: ... } en JSON ou ?chemin=...
    path = payload.get('chemin') if payload else None
    if not path:
        path = chemin
    if not path:
        return {"statut": "erreur", "message": "Paramètre 'chemin' requis"}
    
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    chemin_complet = os.path.normpath(os.path.join(base_dir, str(path).strip('/\\')))
    
    print(f"[DEBUG CREATE DIR] base_dir={base_dir}")
    print(f"[DEBUG CREATE DIR] chemin={path}")
    print(f"[DEBUG CREATE DIR] chemin_complet={chemin_complet}")
    
    # Vérification de sécurité
    if not chemin_complet.startswith(os.path.normpath(base_dir)):
        return {"statut": "erreur", "message": "Accès non autorisé"}
    
    try:
        os.makedirs(chemin_complet, exist_ok=True)
        print(f"[SUCCESS] Dossier créé: {chemin_complet}")
        return {"statut": "succes", "message": f"Dossier créé: {path}"}
    except Exception as e:
        print(f"[ERREUR] création dossier: {e}")
        return {"statut": "erreur", "message": str(e)}

@application_fastapi.get("/api/v1/fichiers/debug-storage")
def debug_storage():
    """Endpoint de debug pour voir le contenu du dossier de stockage"""
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    
    if not os.path.exists(base_dir):
        return {"statut": "erreur", "message": f"Dossier de base n'existe pas: {base_dir}"}
    
    try:
        contenu = []
        for root, dirs, files in os.walk(base_dir):
            for file in files:
                file_path = os.path.join(root, file)
                relative_path = os.path.relpath(file_path, base_dir)
                contenu.append({
                    "nom": file,
                    "chemin_relatif": relative_path,
                    "chemin_complet": file_path,
                    "taille": os.path.getsize(file_path)
                })
        
        return {
            "statut": "succes",
            "dossier_base": base_dir,
            "contenu": contenu,
            "nombre_fichiers": len(contenu)
        }
    except Exception as e:
        return {"statut": "erreur", "message": str(e)}

@application_fastapi.get("/api/v1/fichiers/liste")
def lister_fichiers_http(chemin: Optional[str] = Query(default="/")):
    try:
        return lister_fichiers_logique(chemin)
    except Exception as e:
        return {"erreur": str(e)}

@application_fastapi.get("/api/v1/parametres")
def lire_parametres():
    return parametres_db

@application_fastapi.post("/api/v1/parametres")
def sauvegarder_parametres(parametres: ParametresComplets):
    global parametres_db
    parametres_db = parametres.dict()
    # Crée le dossier de stockage si besoin
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    if not os.path.exists(base_dir):
        os.makedirs(base_dir, exist_ok=True)
    print(f"Paramètres sauvegardés: {parametres_db}")
    return {"statut": "succes"}

# --- Statistiques de stockage et tableau de bord ---
def _calculer_stats_stockage():
    base_dir = parametres_db.get("stockage", {}).get("dossier_principal", REPERTOIRE_DE_BASE_DEFAUT)
    try:
        total, utilise, libre = shutil.disk_usage(base_dir).total, None, None
        usage = shutil.disk_usage(base_dir)
        total = usage.total
        libre = usage.free
        utilise = total - libre
        to_gib = lambda v: round(v / (1024 ** 3), 1)
        return {"utiliseGo": to_gib(utilise), "totalGo": to_gib(total)}
    except Exception:
        return {"utiliseGo": 0.0, "totalGo": 0.0}

@application_fastapi.get("/api/v1/stockage/statistiques")
def lire_statistiques_stockage():
    stockage = _calculer_stats_stockage()
    appareils = [
        {"nom": v.get("nom_appareil", "Appareil"), "type": "mobile", "statut": "Actif"}
        for v in appareils_appaires_db.values()
    ]
    return {"stockage": stockage, "appareilsConnectes": appareils, "activiteRecente": []}

@application_fastapi.get("/api/v1/tableau-de-bord/statistiques")
def lire_statistiques_tableau_de_bord():
    # Alias compatible avec le frontend desktop existant
    return lire_statistiques_stockage()

# --- Endpoint WebSocket ---
@application_fastapi.websocket("/ws/{id_appareil}")
async def websocket_endpoint(websocket: WebSocket, id_appareil: str):
    if id_appareil not in appareils_appaires_db:
        await websocket.close(code=1008); return
    await gestionnaire.connecter_pour_appareil(websocket, id_appareil)
    try:
        while True:
            # Ferme si l'appareil a été révoqué entre-temps
            if id_appareil not in appareils_appaires_db:
                payload = json.dumps({"action": "revoked", "statut": "erreur", "message": "Appareil révoqué"})
                try:
                    await websocket.send_text(payload)
                except Exception:
                    pass
                await websocket.close(code=4003)
                break

            donnees = await websocket.receive_text()
            message = json.loads(donnees)
            action = message.get("action")
            if action == "lister_fichiers":
                chemin = message.get("charge_utile", {}).get("chemin", "/")
                try:
                    reponse = {"action": "liste_fichiers", "statut": "succes", "donnees": lister_fichiers_logique(chemin)}
                except Exception as e:
                    reponse = {"action": "liste_fichiers", "statut": "erreur", "message": str(e)}
                await gestionnaire.envoyer_message_personnel(json.dumps(reponse), websocket)
    except WebSocketDisconnect:
        gestionnaire.deconnecter(websocket)
    except Exception:
        # En cas d'erreur, s'assurer du nettoyage
        gestionnaire.deconnecter(websocket)

# --- Lancement ---
if __name__ == "__main__":
    # Par défaut, écoute sur toutes les interfaces et sur le port configuré
    uvicorn.run(
        "main:application_fastapi",
        host=os.environ.get("FASTAPI_HOST", "0.0.0.0"),
        port=int(os.environ.get("FASTAPI_PORT", str(parametres_db.get("reseau", {}).get("port_ecoute", 8001)))),
        reload=True,
    )

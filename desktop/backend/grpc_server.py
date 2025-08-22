import grpc
from concurrent import futures
import os
import transfer_pb2
import transfer_pb2_grpc

# Le répertoire de base où tous les fichiers seront stockés.
# Doit être le même que dans main.py
REPERTOIRE_DE_BASE = os.path.join(os.path.expanduser("~"), "HybridStorage")

class FileTransferServicer(transfer_pb2_grpc.FileTransferServicer):
    """Implémente le service de transfert de fichiers défini dans le .proto."""

    def UploadFile(self, request_iterator, context):
        """
        Reçoit un flux de morceaux de fichier et les écrit sur le disque.
        Le premier morceau est supposé contenir les métadonnées (nom du fichier).
        """
        # Pour cet exemple, on suppose que le nom du fichier est dans les métadonnées du contexte.
        # Une implémentation plus robuste enverrait les métadonnées dans le premier chunk.
        metadata = dict(context.invocation_metadata())
        nom_fichier = metadata.get("nom-fichier", "fichier_upload_inconnu.bin")
        chemin_fichier = os.path.join(REPERTOIRE_DE_BASE, nom_fichier)

        print(f"Début de la réception du fichier : {nom_fichier}")

        try:
            with open(chemin_fichier, 'wb') as f:
                for chunk in request_iterator:
                    f.write(chunk.content)

            print(f"Fichier {nom_fichier} reçu avec succès.")
            return transfer_pb2.UploadStatus(success=True, message="Fichier uploadé avec succès.")
        except Exception as e:
            print(f"Erreur lors de l'upload du fichier : {e}")
            return transfer_pb2.UploadStatus(success=False, message=f"Erreur serveur : {e}")

    def DownloadFile(self, request, context):
        """
        Lit un fichier sur le disque et le renvoie au client sous forme de flux.
        """
        chemin_fichier_demande = request.remote_file_path
        chemin_fichier_securise = os.path.normpath(os.path.join(REPERTOIRE_DE_BASE, chemin_fichier_demande.strip('/\\')))

        print(f"Demande de téléchargement pour : {chemin_fichier_securise}")

        # Vérification de sécurité
        if not chemin_fichier_securise.startswith(os.path.normpath(REPERTOIRE_DE_BASE)):
            context.set_details("Accès non autorisé")
            context.set_code(grpc.StatusCode.PERMISSION_DENIED)
            return transfer_pb2.Chunk()

        if not os.path.exists(chemin_fichier_securise):
            context.set_details("Fichier non trouvé")
            context.set_code(grpc.StatusCode.NOT_FOUND)
            return transfer_pb2.Chunk()

        try:
            with open(chemin_fichier_securise, 'rb') as f:
                while True:
                    # Lit le fichier par morceaux de 1 Mo
                    piece = f.read(1024 * 1024)
                    if not piece:
                        break
                    yield transfer_pb2.Chunk(content=piece)
            print(f"Fichier {chemin_fichier_securise} envoyé avec succès.")
        except Exception as e:
            print(f"Erreur lors de l'envoi du fichier : {e}")
            context.set_details(f"Erreur serveur : {e}")
            context.set_code(grpc.StatusCode.INTERNAL)
            return transfer_pb2.Chunk()

def demarrer_serveur_grpc():
    """Démarre le serveur gRPC."""
    serveur = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
    transfer_pb2_grpc.add_FileTransferServicer_to_server(FileTransferServicer(), serveur)
    # Hôte/port configurables via variables d'env, valeurs sûres par défaut
    hote = os.environ.get('GRPC_HOST', '0.0.0.0')
    port = os.environ.get('GRPC_PORT', '50051')
    adresse_ecoute = f'{hote}:{port}'
    # Tente d'ouvrir le port et valide le résultat
    resultat_port = serveur.add_insecure_port(adresse_ecoute)
    if not resultat_port:
        raise RuntimeError(f"Impossible d'ouvrir le port gRPC sur {adresse_ecoute}.")
    serveur.start()
    print(f"Serveur gRPC démarré et à l'écoute sur {adresse_ecoute}")
    serveur.wait_for_termination()

if __name__ == '__main__':
    demarrer_serveur_grpc()

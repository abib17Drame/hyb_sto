// Importations des modules nécessaires d'Electron.
const { app, BrowserWindow, ipcMain, dialog } = require('electron');
const path = require('path');
const { spawn, spawnSync } = require('child_process'); // Pour lancer le processus Python

// Ports/host configurables via variables d'environnement
const FASTAPI_HOST = process.env.FASTAPI_HOST || '0.0.0.0';
const FASTAPI_PORT = process.env.FASTAPI_PORT || '8001';
const GRPC_HOST = process.env.GRPC_HOST || '127.0.0.1';
const GRPC_PORT = process.env.GRPC_PORT || '50051';

// Variable globale pour garder une référence à la fenêtre principale.
// Si on ne fait pas ça, la fenêtre pourrait être fermée automatiquement
// lorsque l'objet JavaScript est récupéré par le ramasse-miettes (garbage collector).
let fenetre_principale;
let processus_fastapi;
let processus_grpc;

// Résout la commande Python à utiliser (gère venv Windows, py, python, python3)
function resoudreCommandePython() {
  const backendDir = path.join(__dirname, 'backend');

  // Priorité à la variable d'environnement explicite
  if (process.env.PYTHON && process.env.PYTHON.trim().length > 0) {
    return { cmd: process.env.PYTHON.trim(), baseArgs: [] };
  }

  const candidats = [];
  if (process.platform === 'win32') {
    candidats.push({ cmd: path.join(backendDir, 'venv', 'Scripts', 'python.exe'), baseArgs: [] });
    candidats.push({ cmd: path.join(backendDir, '.venv', 'Scripts', 'python.exe'), baseArgs: [] });
    candidats.push({ cmd: 'py', baseArgs: ['-3'] });
    candidats.push({ cmd: 'py', baseArgs: [] });
    candidats.push({ cmd: 'python', baseArgs: [] });
    candidats.push({ cmd: 'python3', baseArgs: [] });
  } else {
    // macOS/Linux
    candidats.push({ cmd: path.join(backendDir, 'venv', 'bin', 'python3'), baseArgs: [] });
    candidats.push({ cmd: path.join(backendDir, '.venv', 'bin', 'python3'), baseArgs: [] });
    candidats.push({ cmd: 'python3', baseArgs: [] });
    candidats.push({ cmd: 'python', baseArgs: [] });
  }

  for (const c of candidats) {
    try {
      const resultat = spawnSync(c.cmd, [...c.baseArgs, '--version'], {
        cwd: backendDir,
        shell: true,
        stdio: 'ignore',
      });
      if (resultat && resultat.status === 0) {
        return c;
      }
    } catch (_) {
      // ignore et continue avec le prochain candidat
    }
  }
  return null;
}

// Fonction pour créer la fenêtre de l'application.
function creer_fenetre() {
  // Crée une nouvelle fenêtre de navigateur.
  fenetre_principale = new BrowserWindow({
    width: 1200,
    height: 800,
    webPreferences: {
      // Le `preload.js` n'est pas utilisé dans cette configuration simple,
      // mais il est essentiel pour une communication sécurisée entre le processus principal
      // et le processus de rendu (le frontend React).
      // preload: path.join(__dirname, 'preload.js'),
      nodeIntegration: true, // Non recommandé pour la production, mais simple pour démarrer.
      contextIsolation: false, // Idem.
    },
  });

  // Charge l'URL du frontend React.
  // En développement, React est servi par `react-scripts` sur le port 3000.
  fenetre_principale.loadURL('http://localhost:3000');

  // Ouvre les Outils de Développement (DevTools) pour le débogage.
  fenetre_principale.webContents.openDevTools();

  // Émis lorsque la fenêtre est fermée.
  fenetre_principale.on('closed', () => {
    // Supprime la référence à la fenêtre.
    fenetre_principale = null;
  });
}

// IPC: Ouvrir un sélecteur de dossier et retourner le chemin choisi
ipcMain.handle('ouvrir-dialog-dossier', async (_event, defaultPath) => {
  try {
    const options = {
      properties: ['openDirectory', 'createDirectory'],
    };
    if (defaultPath && typeof defaultPath === 'string' && defaultPath.trim().length > 0) {
      options.defaultPath = defaultPath;
    }
    const resultat = await dialog.showOpenDialog(BrowserWindow.getFocusedWindow() || null, options);
    if (resultat.canceled || !resultat.filePaths || resultat.filePaths.length === 0) {
      return null;
    }
    return resultat.filePaths[0];
  } catch (e) {
    console.error('[IPC ouvrir-dialog-dossier] Erreur:', e);
    return null;
  }
});

// Fonctions pour démarrer les serveurs backend.
function demarrer_serveur_fastapi() {
  console.log(`Démarrage du serveur FastAPI sur le port ${FASTAPI_PORT}...`);
  const backendDir = path.join(__dirname, 'backend');
  const py = resoudreCommandePython();
  if (!py) {
    console.error('[Erreur FastAPI]: Python introuvable. Installez Python 3.x ou créez un venv dans desktop/backend/.venv');
    return;
  }
  const args = [...py.baseArgs, '-m', 'uvicorn', 'main:application_fastapi', '--host', FASTAPI_HOST, '--port', FASTAPI_PORT];
  processus_fastapi = spawn(py.cmd, args, {
    cwd: backendDir,
    shell: true,
    env: { ...process.env, FASTAPI_HOST, FASTAPI_PORT },
  });

  processus_fastapi.stdout.on('data', (data) => console.log(`[FastAPI]: ${data}`));
  processus_fastapi.stderr.on('data', (data) => console.error(`[Erreur FastAPI]: ${data}`));
}

function demarrer_serveur_grpc() {
  console.log('Démarrage du serveur gRPC...');
  const backendDir = path.join(__dirname, 'backend');
  const py = resoudreCommandePython();
  if (!py) {
    console.error('[Erreur gRPC]: Python introuvable. Installez Python 3.x ou créez un venv dans desktop/backend/.venv');
    return;
  }
  const args = [...py.baseArgs, 'grpc_server.py'];
  processus_grpc = spawn(py.cmd, args, {
    cwd: backendDir,
    shell: true,
    env: { ...process.env, GRPC_HOST, GRPC_PORT },
  });

  processus_grpc.stdout.on('data', (data) => console.log(`[gRPC]: ${data}`));
  processus_grpc.stderr.on('data', (data) => console.error(`[Erreur gRPC]: ${data}`));
}

// Cette méthode sera appelée quand Electron aura fini
// son initialisation et sera prêt à créer des fenêtres de navigateur.
// Certaines APIs peuvent être utilisées uniquement après cet événement.
app.on('ready', () => {
  demarrer_serveur_fastapi();
  demarrer_serveur_grpc();
  creer_fenetre();
});

// Quitte l'application quand toutes les fenêtres sont fermées.
app.on('window-all-closed', () => {
  // Sur macOS, il est commun pour les applications et leur barre de menu
  // de rester actives jusqu'à ce que l'utilisateur quitte explicitement avec Cmd + Q.
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

// Sur macOS, il est commun de recréer une fenêtre dans l'application quand
// l'icône du dock est cliquée et qu'il n'y a pas d'autres fenêtres d'ouvertes.
app.on('activate', () => {
  if (fenetre_principale === null) {
    creer_fenetre();
  }
});

// Assure que les processus Python sont bien terminés quand l'application Electron quitte.
app.on('will-quit', () => {
  console.log('Arrêt des serveurs backend...');
  if (processus_fastapi) processus_fastapi.kill();
  if (processus_grpc) processus_grpc.kill();
});

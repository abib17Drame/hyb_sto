import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './Parametres.css';
import { API_URL } from '../config';

function Parametres() {
  const [parametres, definirParametres] = useState(null);
  const [erreur, definirErreur] = useState('');
  const [chargement, definirChargement] = useState(true);
  const [messageSauvegarde, definirMessageSauvegarde] = useState('');
  // ipcRenderer pour Electron si disponible
  let ipcRenderer;
  try {
    // Disponible lorsque l'app tourne dans Electron avec nodeIntegration
    ipcRenderer = window.require && window.require('electron') && window.require('electron').ipcRenderer;
  } catch (_) {
    ipcRenderer = undefined;
  }

  useEffect(() => {
    const recupererParametres = async () => {
      definirChargement(true);
      try {
        const reponse = await axios.get(`${API_URL}/api/v1/parametres`);
        definirParametres(reponse.data);
      } catch (err) {
        definirErreur('Impossible de charger les paramètres.');
        console.error(err);
      } finally {
        definirChargement(false);
      }
    };
    recupererParametres();
  }, []);

  // Applique le thème lorsqu'il est chargé ou modifié
  useEffect(() => {
    const theme = parametres?.application?.theme;
    if (!theme) return;
    try {
      document.documentElement.setAttribute('data-theme', theme);
      localStorage.setItem('theme_application', theme);
    } catch (_) {}
  }, [parametres?.application?.theme]);

  const handleChangement = (categorie, cle, valeur) => {
    definirParametres(prev => ({
      ...prev,
      [categorie]: {
        ...prev[categorie],
        [cle]: valeur,
      }
    }));
  };

  const sauvegarderParametres = async (e) => {
    e.preventDefault(); // Empêche le rechargement de la page pour un formulaire
    definirMessageSauvegarde('Sauvegarde en cours...');
    try {
      await axios.post(`${API_URL}/api/v1/parametres`, parametres);
      definirMessageSauvegarde('Paramètres sauvegardés avec succès !');
    } catch (err) {
      definirMessageSauvegarde("Erreur lors de la sauvegarde.");
      console.error(err);
    }
    // Fait disparaître le message après 3 secondes
    setTimeout(() => definirMessageSauvegarde(''), 3000);
  };

  const ouvrirSelecteurDossier = async () => {
    try {
      // Pré-remplir avec la valeur actuelle si possible
      const valeurActuelle = parametres?.stockage?.dossier_principal || '';
      if (ipcRenderer && ipcRenderer.invoke) {
        const chemin = await ipcRenderer.invoke('ouvrir-dialog-dossier', valeurActuelle);
        if (chemin) {
          handleChangement('stockage', 'dossier_principal', chemin);
        }
      } else {
        // Fallback web: simple prompt
        const saisie = window.prompt('Saisissez le chemin du dossier de stockage', valeurActuelle);
        if (saisie && saisie.trim().length > 0) {
          handleChangement('stockage', 'dossier_principal', saisie.trim());
        }
      }
    } catch (e) {
      console.error('Erreur lors de la sélection du dossier:', e);
    }
  };

  if (chargement) return <div>Chargement des paramètres...</div>;
  if (erreur) return <div className="erreur-message">{erreur}</div>;
  if (!parametres) return <div>Aucun paramètre trouvé.</div>;

  return (
    <form className="ecran-parametres" onSubmit={sauvegarderParametres}>
      <h1>Paramètres</h1>

      {/* --- Section Stockage --- */}
      <div className="section-parametres">
        <h2>Stockage</h2>
        <div className="champ-parametre">
          <label htmlFor="dossier_principal">Dossier de stockage principal</label>
          <div className="champ-avec-bouton">
            <input
              type="text"
              id="dossier_principal"
              value={parametres.stockage.dossier_principal}
              onChange={(e) => handleChangement('stockage', 'dossier_principal', e.target.value)}
            />
            <button type="button" onClick={ouvrirSelecteurDossier}>Parcourir...</button>
          </div>
        </div>
      </div>

      {/* --- Section Application --- */}
      <div className="section-parametres">
        <h2>Application</h2>
        <div className="champ-parametre-checkbox">
          <input
            type="checkbox"
            id="lancement_demarrage"
            checked={parametres.application.lancement_demarrage}
            onChange={(e) => handleChangement('application', 'lancement_demarrage', e.target.checked)}
          />
          <label htmlFor="lancement_demarrage">Lancer l'application au démarrage du système</label>
        </div>
        <div className="champ-parametre">
          <label htmlFor="theme">Thème de l'application</label>
          <select
            id="theme"
            value={parametres.application.theme}
            onChange={(e) => handleChangement('application', 'theme', e.target.value)}
          >
            <option value="systeme">Thème du système</option>
            <option value="clair">Clair</option>
            <option value="sombre">Sombre</option>
          </select>
        </div>
      </div>

      {/* --- Section Réseau --- */}
      <div className="section-parametres">
        <h2>Réseau</h2>
        <div className="champ-parametre">
          <label htmlFor="port_ecoute">Port d'écoute</label>
          <input
            type="number"
            id="port_ecoute"
            value={parametres.reseau.port_ecoute}
            onChange={(e) => handleChangement('reseau', 'port_ecoute', parseInt(e.target.value, 10))}
          />
        </div>
      </div>

      {/* --- Actions --- */}
      <div className="actions-globales">
        {messageSauvegarde && <span className="message-sauvegarde">{messageSauvegarde}</span>}
        <button type="submit" className="bouton-sauvegarder">
          Sauvegarder les changements
        </button>
      </div>
    </form>
  );
}

export default Parametres;

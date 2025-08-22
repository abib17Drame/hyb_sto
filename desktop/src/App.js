import React, { useState, useEffect } from 'react';
import { Routes, Route, Link, useLocation } from 'react-router-dom';
import axios from 'axios';
import './App.css';

import TableauDeBord from './composants/TableauDeBord';
import ExplorateurFichiers from './composants/ExplorateurFichiers';
import Appareils from './composants/Appareils';
import Parametres from './composants/Parametres';
import EcranAppairage from './composants/EcranAppairage';
import { API_URL } from './config';

function BarreLaterale() {
  const location = useLocation();
  const estActif = (chemin) => location.pathname === chemin;

  return (
    <nav className="barre-laterale">
      <div className="logo-conteneur">
        <h2>HybridStorage</h2>
      </div>
      <ul>
        <li className={estActif('/') ? 'actif' : ''}>
          <Link to="/">Tableau de bord</Link>
        </li>
        <li className={estActif('/explorateur') ? 'actif' : ''}>
          <Link to="/explorateur">Explorateur</Link>
        </li>
        <li className={estActif('/appareils') ? 'actif' : ''}>
          <Link to="/appareils">Appareils</Link>
        </li>
        <li className={estActif('/parametres') ? 'actif' : ''}>
          <Link to="/parametres">Paramètres</Link>
        </li>
      </ul>
    </nav>
  );
}

function App() {
  const [estAppaire, definirEstAppaire] = useState(false);
  const [afficherAppairage, definirAfficherAppairage] = useState(false);
  const [chargement, definirChargement] = useState(true);

  // Fonction pour vérifier s'il y a des appareils appairés
  const verifierAppareilsAppaires = async () => {
    try {
      const reponse = await axios.get(`${API_URL}/api/v1/appareils`);
      const aDesAppareils = reponse.data.length > 0;
      definirEstAppaire(aDesAppareils);
      
      // Si on était en train d'afficher l'appairage mais qu'il y a maintenant des appareils,
      // on ferme l'écran d'appairage
      if (aDesAppareils && afficherAppairage) {
        definirAfficherAppairage(false);
      }
    } catch (err) {
      console.error("Erreur lors de la vérification des appareils:", err);
      // En cas d'erreur, on considère qu'il n'y a pas d'appareils
      definirEstAppaire(false);
    } finally {
      definirChargement(false);
    }
  };

  // Cette fonction sera passée à l'écran d'appairage pour qu'il puisse
  // mettre à jour l'état de l'application principale.
  const handleAppairageReussi = () => {
    definirEstAppaire(true);
    definirAfficherAppairage(false);
  };

  const ouvrirEcranAppairage = () => {
    definirAfficherAppairage(true);
  };

  // Vérifier les appareils au démarrage et régulièrement
  useEffect(() => {
    verifierAppareilsAppaires();
    
    // Vérifier toutes les 5 secondes s'il y a des appareils appairés
    const interval = setInterval(verifierAppareilsAppaires, 5000);
    
    return () => clearInterval(interval);
  }, []);

  // Afficher l'écran de chargement pendant la vérification initiale
  if (chargement) {
    return <div style={{ display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh' }}>
      Chargement...
    </div>;
  }

  // Afficher l'écran d'appairage si aucun appareil n'est appairé ou si on veut afficher l'appairage
  if (!estAppaire || afficherAppairage) {
    return <EcranAppairage surAppairageReussi={handleAppairageReussi} />;
  }

  return (
    <div className="app-conteneur">
      <BarreLaterale />
      <main className="contenu-principal">
        <Routes>
          <Route path="/" element={<TableauDeBord />} />
          <Route path="/explorateur" element={<ExplorateurFichiers />} />
          <Route path="/appareils" element={<Appareils onOuvrirAppairage={ouvrirEcranAppairage} onAppareilRevoque={verifierAppareilsAppaires} />} />
          <Route path="/parametres" element={<Parametres />} />
        </Routes>
      </main>
    </div>
  );
}

export default App;

import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './TableauDeBord.css';
import { API_URL } from '../config';

// Composant pour afficher les statistiques de stockage
function WidgetStockage({ stockage }) {
  if (!stockage) return <div className="widget carte loading">Chargement...</div>;
  const pourcentage_utilise = (stockage.utiliseGo / stockage.totalGo) * 100;
  return (
    <div className="widget carte">
      <h3>État du Stockage</h3>
      <div className="barre-progression-conteneur">
        <div className="barre-progression" style={{ width: `${pourcentage_utilise}%` }}></div>
      </div>
      <p>{stockage.utiliseGo} Go utilisés sur {stockage.totalGo} Go ({pourcentage_utilise.toFixed(1)}%)</p>
    </div>
  );
}

// Composant pour afficher les appareils connectés
function WidgetAppareils({ appareils }) {
  if (!appareils) return <div className="widget carte loading">Chargement...</div>;
  return (
    <div className="widget carte">
      <h3>Appareils Connectés</h3>
      <ul>
        {appareils.map((appareil, index) => (
          <li key={index} className={`statut-${appareil.statut.toLowerCase().replace(' ', '-')}`}>
            <strong>{appareil.nom}</strong> ({appareil.type}) - <span>{appareil.statut}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

// Composant pour afficher le journal d'activité
function WidgetActivite({ activites }) {
  if (!activites) return <div className="widget carte loading">Chargement...</div>;
  return (
    <div className="widget carte">
      <h3>Activité Récente</h3>
      <ul>
        {activites.map((activite, index) => (
          <li key={index}>
            <span>[{activite.heure}]</span> {activite.action}
          </li>
        ))}
      </ul>
    </div>
  );
}

// Composant principal du tableau de bord
function TableauDeBord() {
  const [donnees, definirDonnees] = useState(null);
  const [erreur, definirErreur] = useState('');

  useEffect(() => {
    const recupererDonnees = async () => {
      try {
        const reponse = await axios.get(`${API_URL}/api/v1/tableau-de-bord/statistiques`);
        definirDonnees(reponse.data);
      } catch (err) {
        console.error("Erreur lors de la récupération des données du tableau de bord:", err);
        definirErreur('Impossible de charger les données du tableau de bord.');
      }
    };
    recupererDonnees();
  }, []);

  if (erreur) {
    return <div className="erreur-globale">{erreur}</div>;
  }

  if (!donnees) {
    return <div className="chargement-global">Chargement du tableau de bord...</div>;
  }

  return (
    <div className="tableau-de-bord">
      <h1>Tableau de bord</h1>
      <div className="grille-widgets">
        <WidgetStockage stockage={donnees.stockage} />
        <WidgetAppareils appareils={donnees.appareilsConnectes} />
        <WidgetActivite activites={donnees.activiteRecente} />
      </div>
    </div>
  );
}

export default TableauDeBord;

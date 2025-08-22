import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './Appareils.css';
import { API_URL } from '../config';

function Appareils({ onOuvrirAppairage, onAppareilRevoque }) {
  const [appareils, definirAppareils] = useState([]);
  const [erreur, definirErreur] = useState('');
  const [chargement, definirChargement] = useState(true);

  // Fonction pour récupérer la liste des appareils depuis le backend
  const recupererAppareils = async () => {
    definirChargement(true);
    try {
      const reponse = await axios.get(`${API_URL}/api/v1/appareils`);
      definirAppareils(reponse.data);
    } catch (err) {
      console.error("Erreur lors de la récupération des appareils:", err);
      definirErreur("Impossible de charger la liste des appareils.");
    } finally {
      definirChargement(false);
    }
  };

  // useEffect pour appeler la fonction de récupération au chargement du composant
  useEffect(() => {
    recupererAppareils();
  }, []);

  const revoquerAppareil = async (id_appareil) => {
    if (window.confirm("Êtes-vous sûr de vouloir révoquer l'accès pour cet appareil ?")) {
      try {
        await axios.delete(`${API_URL}/api/v1/appareils/${id_appareil}`);
        // Rafraîchit la liste des appareils après la suppression
        recupererAppareils();
        // Notifier le parent qu'un appareil a été révoqué
        if (onAppareilRevoque) {
          onAppareilRevoque();
        }
      } catch (err) {
        console.error("Erreur lors de la révocation de l'appareil:", err);
        alert("Une erreur est survenue lors de la révocation.");
      }
    }
  };

  if (chargement) {
    return <div>Chargement des appareils...</div>;
  }

  if (erreur) {
    return <div className="erreur-message">{erreur}</div>;
  }

  return (
    <div className="ecran-appareils">
      <div className="en-tete-appareils">
        <h1>Appareils Appairés</h1>
        <button className="bouton-primaire" onClick={onOuvrirAppairage}>
          Appairer un nouvel appareil
        </button>
      </div>

      <div className="tableau-conteneur">
        <table>
          <thead>
            <tr>
              <th>Nom de l'appareil</th>
              <th>Type</th>
              <th>Date d'appairage</th>
              <th>Statut</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {appareils.length > 0 ? (
              appareils.map(appareil => (
                <tr key={appareil.id_appareil || appareil.id || Math.random()}>
                  <td>{appareil.nom_appareil || appareil.nom || 'Appareil'}</td>
                  <td>{appareil.type || 'mobile'}</td>
                  <td>{appareil.date_appairage ? new Date(appareil.date_appairage).toLocaleDateString('fr-FR') : '-'}</td>
                  <td>
                    <span className={`pastille-statut statut-${(appareil.statut || 'actif').toLowerCase()}`}>
                      {appareil.statut || 'Actif'}
                    </span>
                  </td>
                  <td>
                    <button
                      className="bouton-action-revoquer"
                      onClick={() => revoquerAppareil(appareil.id_appareil || appareil.id)}
                    >
                      Révoquer
                    </button>
                  </td>
                </tr>
              ))
            ) : (
              <tr>
                <td colSpan="5" style={{ textAlign: 'center' }}>Aucun appareil appairé.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default Appareils;

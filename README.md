# Simulations sociales avec GAMA

Projet réalisé dans le cadre du cours MOSIMA en Master 2 à Sorbonne Université.

Ce dépôt contient deux modèles de simulation multi-agents :

- **Schelling** : formation de quartiers ségrégés selon les préférences de voisinage des agents.
- **Bounded Confidence** : évolution des opinions par discussion, en population mélangée ou sur une grille, avec une variante incluant des agents extrémistes à opinion fixe.

## Lancer une simulation

Avec **GAMA 2025.6** :

1. Importer les projets `gama/Schelling` et `gama/BoundedConfidence` via `File > Import > GAMA > Existing projects into workspace`.
2. Ouvrir un modèle et lancer une expérience interactive :

| Fichier | Expérience |
|---|---|
| `SchellingGrid.gaml` | `Schelling_Grid` |
| `BC_Base.gaml` | `BC_Base_Test` ou `BC_Base_1000` |
| `BC_Grid.gaml` | `BC_Grid` |
| `BC_Grid_Extremistes.gaml` | `BC_Extremistes` |

3. Modifier les paramètres dans l’interface pour observer leur effet.

Les résultats des expériences sont disponibles au format CSV dans `resultats/`.

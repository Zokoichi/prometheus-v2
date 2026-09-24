# PROMETHEUS V2 — Evidence Layer

Cette couche constitue la base de génération automatique du portfolio.

## Principe

Le portfolio ne doit pas être alimenté par des affirmations manuelles.

Pipeline :

REAL WORK
→ TEST
→ RESULT
→ EVIDENCE
→ DOCUMENTATION
→ PORTFOLIO

## Sources de vérité

Les preuves doivent provenir du projet réel :

- `tests/`
- `contracts/`
- `scripts/`
- `config/`
- `docs/`

## Règle

Aucune compétence, réalisation ou performance ne doit être déclarée sans preuve identifiable.

Une future génération automatique pourra associer :

- une réalisation ;
- une compétence technique ;
- un test ;
- un résultat ;
- une décision technique ;
- une limitation ;
- une évolution ;
- un chemin de preuve dans le dépôt.

## Statut initial

Cette première version installe uniquement l'infrastructure de preuve.

Elle ne déclare volontairement aucune compétence validée dans `project.json`.

La génération automatique des preuves sera ajoutée dans une étape ultérieure.

# PROMETHEUS — Automatisation de production média

## Vue d'ensemble

PROMETHEUS est une série de workflows et de composants expérimentaux visant à automatiser une chaîne de production média.

Trajectoire technique observée :

RESEARCH → SELECTION → SCRIPT → AUDIO → VISUALS → ASSEMBLY → STORAGE → PUBLICATION → MONITORING

Le corpus historique comprend notamment plusieurs générations : CORE_V3, PRODUCER_V1.2, PRODUCER_v1.5, V5_PRO, V7_PROD, V8_FINAL et VIDEO_CORE_v1.31.

## Architecture observée

Dans le corpus n8n analysé :

- 136 nœuds Code
- 98 nœuds HTTP/API
- 36 nœuds Execute Command
- 21 nœuds NocoDB
- 23 opérations de lecture/écriture de fichiers
- 9 nœuds Merge
- 6 nœuds RSS
- 2 Error Trigger

Ces chiffres décrivent la structure du corpus et ne constituent pas des mesures de performance.

## Réalisations techniques observables

### Orchestration

Déclencheurs, conditions, transformations, appels HTTP, fusion de données et orchestration de traitements.

### Traitement par code

De nombreux nœuds Code sont utilisés pour préparer, transformer, contrôler et transmettre des données.

### Audio et vidéo

Plusieurs générations utilisent des commandes système et des opérations fichiers pour la génération ou le traitement audio, le montage de segments, l'assemblage final, la vérification et le nettoyage.

### Persistance

NocoDB est utilisé pour lire des éléments, conserver un historique et mettre à jour des états.

### Gestion des erreurs

Les workflows WATCHDOG utilisent notamment Error Trigger, nettoyage et journalisation.

## PROMETHEUS V2

Le dépôt contient également une Evidence Layer dédiée dans `portfolio/evidence`, avec des preuves issues des répertoires `tests`, `contracts`, `scripts`, `config` et `docs`.

Les familles de preuves déjà identifiées comprennent :

- Scene Plan / Compiler
- génération de script
- pipeline audio
- Storage Adapter
- contrats de production média
- orchestration et concurrence PostgreSQL

## Limites

Aucune vente, revenu, audience, ROI ou performance commerciale n'est déclarée : ces résultats ne sont pas démontrés par les preuves actuellement retenues.

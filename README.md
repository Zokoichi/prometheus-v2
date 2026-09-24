# PROMETHEUS V2

## Système expérimental de production média automatisée et validée par preuves

PROMETHEUS V2 est un projet d'ingénierie expérimental consacré à la conception d'une chaîne de production média automatisée, modulaire et vérifiable.

L'objectif du projet est de construire progressivement une boucle de production capable d'intégrer :

RESEARCH → IDEA / ANGLE → HOOK → SCRIPT → SCENE PLAN → VOICE → VISUALS → ASSEMBLY → QA → PUBLISH → MEASURE → LEARN → EXPERIMENT

Le projet privilégie une approche fondée sur les contrats techniques, la reproductibilité, les tests et les preuves plutôt que sur de simples déclarations de fonctionnalités.

---

## Objectifs techniques

Le projet explore notamment :

- l'orchestration de pipelines de production ;
- la séparation entre contrats, configuration, exécution et validation ;
- la production d'artefacts structurés ;
- la validation automatique de résultats ;
- la traçabilité des artefacts ;
- la reproductibilité des traitements ;
- l'isolation des environnements de test et de production ;
- la gestion d'objets et d'artefacts ;
- la persistance et la validation des données ;
- l'automatisation de workflows ;
- la génération d'éléments de preuve destinés à documenter les réalisations.

---

## Architecture et technologies

Les éléments actuellement présents dans le projet utilisent notamment :

- Docker
- PostgreSQL
- n8n
- SeaweedFS
- PowerShell
- JSON
- SQL

La liste ci-dessus décrit les technologies réellement présentes dans le dépôt ; elle ne constitue pas une déclaration de maîtrise professionnelle de chacune d'elles.

---

## Architecture documentaire

    contracts/     Contrats et interfaces techniques
    config/        Configuration non sensible
    docs/          Documentation technique
    scripts/       Scripts d'automatisation et de validation
    tests/         Tests, rapports et preuves techniques
    portfolio/     Evidence Layer et données du futur portfolio
    db/            Éléments liés à la persistance
    renderer/      Éléments liés au rendu

---

## Evidence Layer

PROMETHEUS V2 contient une couche dédiée à la transformation du travail technique réel en preuves documentées.

Principe :

    REAL WORK
        ↓
    TEST
        ↓
    RESULT
        ↓
    EVIDENCE
        ↓
    DOCUMENTATION
        ↓
    PORTFOLIO

La règle fondamentale est :

> Aucune compétence, réalisation ou performance ne doit être déclarée sans réalisation, preuve ou validation identifiable.

La source de vérité actuelle repose notamment sur :

- `tests/`
- `contracts/`
- `scripts/`
- `config/`
- `docs/`

Le manifeste du projet est disponible dans :

    portfolio/project/project.json

---

## Validation

Le projet est développé selon une logique de validation progressive :

    TEST
    ↓
    OBSERVE
    ↓
    DIAGNOSE
    ↓
    MODIFY
    ↓
    RETEST
    ↓
    VERIFY
    ↓
    FREEZE

Les tests présents dans le dépôt constituent les principales preuves techniques du fonctionnement ou de l'état des différents composants.

Un résultat de test doit être distingué d'une fonctionnalité considérée comme définitivement terminée.

---

## État du projet

PROMETHEUS V2 est un projet actif et évolutif.

Certaines parties sont validées par des tests et des artefacts reproductibles.

D'autres restent expérimentales ou nécessitent encore des validations supplémentaires.

Le dépôt privilégie donc une présentation factuelle de l'état réel du système plutôt qu'une présentation marketing de fonctionnalités non démontrées.

---

## Philosophie d'ingénierie

Le projet suit plusieurs principes :

1. Les preuves priment sur les affirmations.
2. Les contrats précèdent les implémentations lorsqu'ils sont nécessaires à la stabilité du système.
3. Les tests doivent produire des résultats observables.
4. Les artefacts validés doivent être traçables.
5. Les composants doivent rester remplaçables lorsque cela est pertinent.
6. Les limitations doivent être documentées plutôt que masquées.
7. Les secrets et données privées ne doivent jamais être publiés.

---

## Sécurité et publication

Ce dépôt est destiné à présenter du travail technique publiable.

Les éléments sensibles de l'environnement local sont volontairement exclus du dépôt, notamment :

- fichiers `.env` contenant des credentials ;
- données runtime locales ;
- credentials ;
- tokens ;
- clés privées ;
- sauvegardes locales ;
- informations confidentielles.

Le fichier `.env.example`, lorsqu'il est présent, constitue uniquement un modèle de configuration et ne doit contenir aucune valeur secrète réelle.

Avant chaque publication, un audit des fichiers suivis par Git doit être effectué.

---

## Reproductibilité

L'objectif à terme est que les éléments significatifs du projet puissent être compris et, lorsque l'environnement le permet, reproduits à partir :

- du code ;
- des contrats ;
- de la configuration non sensible ;
- des scripts ;
- des tests ;
- des artefacts de preuve ;
- de la documentation.

Les dépendances à un environnement local ou à des services externes doivent être documentées lorsqu'elles sont nécessaires à la reproduction.

---

## Portfolio

Le répertoire `portfolio/` constitue la base d'un futur système de génération automatique de portfolio.

L'objectif est de pouvoir produire progressivement une présentation professionnelle à partir du travail réellement effectué :

    Projet réel
        ↓
    Preuve technique
        ↓
    Evidence Layer
        ↓
    Documentation
        ↓
    Portfolio généré

Cela permet d'éviter de maintenir manuellement une liste de compétences déconnectée des réalisations.

---

## Limites

PROMETHEUS V2 ne doit pas être considéré comme un système industriel ou comme un produit terminé.

Les résultats présentés dans ce dépôt doivent être interprétés en fonction :

- des tests disponibles ;
- de leur environnement d'exécution ;
- de leurs rapports ;
- des limitations documentées ;
- de l'état de développement du projet.

---

## Évolution

Le projet évolue par validations successives.

Les nouveaux composants doivent idéalement être accompagnés de :

- leur contrat ou spécification ;
- leur implémentation ;
- leurs tests ;
- leurs résultats ;
- leurs artefacts ;
- leur documentation ;
- leurs limitations éventuelles.

---

## Statut

**Projet :** PROMETHEUS V2  
**Type :** projet d'ingénierie expérimental  
**Statut :** actif  
**Evidence Layer :** installée  
**Publication :** préparée pour audit avant exposition publique

## Portfolio technique

Le dossier [`portfolio/presentation`](./portfolio/presentation/) présente les réalisations techniques documentées à partir d'artefacts réellement produits et vérifiés.

La publication distingue explicitement structure démontrée, comportement observable, validation expérimentale et résultats externes.

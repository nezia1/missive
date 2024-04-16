# Missive

- [Missive](#missive)
  - [Installation](#installation)
    - [Prérequis](#prérequis)
    - [Procédure](#procédure)
      - [Production](#production)
      - [Local](#local)
  - [Organisation du projet](#organisation-du-projet)

Missive est une application de messagerie sécurisée, basée sur le protocole Signal. Elle permet d'échanger des messages chiffrés de bout-en-bout avec différents utilisateurs. Elle a été réalisée dans le cadre du travail de diplôme de technicien ES en développement d'applications au CFPT informatique de Genève, promotion 2024.

Vous pouvez retrouver la documentation complète de l'application [sur cette page](https://anthony-rdrgz.docs.ictge.ch/missive). Elle comprend une explication du fonctionnement, des choix techniques, des cas d'utilisation, ainsi que l'intégralité de mon journal de bord durant le développement de l'application.

## Installation

### Prérequis

- [Node.js](https://nodejs.org/en/) (version 21.7.2 ou supérieure)
- [Flutter](https://flutter.dev/) (version 3.19.3 ou supérieure)
- [Docker](https://www.docker.com/) (version 26.0.0 ou supérieure)

### Procédure

Les procédures d'installation de la partie serveur et client sont détaillées dans un `README.md` présent dans leur dossier respectif.

Un docker-compose est disponible à la racine du projet, et permet de déployer l'application sur un serveur cloud, ou alors de lancer un déploiement local.

#### Production

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

#### Local

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Organisation du projet

Le projet est découpé en multiples sous dossiers et sous dépôts :

- `documentation` : contient le code source de la documentation de l'application (réalisée grâce à MKDocs)
- `server` : contient le code source du serveur (comprend l'API REST et le serveur WebSocket)
- `client` : contient le code source du client (application mobile réalisée en Flutter)
- `poc` : contient le code source du Proof of Concept (application réalisée durant le cadre du travail de semestre, afin de pouvoir tester les fonctionnalités d'authentification)

Il contient également un `docker-compose.yml`, qui permet le déploiement du serveur de l'application sur le cloud.

De plus, différents workspaces VSCode sont disponibles afin d'aider au développement si vous utilisez cet éditeur.

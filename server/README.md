# Missive Server

Ce dossier contient la partie serveur de Missive. Il contient une API REST qui permet de gérer et d'authentifier des utilisateurs, des routes pour gérer les messages, ainsi qu'une fonctionnalité d'authentification à deux facteurs (TOTP).

Il contient également un serveur WebSocket qui va permettre de gérer la partie messagerie en temps réelle.

## Installation

### Prérequis

- NodeJS v21.7.2 ([https://nodejs.org/](https://nodejs.org/))
- Une base de données PostgreSQL

### Procédure

Pour installer les dépendances :

```bash
npm install
```

Après avoir cloné le dépôt en local et installé les prérequis, il faut créer un fichier `.env` à la racine du dossier `server` (copiez le .env.example) et remplir les variables d'environnement suivantes :

- `DATABASE_URL` : URL de la base de données (URI standard Postgres)
- `COOKIE_SECRET` : Clé secrète pour les cookies

#### Ajout du fichier de configuration pour Firebase Admin SDK

Afin de pouvoir envoyer des notifications, il est nécessaire d'ajouter un fichier de configuration pour Firebase Admin SDK (Firebase Cloud Messaging est utilisé). Pour cela, il faut créer un compte de service sur Firebase et télécharger le fichier de configuration. Une fois cela fait, il faut ajouter le fichier `service-account-file.json` à la racine du dossier `server`.

#### Génération des clés

Il faudra également générer les clés pour signer les tokens JWT. Pour cela, vous pouvez utiliser les commandes suivantes :

```bash
openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -pubout -in private_key.pem -out public_key.pem
```

Assurez vous de les générer à la racine du dossier `api`.

#### Ajout du compte de service pour Firebase

Missive utilise FCM, qui lui permet d'envoyer des notifications push. Pour cela, il est nécessaire de créer un compte de service sur Firebase, et de télécharger le fichier de configuration. Une fois cela fait, il faut ajouter le fichier `service-account-file.json` à la racine du dossier `server`. Vous trouverez plus d'informations sur la [documentation officielle de Firebase](https://firebase.google.com/docs/admin/setup#initialize-sdk).

#### Lancement du serveur en mode développement

Le serveur de Missive utilise Docker, afin d'avoir un environnement de développement similaire à celui de production, et reproducible. Pour lancer le serveur en mode développement, voici les étapes à suivre :

```bash
cd .. # Pour revenir à la racine du projet
docker compose -f docker-compose.yml -f docker-compose.dev.yml up --build -d # Pour lancer le serveur en mode développement
docker compose -f docker-compose.yml -f docker-compose.dev.yml logs -f # Pour voir les logs du serveur (possible de filtrer par service)
```

# Missive API

Ce dossier contient la partie API de Missive. Il contient une API REST qui permet de gérer et d'authentifier des utilisateurs, des routes pour gérer les messages, ainsi qu'une fonctionnalité d'authentification à deux facteurs (TOTP).

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

#### Génération des clés

Il faudra également générer les clés pour signer les tokens JWT. Pour cela, vous pouvez utiliser les commandes suivantes :

- `openssl genpkey -algorithm RSA -out private_key.pem -pkeyopt rsa_keygen_bits:2048`
- `openssl rsa -pubout -in private_key.pem -out public_key.pem`

Assurez vous de les générer à la racine du dossier `api`.

Pour lancer le serveur en mode développement :

```bash
npm run dev
```

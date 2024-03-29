# poc-flutter-api

Ce dossier contient la partie serveur de mon POC Flutter. Il contient une API REST qui permet de gérer et d'authentifier des utilisateurs, ainsi qu'une fonctionnalité d'authentification à deux facteurs (TOTP).

## Installation

### Prérequis

- Bun (<https://bun.sh>)
- Une base de données PostgreSQL

### Procédure

Pour installer les dépendances :

```bash
bun install
```

Après avoir cloné le dépôt en local et installé les prérequis, il faut créer un fichier `.env` à la racine du dossier `server` (copiez le .env.example) et y ajouter les variables suivantes :

- `DATABASE_URL` : l'URL de la base de données PostgreSQL
- `JWT_SECRET` : la clé secrète utilisée pour générer les tokens JWT
- `COOKIE_SECRET` : la clé secrète utilisée pour signer les cookies

Pour lancer le serveur en mode développement :

```bash
bun dev
```

Pour lancer le serveur en mode production :

```bash
bun start
```

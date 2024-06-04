# Missive

Missive est une application iOS / Android de messagerie instantanée sécurisée chiffrée de bout-en bout. Elle implémente le protocole Signal afin de chiffrer les messages.

## Structure du projet

Le projet est divisé avec la structure standard de Flutter. La structure du dossier lib étant libre, j'ai choisi de partir sur une approche *feature-first* qui me permet de séparer les différentes fonctionnalités de l'application dans des dossiers distincts.:

- **constants** : Contient les constantes du projet
- **features** : Contient les différentes fonctionnalités de l'application (contient les écrans, les modèles, les services, ...)

```sh
lib
├── common # éléments communs à plusieurs fichiers
├── constants # constantes de l'application (couleurs...)
└── features
    ├── authentication
    │   ├── models
    │   └── providers
    ├── chat
    │   ├── models
    │   ├── providers
    │   └── screens
    └── encryption
        └── providers
``` 
## Crédits

- Icône de l'application : [messaging, Gregor Cresnar](https://thenounproject.com/icon/messaging-6249502/) (CC BY 3.0)

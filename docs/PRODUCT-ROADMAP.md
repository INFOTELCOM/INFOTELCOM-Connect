# INFOTELCOM Connect — feuille de route produit

Cette feuille de route décrit les capacités à rapprocher d'outils comme Microsoft Teams, WhatsApp, Discord et Telegram, tout en conservant l'identité INFOTELCOM Connect, la séparation stricte entre entreprises et les autorisations Supabase.

## Déjà présentes dans le socle actuel
- Authentification, espaces d'entreprise, membres, rôles et invitations.
- Canaux, messages temps réel, réactions, épingles, fils de discussion et brouillons locaux.
- Recherche de messages, notifications, export CSV, documents, présence, journal d'audit.
- Réunions via liens Jitsi, calendrier partagé, tâches et tableaux de suivi.
- Navigation mobile et barre de navigation basse.

## Lots proposés

### Lot A — expérience quotidienne
- Profils complets : photo, nom affiché, fonction, bio et statut de disponibilité.
- Statuts éphémères avec expiration automatique à 24 h, visibilité configurable et contrôle de suppression.
- Répertoire des membres, recherche par nom et création de conversations sans saisir d'identifiants UUID.
- États de livraison/lecture des messages, réponses rapides, édition et suppression avec journalisation.
- Recherche unifiée dans les messages, fichiers, membres et canaux autorisés.

### Lot B — conversations et communautés
- Messages vocaux avec enregistrement, aperçu, annulation et lecture accessible.
- Pièces jointes avec progression, limites par rôle, reprise d'envoi si le stockage choisi la prend en charge, et liens signés.
- Canaux publics/privés, fils, annonces, rôles par canal, invitations et demandes d'accès.
- Communautés découvrables avec soumission, modération et approbation par l'équipe autorisée.
- Outils de modération : signalement, limitation de débit, suppression/masquage et journal d'audit.

### Lot C — réunions et travail d'équipe
- Réunions avec participants, agenda, rappels et liens de calendrier.
- Tâches assignables, échéances, filtres, commentaires et notifications.
- Partage d'écran, audio/vidéo et salle d'attente uniquement via un fournisseur de visioconférence configuré et testé.
- Notifications web/push, préférences par canal et mode « ne pas déranger ».

### Lot D — mobile, résilience et administration
- Interface mobile dédiée : navigation basse, gestes tactiles, formulaires adaptés et états de chargement.
- Mode hors ligne limité aux brouillons et contenus explicitement mis en cache, avec synchronisation et conflits gérés.
- Administration INFOTELCOM centralisée, demandes d'accès, export contrôlé et journalisation.
- Tests de sécurité multi-entreprises : RLS, accès aux fichiers, permissions par rôle et tests d'isolation automatisés.
- Accessibilité clavier, contrastes, réduction des animations et tests sur petits écrans.

## Règles techniques non négociables
1. Une fonction n'est considérée comme livrée qu'après migration SQL, politiques RLS, tests et intégration UI lorsque ces éléments sont nécessaires.
2. Ne jamais exposer de clé Supabase service-role dans le navigateur.
3. Ne pas présenter un lien de réunion comme privé ou sécurisé si le fournisseur ne contrôle pas l'accès à la salle.
4. Les statuts temporaires, messages vocaux, reçus de lecture et communautés nécessitent un modèle de données explicite ; ne pas les simuler avec du stockage local partagé.
5. Toute lecture/écriture doit rester limitée à l'organisation et aux rôles autorisés.
6. Le mode hors ligne ne doit pas mettre en cache des conversations privées sans politique claire de stockage et d'effacement.

## Critères d'acceptation pour chaque lot
- Build de production réussi.
- Test mobile à 320, 375, 390, 768 et 1024 px.
- Vérification des états vide, chargement, erreur et absence de réseau.
- Tests RLS avec deux organisations différentes et plusieurs rôles.
- Vérification des migrations sur un environnement de test avant production.
- Documentation des variables d'environnement et des réglages fournisseurs.

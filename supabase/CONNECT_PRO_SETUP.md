# INFOTELCOM Connect Pro — activation des réactions, fils et notifications

## 1. Appliquer la migration SQL

Dans Supabase > SQL Editor, exécuter intégralement `migrations/202610130001_connect_pro_features.sql`. Cela crée les tables de réactions, messages épinglés, notifications, abonnements push et la colonne `parent_message_id`.

## 2. Déployer la fonction push

Depuis la racine du dépôt, avec Supabase CLI lié au projet :
```sh
supabase functions deploy send-push --no-verify-jwt
supabase secrets set PUSH_WEBHOOK_SECRET="une-longue-valeur-aleatoire"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="CLE_SERVICE_ROLE_DU_PROJET"
supabase secrets set VAPID_PUBLIC_KEY="CLE_PUBLIQUE_VAPID"
supabase secrets set VAPID_PRIVATE_KEY="CLE_PRIVEE_VAPID"
supabase secrets set VAPID_SUBJECT="mailto:contact.infotelcom@gmail.com"
```
Ne jamais mettre la clé service-role, le secret webhook ni la clé VAPID privée dans le code du navigateur ou dans GitHub Pages.

Générer une paire VAPID avec un outil Web Push fiable, conserver la clé privée uniquement dans les secrets de la fonction et configurer la clé publique comme variable de build `VITE_VAPID_PUBLIC_KEY` dans l'environnement qui construit le site.

## 3. Relier l'historique de notifications au push

Dans Supabase > Database > Webhooks, créer un webhook sur la table `public.connect_notifications`, événement **INSERT**, URL :
`https://<PROJECT_REF>.supabase.co/functions/v1/send-push`
Ajouter l'en-tête `x-webhook-secret` avec exactement la valeur du secret `PUSH_WEBHOOK_SECRET`. Le webhook envoie le nouvel enregistrement dans le champ `record`.

## 4. Publier et vérifier

Après le déploiement du site, ouvrir Connect sur HTTPS, autoriser les notifications puis choisir « Activer les notifications push » dans le centre de notifications. Sur Android, utiliser un navigateur compatible et accepter l'autorisation. Les notifications push exigent une configuration serveur valide ; l'interface seule ne peut pas envoyer les notifications lorsque le navigateur est fermé.

## Fonctions disponibles dans l'interface

- Réactions 👍 ❤️ 😂 👏 enregistrées par utilisateur.
- Épinglage et désépinglage des messages du canal.
- Réponses en fil de discussion.
- Brouillons locaux séparés par utilisateur et par canal.
- Recherche textuelle dans les messages des canaux accessibles à l'utilisateur.
- Historique de notifications, compteur de non-lues et marquage comme lu.
- Service worker pour afficher les notifications push en arrière-plan.

Les autorisations RLS restent la barrière de sécurité : vérifier aussi les règles d'accès existantes aux tables principales dans le projet Supabase avant mise en production.

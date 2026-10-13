# INFOTELCOM Connect Pro — configuration et vérification des notifications push

Projet Supabase : `xtkcfhbsksoqbpnaciga`

## État confirmé

- La migration des réactions, épingles, fils, notifications et abonnements push a été appliquée.
- La migration d'index de recherche et de temps réel a été appliquée.
- La fonction Edge `send-push` est déployée et active, avec vérification JWT désactivée pour accepter le webhook ; elle vérifie elle-même l'en-tête `x-webhook-secret`.
- Le dernier workflow GitHub Pages vérifié est réussi : [run #58](https://github.com/INFOTELCOM/INFOTELCOM-Connect/actions/runs/38443809906).
- **Les push en arrière-plan ne sont pas confirmés tant que les secrets, le secret GitHub et le webhook ne sont pas configurés puis testés.**

## 1. Créer les clés VAPID et le secret webhook

Sur un ordinateur de confiance, avec Node.js installé, exécuter :
```sh
npx web-push generate-vapid-keys
```
Conserver la clé privée hors du dépôt. Créer aussi un secret webhook aléatoire long (au moins 32 octets). Ne jamais envoyer ces secrets dans le chat, les commits, ni dans le code du navigateur.

## 2. Définir les secrets côté Supabase

Ouvrir le terminal à la racine du dépôt, se connecter avec Supabase CLI, puis lier le projet :
```sh
supabase login
supabase link --project-ref xtkcfhbsksoqbpnaciga
```

Récupérer la clé **service_role** depuis Supabase Dashboard > Project Settings > API (ou API Keys, selon l'interface). C'est un secret serveur : ne pas utiliser la clé anon/publishable à sa place et ne jamais la publier.

Puis enregistrer les valeurs en remplaçant les exemples par les vraies valeurs générées/récupérées :
```sh
supabase secrets set PUSH_WEBHOOK_SECRET="SECRET_ALEATOIRE_LONG"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="CLE_SERVICE_ROLE_DU_PROJET"
supabase secrets set VAPID_PUBLIC_KEY="CLE_PUBLIQUE_VAPID"
supabase secrets set VAPID_PRIVATE_KEY="CLE_PRIVEE_VAPID"
supabase secrets set VAPID_SUBJECT="mailto:contact.infotelcom@gmail.com"
```

Ne pas copier les valeurs d'exemple telles quelles. Les commandes doivent être exécutées localement, dans un terminal privé. La clé publique VAPID doit correspondre exactement à la clé privée.

## 3. Ajouter la clé publique aux secrets GitHub

Dans le dépôt [INFOTELCOM/INFOTELCOM-Connect](https://github.com/INFOTELCOM/INFOTELCOM-Connect) :
1. Ouvrir **Settings > Secrets and variables > Actions**.
2. Cliquer **New repository secret**.
3. Nom : `VITE_VAPID_PUBLIC_KEY`.
4. Valeur : la **même clé publique VAPID** que celle enregistrée dans `VAPID_PUBLIC_KEY` côté Supabase.
5. Enregistrer, puis relancer le workflow [GitHub Actions](https://github.com/INFOTELCOM/INFOTELCOM-Connect/actions) si aucun nouveau commit ne déclenche une compilation.

Seule la clé publique VAPID est autorisée dans le build du navigateur. Ne jamais créer de secret GitHub Pages pour la clé privée ou la clé service-role.

## 4. Créer le webhook Supabase

Dans Supabase Dashboard du projet `xtkcfhbsksoqbpnaciga` :
1. Aller dans **Database > Webhooks** (le libellé peut varier selon la version du tableau de bord).
2. Créer un webhook nommé `connect-notifications-push`.
3. Table : `public.connect_notifications`.
4. Événement : **INSERT** uniquement.
5. Méthode : **POST**.
6. URL : `https://xtkcfhbsksoqbpnaciga.supabase.co/functions/v1/send-push`.
7. Ajouter l'en-tête HTTP `x-webhook-secret` avec exactement la même valeur que `PUSH_WEBHOOK_SECRET`.
8. Enregistrer et vérifier l'historique d'exécution du webhook après un nouvel enregistrement de notification.

Ne pas exposer la valeur du secret dans une capture d'écran ou un dépôt. La fonction attend le nouvel enregistrement dans le champ `record`.

## 5. Tester la chaîne complète

1. Ouvrir Connect via HTTPS et se connecter.
2. Dans le centre de notifications, activer les notifications push et accepter la demande du navigateur.
3. Vérifier que l'abonnement est ajouté dans `connect_push_subscriptions`.
4. Créer une nouvelle notification pour cet utilisateur et vérifier que le webhook répond sans erreur.
5. Tester avec l'application en arrière-plan puis avec l'onglet fermé. Les restrictions du navigateur/Android peuvent affecter le comportement.
6. Consulter les logs de la fonction Edge `send-push` dans Supabase en cas d'échec.

## Fonctions côté interface

- Réactions 👍 ❤️ 😂 👏.
- Épinglage et désépinglage des messages.
- Réponses en fil de discussion.
- Brouillons locaux séparés par utilisateur et par canal.
- Recherche textuelle dans les messages accessibles à l'utilisateur.
- Historique des notifications, compteur de non-lues et marquage comme lu.
- Service worker pour afficher les notifications push en arrière-plan.

Les politiques RLS restent essentielles : vérifier les règles d'accès des tables principales avant la mise en production.

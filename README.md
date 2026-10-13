# INFOTELCOM Connect

Plateforme collaborative React + Vite + Supabase : authentification, espaces, canaux, messages en temps réel, fichiers privés, membres et invitations par lien à usage unique.

## Démarrage
1. Installer Node.js 20+.
2. Copier `.env.example` vers `.env.local` et renseigner l'URL et la clé **publishable/anon** Supabase. Ne jamais mettre la clé `service_role` dans le navigateur.
3. Exécuter `npm install`, puis `npm run dev`.
4. Dans Supabase SQL Editor, exécuter la migration `supabase/migrations/202610130002_connect_collaboration.sql`.
5. Dans Supabase > Authentication > URL Configuration, ajouter l'URL de développement et l'URL de production aux URLs autorisées.

## Invitations
Dans Membres, un propriétaire/administrateur crée une invitation à usage unique et partage le lien généré au destinataire. Le destinataire ouvre le lien, se connecte avec l'adresse invitée et accepte. L'envoi automatique d'e-mails nécessite un fournisseur e-mail configuré dans Supabase Auth.

## À savoir
La V1 contient les canaux, messages, fichiers privés et invitations sécurisées. Les appels vidéo, notifications push et conversations privées ne sont pas inclus. Avant une mise en production, tester avec deux comptes et vérifier les politiques RLS dans Supabase Security Advisor.
## Publication GitHub Pages
Le workflow `.github/workflows/deploy-pages.yml` construit et publie automatiquement le site après chaque push sur `main`. Dans GitHub > Settings > Pages, sélectionner **GitHub Actions** comme source de publication. URL prévue : https://infotelcom.github.io/INFOTELCOM-Connect/

Dans Supabase > Authentication > URL Configuration, définir l'URL du site comme **Site URL** et ajouter `https://infotelcom.github.io/INFOTELCOM-Connect/` dans les **Redirect URLs**. Cette configuration est nécessaire pour la confirmation d'e-mail et le retour après connexion.

La clé `sb_publishable_...` utilisée côté navigateur est une clé publique prévue à cet effet. Ne jamais publier une clé `service_role`, un mot de passe ou un secret serveur.

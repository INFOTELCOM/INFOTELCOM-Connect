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
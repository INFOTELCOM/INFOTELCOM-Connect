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
La V1.2 contient les canaux, messages, fichiers privés, invitations sécurisées et une page de visioconférences. Les réunions sont enregistrées dans `connect_meetings` avec RLS et génèrent un lien Jitsi Meet partageable. Les invités ouvrent directement le lien externe et n'ont pas besoin d'un compte Connect pour rejoindre la salle. La disponibilité, les règles d'accès, les fonctionnalités et les conditions de confidentialité de la salle dépendent du service Jitsi utilisé. Pour un usage professionnel sensible, configurez une instance Jitsi administrée par votre organisation ou un fournisseur avec garanties contractuelles. Avant une mise en production, tester avec deux comptes et vérifier les politiques RLS dans Supabase Security Advisor.
## Publication GitHub Pages
Le workflow `.github/workflows/deploy-pages.yml` construit et publie automatiquement le site après chaque push sur `main`. Dans GitHub > Settings > Pages, sélectionner **GitHub Actions** comme source de publication. URL prévue : https://infotelcom.github.io/INFOTELCOM-Connect/

Dans Supabase > Authentication > URL Configuration, définir l'URL du site comme **Site URL** et ajouter `https://infotelcom.github.io/INFOTELCOM-Connect/` dans les **Redirect URLs**. Cette configuration est nécessaire pour la confirmation d'e-mail et le retour après connexion.

La clé `sb_publishable_...` utilisée côté navigateur est une clé publique prévue à cet effet. Ne jamais publier une clé `service_role`, un mot de passe ou un secret serveur.


## Visioconférences
Dans le menu **Visios**, crée une réunion, donne-lui un nom et éventuellement une date/heure. Connect enregistre la réunion dans Supabase et génère un lien `https://meet.jit.si/...` que tu peux copier et envoyer par e-mail, WhatsApp ou dans un canal. Le bouton **Rejoindre** ouvre la salle dans un nouvel onglet. Le navigateur demandera l'autorisation d'utiliser le micro et la caméra. Supprimer la ligne dans Connect ne désactive pas la salle externe.

La fonction repose sur Jitsi Meet public pour éviter de stocker des flux audio/vidéo sur Supabase. Les flux médias ne passent pas par les tables Supabase. Tester les appels depuis deux appareils/réseaux avant de l'utiliser en réunion réelle.

# Sécurité et exploitation — INFOTELCOM Connect

## Secrets

- Ne jamais placer `SUPABASE_SERVICE_ROLE_KEY`, `PUSH_WEBHOOK_SECRET` ou `VAPID_PRIVATE_KEY` dans le code du navigateur, un fichier `.env` versionné ou les variables `VITE_*`.
- Le frontend peut contenir la clé Supabase publishable/anon. La sécurité des données doit rester assurée par RLS et les fonctions RPC.
- Configurez les secrets du webhook dans **Supabase → Edge Functions → Secrets** : `PUSH_WEBHOOK_SECRET`, `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY` et, si nécessaire, `VAPID_SUBJECT`.
- Le webhook de push attend `x-webhook-secret` et un corps JSON contenant `user_id` (UUID) ou `record.user_id`. Toute modification du secret doit être synchronisée avec le déclencheur qui appelle la fonction.

## Contrôles après déploiement

1. Vérifier que le workflow GitHub Pages termine avec succès.
2. Tester connexion, création de canal, envoi de message, pièce jointe, invitation et déconnexion avec un compte membre.
3. Tester les mêmes opérations avec un compte gestionnaire et un compte administrateur; vérifier qu'un membre ne peut pas gérer les membres ou consulter les journaux d'administration.
4. Vérifier l'isolation entre deux organisations avec deux comptes de test.
5. Vérifier les notifications push avec un appareil abonné; sans secrets VAPID et déclencheur configurés, les notifications en arrière-plan ne sont pas opérationnelles.
6. Contrôler les journaux Supabase après chaque test et ne pas publier de captures contenant des jetons, clés ou données clients.

## Fichiers et réunions

- Les liens signés de stockage sont temporaires. Ne pas enregistrer de lien signé comme URL permanente.
- Les réunions Jitsi accessibles par un nom de salle ne doivent pas être considérées comme confidentielles uniquement parce que le nom est difficile à deviner. Pour les échanges sensibles, utiliser une salle avec contrôle d'accès et vérifier les droits de modération.
- Avant de modifier les règles RLS ou les droits SQL, inspecter les politiques et tester les flux existants sur un environnement de test.

# Confidentialité — Calendrier

Initium peut accéder aux calendriers de l’iPhone uniquement après une action
explicite de l’utilisateur et l’autorisation système correspondante.

Dans ce lot, l’accès est strictement en lecture seule via EventKit :

- les calendriers sélectionnés et leurs événements sont lus localement ;
- les événements servent à afficher la journée, calculer les transitions et
  planifier des rappels locaux ;
- aucune donnée de calendrier n’est envoyée à un serveur ;
- aucune donnée n’est partagée avec des tiers ;
- Initium ne modifie, ne crée et ne supprime aucun événement Apple Calendar.

Les réglages, associations de routines et métadonnées d’exécution restent
stockés localement sur l’appareil.

## Compte et profil

Initium peut utiliser Supabase Auth pour créer et maintenir un compte email +
mot de passe. L’adresse email est stockée par Supabase Auth. Le nom
d’affichage, la langue préférée et l’état de fin d’onboarding sont stockés
dans la table `profiles`, protégée par des règles d’accès personnelles.

La connexion ne constitue pas une synchronisation générale des données. Dans
ce lot, les activités, routines, sessions, insights et événements calendrier
restent dans SwiftData sur l’appareil et ne sont pas envoyés à Supabase.

La déconnexion conserve les données locales. La suppression du compte supprime
l’identité et le profil Supabase ; les données locales restent sur l’appareil
jusqu’à une action distincte et explicite de l’utilisateur.

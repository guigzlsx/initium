# Initium

Initium aide à transformer un planning théorique en journée réellement exécutable.

L’app aide à commencer une tâche, traverser les transitions, préparer un événement à temps, mesurer les durées réelles et réorganiser la journée lorsqu’elle dérive. Elle est pensée pour les difficultés de fonctions exécutives, notamment celles que peuvent rencontrer les personnes avec un TDAH, sans être une application médicale.

## Fonctionnalités

### Today

Timeline locale de la journée avec l’activité actuelle, la prochaine activité et les activités planifiées.

### Now

Exécution d’une activité avec démarrage, pause, reprise, fin et mesure du temps réellement passé. Les étapes d’une routine peuvent être suivies séparément.

### Transitions

Préparation avant un événement fixe :

```text
18:30 Restaurant
↓
Routine « Se préparer »
↓
Initium calcule quand commencer
```

Les durées observées localement servent ensuite à rendre les prochaines transitions plus réalistes.

### Smart Routine Templates

Catalogue de templates de routines fourni par Supabase et embarqué en fallback JSON. Le cache local est prioritaire, puis le catalogue distant est rafraîchi en arrière-plan.

Le matching est local, déterministe et basé sur le titre, le lieu, la normalisation casse/accents et un score minimal. Aucun titre d’événement n’est envoyé à Supabase pour effectuer ce matching et aucune IA n’est utilisée.

### Calendar Integration

Intégration EventKit en lecture seule. Les événements sélectionnés sont importés localement comme contraintes, sans écriture dans Apple Calendar.

### Reset My Day / Replan

Réorganisation déterministe des activités restantes, en conservant les activités fixes et en signalant les conflits lorsqu’un créneau ne suffit plus.

### Insights

Comparaison des durées estimées et réelles, suivi des délais de démarrage et calibration locale à partir des sessions terminées.

### Auth / Profile

Création de compte et connexion email/mot de passe avec Supabase Auth, persistance de session dans le Keychain et profil utilisateur dans Supabase. Le flow ne dépend pas d’une validation email obligatoire.

Le parcours d’entrée est actuellement :

```text
Welcome → Onboarding → Value Summary → Paywall placeholder → Auth → Main App
```

## Principes produit

- **Local-first** : les données métier et l’exécution restent disponibles localement.
- **Privacy-first** : les événements calendrier et les données d’usage restent sur l’appareil.
- **Pas d’IA générative** : pas de LLM, d’embeddings ou de base vectorielle dans le projet.
- **Pas de backend calendrier** : EventKit est utilisé localement et en lecture seule.
- **Supabase ciblé** : Auth, profils et catalogue public de templates uniquement.

## Stack

- Swift 5
- SwiftUI
- SwiftData
- EventKit
- UserNotifications
- Supabase Auth et PostgREST via `URLSession` ; aucune dépendance Swift Package Supabase n’est actuellement déclarée
- XCTest
- iOS deployment target : 17.0
- Xcode utilisé pour la validation actuelle : 26.1.1

## Architecture

```text
SwiftUI Views
    ↓
ViewModels
    ↓
Domain / Services
    ↓
SwiftData / EventKit / Supabase REST / UserNotifications
```

Les principaux composants sont :

- `TransitionPlanner` : calcule le début d’une transition.
- `ScheduleReplanner` : produit une proposition de réorganisation et ses conflits.
- `DurationEstimator` et `RoutineCalibration` : estiment les durées à partir de l’historique local.
- `InsightsCalculator` : construit les indicateurs de calibration et de replanification.
- `ActivityExecutionService` : gère les sessions d’activité et de routine.
- `TransitionExecutionService` : exécute les étapes d’une transition.
- `CalendarIntegrationService` et `CalendarSyncService` : lisent EventKit et synchronisent les activités locales importées.
- `LocalNotificationScheduler` : planifie les rappels locaux de transition.
- `RoutineTemplateRepository` : charge le cache, le fallback JSON et le catalogue Supabase.
- `RoutineTemplateMatcher` : effectue le matching local déterministe.
- `RoutineTemplateApplicationService` : transforme un template en routine SwiftData locale.
- `AuthenticationService` : gère la session, Auth, le profil, le reset de mot de passe et la suppression de compte.

## Données et propriété

| Système | Données | Comportement |
| --- | --- | --- |
| SwiftData | `Activity`, `Routine`, `RoutineStep`, `ActivitySession`, `RoutineSession`, historique et calibration | Données métier principales, locales à l’appareil |
| Supabase Auth | Identité et email | Session distante persistée dans le Keychain |
| Supabase `profiles` | Nom d’affichage, langue préférée, état d’onboarding | Accès isolé au profil de l’utilisateur connecté |
| Supabase catalogue | Catégories, templates, étapes et mots-clés | Lecture publique des lignes actives, sans écriture depuis l’app cliente |
| EventKit | Événements et calendriers externes | Lecture locale uniquement |

La connexion à Initium ne constitue pas encore une synchronisation cloud des activités, routines, sessions ou insights.

## Configuration Supabase

Le projet Supabase utilisé par Initium est `ffgqokjkxqloepyevbct` :

```text
https://ffgqokjkxqloepyevbct.supabase.co
```

La configuration client est injectée dans les build settings Xcode et lue depuis `Info.plist` :

```text
SUPABASE_URL=https://ffgqokjkxqloepyevbct.supabase.co
SUPABASE_ANON_KEY=<clé client publique>
```

`SUPABASE_ANON_KEY` est le nom de configuration conservé par le projet. Il peut recevoir la clé publishable/client publique Supabase utilisée par l’environnement courant.

Ne jamais committer de clé réelle et ne jamais utiliser de `service_role` key dans l’application. Les variables doivent être fournies par une configuration de build locale ou par les secrets de CI.

### Schéma distant

- `profiles` : profil propre à l’utilisateur, créé automatiquement par un trigger à la création de `auth.users`.
- `routine_template_categories`
- `routine_templates`
- `routine_template_steps`
- `routine_template_keywords`

Les quatre tables du catalogue sont en lecture seule pour les rôles clients `anon` et `authenticated`, avec RLS et filtrage des lignes actives. La table `profiles` est limitée à `auth.uid() = id`.

Les migrations locales se trouvent dans `supabase/migrations/` :

- `20261006_create_routine_template_catalog.sql` : tables, relations, index, RLS et policies du catalogue.
- `20261007_create_profiles_and_auth_support.sql` : `profiles`, trigger de création, policies et RPC de suppression du compte courant.
- `20261007_harden_profile_trigger_permissions.sql` : restriction des permissions des fonctions de profil.

Le seed du catalogue se trouve dans `supabase/seed/routine_templates.sql`. Le fallback embarqué est `Initium/Resources/routine_templates_seed.json`.

## Démarrage

Prérequis :

- macOS avec Xcode installé ;
- Xcode compatible avec le deployment target iOS 17.0 ;
- un Simulator iOS ou un appareil iOS ;
- une configuration Supabase publique si Auth et le refresh distant sont nécessaires.

Depuis la racine du dépôt :

```bash
open Initium.xcodeproj
```

Dans Xcode :

1. sélectionner le scheme `Initium` ;
2. sélectionner la target `Initium` ;
3. choisir un Simulator ou un appareil iOS ;
4. fournir `SUPABASE_URL` et `SUPABASE_ANON_KEY` dans la configuration de build si les services Supabase sont utilisés ;
5. lancer l’application.

La target principale est `Initium`, la target de tests est `InitiumTests`. Les configurations disponibles sont `Debug` et `Release`.

## Build et tests

Lister les destinations disponibles :

```bash
xcodebuild \
  -project Initium.xcodeproj \
  -scheme Initium \
  -showdestinations
```

Exemple de build Debug sans signature, avec le Simulator utilisé lors de la validation locale :

```bash
xcodebuild \
  -project Initium.xcodeproj \
  -scheme Initium \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Build Release :

```bash
xcodebuild \
  -project Initium.xcodeproj \
  -scheme Initium \
  -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Suite XCTest :

```bash
xcodebuild \
  -project Initium.xcodeproj \
  -scheme Initium \
  -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.1' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Si cette destination n’est pas installée localement, utiliser une destination retournée par `-showdestinations`. Le dépôt contient actuellement 20 fichiers de tests et 117 méthodes de test.

Vérification de format Git :

```bash
git diff --check
```

## Schéma SwiftData

Le schéma actif est `InitiumSchemaV3`, défini dans `Initium/App/PersistenceController.swift`.

- `InitiumSchemaV1` : modèle initial avec activités, routines, étapes et sessions.
- `InitiumSchemaV2` : version intermédiaire du schéma.
- `InitiumSchemaV3` : version active actuelle.

La migration plan utilise la migration légère intégrée de SwiftData pour les champs optionnels ou dotés de valeurs par défaut. Les modèles persistés sont `Activity`, `ActivitySession`, `Routine`, `RoutineStep` et `RoutineSession`.

## Calendrier et notifications

EventKit nécessite l’autorisation Calendrier du système. La permission est demandée depuis Settings, après une explication à l’utilisateur, et les calendriers à synchroniser peuvent être sélectionnés.

Le mode Calendrier est facultatif : l’application reste utilisable sans calendrier connecté. Les événements sont lus localement, transformés en activités locales et ne sont ni créés, ni modifiés, ni supprimés par Initium.

Les notifications de transition sont locales et utilisent `UserNotifications`. Leur autorisation est également demandée uniquement lorsqu’un rappel est nécessaire.

## Confidentialité

Les titres et lieux des événements calendrier peuvent être utilisés localement par le matching des templates. Ils ne sont pas envoyés à Supabase pour produire une suggestion.

Les activités, routines, sessions, insights, historique et calibration restent dans SwiftData sur l’appareil. Supabase stocke l’identité Auth, le profil et le catalogue public de templates. La politique détaillée est documentée dans [PRIVACY.md](PRIVACY.md).

## Design et accessibilité

La direction visuelle est sombre, premium et centrée sur des cartes lisibles, avec un mode clair disponible dans Settings. Le projet contient des libellés VoiceOver, des tailles typographiques SwiftUI/`@ScaledMetric` et une prise en compte de Reduce Motion. Les parcours principaux sont localisés en français et en anglais.

## Structure du projet

```text
Initium/
├── App/
│   ├── AppState.swift
│   ├── AppTheme.swift
│   └── PersistenceController.swift
├── Data/
│   ├── Models/
│   └── Services/
├── Domain/
├── Features/
│   ├── Account/
│   ├── Calendar/
│   ├── EntryFlow/
│   ├── Insights/
│   ├── Now/
│   ├── Onboarding/
│   ├── Replan/
│   ├── Routines/
│   ├── Settings/
│   ├── Today/
│   └── Welcome/
├── Resources/
└── SharedUI/

InitiumTests/
supabase/
├── migrations/
└── seed/

promo-site/
```

## Limitations actuelles

- Les données métier SwiftData ne sont pas synchronisées entre appareils.
- EventKit reste en lecture seule.
- Le matching des templates est déterministe et local, sans IA.
- L’authentification sociale, notamment Sign in with Apple et Google, n’est pas implémentée.
- Le paywall présent dans le flow d’entrée est encore un placeholder ; aucune synchronisation d’abonnement n’est décrite dans ce dépôt.
- Le site vitrine est un dossier statique indépendant dans `promo-site/`.

## Validation et distribution

Le fichier [TESTFLIGHT_CHECKLIST.md](TESTFLIGHT_CHECKLIST.md) contient la checklist de validation d’archive et de distribution TestFlight, notamment la signature, le bundle ID `com.guillaumelsx.initium`, les tests, les parcours principaux, les modes clair/sombre et l’accessibilité.

# Nekix ChopShop

Job de casse automobile pour FiveM : volez un véhicule, conduisez-le à la casse, démontez-le et revendez les pièces. Fonctionne avec ESX, QBCore et Qbox. Toutes les décisions (job, véhicule, pièces, butin, paiement, XP) sont prises par le serveur.

**Documentation dans d'autres langues :** [English](../../README.md) | [Español](README.es.md) | [Português (Brasil)](README.pt-br.md) | Français | [Deutsch](README.de.md)

## Fonctionnalités

- **Frameworks :** ESX, QBCore et Qbox, détectés automatiquement (`Config.Framework = 'auto'`).
- **Inventaires :** ox_inventory, qs-inventory, core_inventory, ps-inventory et qb-inventory, détectés automatiquement, plus un adaptateur `custom` pour tout autre inventaire.
- **Jobs sous l'autorité du serveur :** le serveur choisit le véhicule, le fait apparaître, valide les distances, les délais et le crochetage, et décide de toutes les récompenses. Un client modifié ne peut se donner ni objets, ni argent, ni XP.
- **Catégories de véhicules et butin :** véhicules de catégorie basse, moyenne et haute, chacune avec son paiement, sa qualité d'objet et sa table de butin.
- **Réputation :** XP et niveaux par personnage (oxmysql) qui débloquent des catégories de véhicules et des avantages.
- **Plus de pièces :** portes, capot, coffre, moteur, sièges avant et roues, avec un ordre « retirer ceci d'abord » imposé par le serveur.
- **Police :** minimum d'agents en service et alerte de dispatch avec 9 scripts pris en charge plus `custom`.
- **Clés de véhicule :** le propriétaire du job reçoit les clés du véhicule après le crochetage, avec 7 scripts pris en charge plus `custom`.
- **Système de partenaire :** le propriétaire peut inviter un partenaire avant le démontage ; le partenaire partage le travail et une part de l'XP.
- **Limites de temps :** minuteurs de récupération et de démontage ; un job expiré est annulé et son emplacement de casse est libéré.
- **Délai d'attente persistant :** stocké dans le KVP de la ressource (sans SQL), par personnage et par licence, avec une commande de réinitialisation pour les administrateurs.
- **NUI de bon de travail :** tableau des jobs, fiche de job avec notes, notes volantes, invitation de partenaire et acheteur de pièces. Peut être désactivée.
- **10 langues** via les locales d'ox_lib : en, es, fr, de, it, pt-br, pl, nl, tr, cs.
- **Logs Discord** et vérificateur de version.

## Prérequis

| Ressource | Remarques |
| :--- | :--- |
| [ox_lib](https://github.com/overextended/ox_lib) | requis |
| [ox_target](https://github.com/overextended/ox_target) | requis |
| [oxmysql](https://github.com/overextended/oxmysql) | requis (dépendance du manifest). Avec `Config.Reputation.Enabled = false`, aucun SQL n'est exécuté |
| OneSync | requis (le serveur fait apparaître les véhicules) |
| `qbx_core`, `es_extended` ou `qb-core` | l'un d'entre eux |
| Un inventaire | `ox_inventory`, `qs-inventory`, `core_inventory`, `ps-inventory`, `qb-inventory` ou un adaptateur custom |

Facultatif : un script de clés de véhicule et un script de dispatch de police (voir « Clés de véhicule » et « Police et dispatch »).

## Installation

1. **Téléchargez** la ressource et placez le dossier dans votre répertoire de ressources. Gardez le nom de dossier `nek_chopshop` : les exports l'utilisent (`exports.nek_chopshop`).
2. **Ajoutez les objets** à votre inventaire. Ouvrez le guide de votre inventaire, copiez le bloc et redémarrez l'inventaire :

   | Inventaire | Guide |
   | :--- | :--- |
   | ox_inventory | [docs/items/ox_inventory.md](../items/ox_inventory.md) |
   | qb-inventory | [docs/items/qb-inventory.md](../items/qb-inventory.md) |
   | ps-inventory | [docs/items/ps-inventory.md](../items/ps-inventory.md) |
   | qs-inventory | [docs/items/qs-inventory.md](../items/qs-inventory.md) |
   | core_inventory | [docs/items/core_inventory.md](../items/core_inventory.md) |
   | tout autre | [docs/items/custom.md](../items/custom.md) |

3. **Copiez les images des objets** du dossier `[assets]` vers le répertoire d'images de votre inventaire (`ox_inventory/web/images/`, `qb-inventory/html/images/`, ... ; chaque guide indique le dossier). Chaque image porte le nom de son objet.
4. **Ajoutez la ressource à `server.cfg`**, après ses dépendances :

   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure oxmysql
   ensure qbx_core            # ou es_extended / qb-core
   ensure ox_inventory        # ou votre inventaire
   ensure qbx_vehiclekeys     # facultatif : votre script de clés
   ensure ps-dispatch         # facultatif : votre script de dispatch
   ensure nek_chopshop
   ```

5. **Base de données :** rien à importer. La table `nek_chopshop_reputation` est créée au premier démarrage.
6. **Configuration :** laissez `Config.Framework = 'auto'` et `Config.Inventory = 'auto'` sauf si vous devez en forcer un. Passez en revue [`shared/config.lua`](../../shared/config.lua).
7. **Langue (facultatif) :** ajoutez `setr ox:locale "fr"` à `server.cfg` (voir « Langues »).
8. **Démarrez le serveur** et regardez la console : elle affiche le framework et l'inventaire trouvés, et signale tout objet non enregistré.

## Déroulement d'un job

1. Le joueur demande un job au ped (option de target ou tableau des jobs). Le serveur vérifie le délai d'attente, les policiers en service, la catégorie selon la réputation et un emplacement de casse libre, puis fait apparaître le véhicule et le marque sur la carte.
2. Le joueur crochète le véhicule (il faut un objet de `Config.LockpickItems` et réussir le mini-jeu). Le serveur donne les clés et envoie l'alerte à la police.
3. Le joueur le conduit jusqu'à la casse.
4. À la casse, le joueur peut inviter un partenaire, puis commence le démontage.
5. Chaque pièce retirée va dans l'inventaire. Quand il ne reste plus de pièces, le propriétaire reçoit `Config.FinishReward` et, si activé, de l'argent. Le véhicule est détruit.
6. Le joueur vend les pièces au ped de vente.

## Aperçu de la configuration

Toutes les options sont dans [`shared/config.lua`](../../shared/config.lua), chacune avec un commentaire. Regroupées par domaine :

### Général

| Option | Description |
| :--- | :--- |
| `Config.Framework` | `'auto'` (par défaut), `'esx'`, `'qbcore'` ou `'qbox'`. Ordre en auto : `qbx_core` > `es_extended` > `qb-core`. Un framework forcé qui n'est pas démarré bascule sur la détection automatique. |
| `Config.Inventory` | `'auto'` (par défaut), `'ox_inventory'`, `'qs-inventory'`, `'core_inventory'`, `'ps-inventory'`, `'qb-inventory'` ou `'custom'`. Voir « Inventaire ». |
| `Config.LockpickItems` | Objets permettant de crocheter le véhicule du job (un seul suffit). Par défaut `lockpick`, `advancedlockpick`, `advanced_lockpick`. |
| `Config.UseNUI` | `true` utilise la NUI ; `false` se rabat sur les menus et notifications d'ox_lib. |
| `Config.Debug` | Messages de débogage. |
| `Config.AdminAce` | ACE autorisé à utiliser la commande d'administration. Voir « Administration ». |

### Jobs, récompenses et temps

| Option | Description |
| :--- | :--- |
| `Config.Cooldown` | Secondes entre deux jobs (par défaut 3600). Les avantages de réputation peuvent le raccourcir. |
| `Config.TimeLimit` | `Pickup` et `Scrap`, en minutes (par défaut 20 et 10). Pickup court de l'acceptation du job jusqu'au début du démontage ; Scrap, du début jusqu'au retrait de toutes les pièces. Un job qui dépasse l'un des deux est annulé. |
| `Config.Payment` | `Enable`, `Min`, `Max` : argent facultatif par job (désactivé par défaut). Multiplié par le `payout` de la catégorie. |
| `Config.FinishReward` | Objet donné au propriétaire quand toutes les pièces sont retirées (par défaut `veh_suspension`), ou `false`. |
| `Config.ChopParts` | Pièces qui peuvent être retirées. C'est la liste blanche des récompenses : le serveur ne récompense que les pièces listées ici. Voir « Pièces ». |
| `Config.Coords` | `Spawns` (points d'apparition des véhicules) et `Scrap` (emplacements de la casse). |
| `Config.Tiers` | Catégories de véhicules. Voir « Catégories de véhicules et butin ». |
| `Config.Reputation` | XP, niveaux, avantages, dégradation. Voir « Réputation ». |

### Peds et vente

| Option | Description |
| :--- | :--- |
| `Config.Ped` | Ped du job : `Model`, `Coords`, `Scenario`, `Target` (options d'ox_target), `Blip`. |
| `Config.SellPed` | Ped de vente : `Enable`, `Model`, `Coords`, `Scenario`, `Items` (objet, prix de base, libellé), `QualityMultiplier`, `Blip`. |

Les libellés (`label`, `Label` du blip, `label` du target) acceptent une clé de locale ; un texte littéral fonctionne aussi.

### Police et clés de véhicule

| Option | Description |
| :--- | :--- |
| `Config.Police` | `MinOnDuty`, `JobType`, `Jobs`, `Dispatch`. Voir « Police et dispatch ». |
| `Config.VehicleKeys` | `System`, `RemoveOnEnd`. Voir « Clés de véhicule ». |

### Sécurité (anti-exploit)

`Config.Security` contient les seuils côté serveur (distances en mètres, durées en millisecondes) :

| Option | Par défaut | Description |
| :--- | :--- | :--- |
| `PedDistance` | 10.0 | Distance maximale au ped du job pour demander un job. |
| `SellDistance` | 10.0 | Distance maximale au ped de vente pour vendre. |
| `ScrapDistance` | 15.0 | Distance maximale entre le véhicule et le point de casse pour commencer le démontage. |
| `PartDistance` | 6.0 | Distance maximale entre le joueur et le véhicule pour retirer une pièce. |
| `PartnerDistance` | 20.0 | Distance maximale entre propriétaire et partenaire lors de l'attribution. |
| `PartInterval` | 2000 | Durée minimale entre deux retraits de pièce par le même joueur. |
| `SpawnClearRadius` | 3.0 | Un point d'apparition est ignoré si un véhicule se trouve dans ce rayon. |
| `MaxAverageSpeed` | 60.0 | m/s. Une livraison du point d'apparition à la casse plus rapide que cela est traitée comme une téléportation et rejetée. |
| `WarnThrottle` | 30 | Secondes entre deux logs de requêtes suspectes pour le même joueur. |
| `DispatchDistance` | 10.0 | Distance maximale au véhicule du job quand le rapport de crochetage arrive. |

### Logs

| Option | Description |
| :--- | :--- |
| `Config.Discord` | `Username`, `AvatarUrl`, `Color` des embeds. L'URL du webhook n'est **pas** ici : définissez `Editable.Webhook` dans `editable/server.lua`. |
| `Config.Logs` | `EnableItem`, `EnablePay`, `EnableFinish`, `EnableWarn`, `EnableReputation`, `Compact`. |

Les logs Discord utilisent la langue du serveur.

## Inventaire

`Config.Inventory = 'auto'` utilise le premier inventaire démarré de cette liste :

| # | Ressource | Frameworks | Remarques |
| :--- | :--- | :--- | :--- |
| 1 | `ox_inventory` | ESX, QBCore, Qbox | Prise en charge complète. |
| 2 | `qs-inventory` | ESX, QBCore, Qbox | Écrit d'après la documentation de l'éditeur. |
| 3 | `core_inventory` | ESX, QBCore, Qbox | Écrit d'après la documentation de l'éditeur ; la vente par qualité est dégradée. |
| 4 | `ps-inventory` | QBCore | Le contrôle de place est une estimation ; la vente par qualité est dégradée. |
| 5 | `qb-inventory` | QBCore | La vente par qualité est dégradée. |

- **Démarrage tardif :** si aucun inventaire n'est lancé au démarrage de la ressource, elle attend et en choisit un dès qu'une ressource de la liste démarre. Démarrez quand même votre inventaire avant nek_chopshop.
- **En forcer un :** indiquez le nom de la ressource. S'il n'est pas démarré, un avertissement est affiché dans la console et la détection automatique est utilisée.
- **Tout autre inventaire :** `Config.Inventory = 'custom'` et remplissez `Editable.Inventory` dans `editable/server.lua`. Voir [docs/items/custom.md](../items/custom.md).
- **Métadonnées de qualité :** ox_inventory stocke la qualité de la catégorie dans `metadata.quality` ; les autres inventaires utilisent `chopQuality`.
- Les limitations connues de chaque inventaire figurent à la fin de son guide d'objets.

## Police et dispatch

### Minimum de policiers en service

`Config.Police.MinOnDuty` est le nombre d'agents devant être en service pour distribuer un job (`0` le désactive). La demande est refusée côté serveur et le tableau affiche « Not enough police on duty » (texte selon la langue).

- **Qbox / QBCore :** compte les joueurs en service dont le type de job est `Config.Police.JobType` (par défaut `'leo'`). Avec `JobType = false`, ce sont les noms de job de `Config.Police.Jobs` qui sont comptés.
- **ESX :** compte les joueurs ayant un job de `Config.Police.Jobs` dont `job.onDuty` n'est pas `false` (un ESX ancien sans service compte tous les membres du job).
- Une catégorie peut ajouter `minPolice` ; l'exigence effective est la plus élevée des deux.

### Alerte

Une alerte par job, envoyée par le serveur (depuis son balayage des jobs, ou à la livraison du véhicule) afin qu'un client modifié ne puisse pas la contourner. Le client du voleur peut la déclencher plus tôt, juste après le crochetage ; le serveur vérifie que l'appelant est le propriétaire du job, qu'il est à l'étape de récupération, qu'il se trouve près du véhicule (`Config.Security.DispatchDistance`) et qu'il n'a pas encore alerté. Position, plaque et modèle viennent toujours du serveur.

`Config.Police.Dispatch.System` :

| Valeur | Comportement |
| :--- | :--- |
| `'auto'` | Premier script démarré de la liste ci-dessous. |
| un nom de script | Force ce script. |
| `'custom'` | Appelle votre propre code (voir plus bas). |
| `false` | Aucune alerte. |

Scripts pris en charge, dans l'ordre de détection automatique :

| # | Ressource | S'exécute côté |
| :--- | :--- | :--- |
| 1 | `ps-dispatch` | client |
| 2 | `cd_dispatch` | client |
| 3 | `qs-dispatch` | client |
| 4 | `rcore_dispatch` | client |
| 5 | `core_dispatch` | serveur |
| 6 | `tk_dispatch` | client |
| 7 | `origen_police` | client |
| 8 | `lb-tablet` | serveur |
| 9 | `linden_outlawalert` | client |

Autres options de `Config.Police.Dispatch` : `Code` (code radio, par défaut `10-35`), `CodeName` (ps-dispatch uniquement), `Title` et `Message` (clés de locale `dispatch_title` / `dispatch_message` ; le message reçoit le modèle et la plaque) et `Blip` (`Sprite`, `Color`, `Scale`, `Time` en secondes).

**Custom :** définissez `System = 'custom'` et remplissez `Editable.Client.DispatchAlert(data)` (`editable/client.lua`) et/ou `Editable.Server.DispatchAlert(data, source)` (`editable/server.lua`). `data` vaut `{ coords, plate, model, code, title, message, jobs, jobType }` ; la version client reçoit aussi `modelLabel` et `vehicle` (entité).

## Clés de véhicule

Les scripts de clés (par exemple `qbx_vehiclekeys`) ne laissent pas démarrer un véhicule dont on n'a pas les clés. Après un crochetage réussi, le serveur donne au propriétaire les clés du véhicule du job, une fois par job et seulement s'il possède un objet de crochetage. Les partenaires ne reçoivent jamais de clés.

`Config.VehicleKeys` :

| Option | Comportement |
| :--- | :--- |
| `System = 'auto'` | Premier script démarré de la liste ci-dessous. |
| `System = '<resource>'` | Force ce script (aucune clé s'il n'est pas démarré). |
| `System = 'custom'` | Appelle `Editable.Server.GiveVehicleKeys(src, vehicle, plate, model)` et `Editable.Server.RemoveVehicleKeys(...)` dans `editable/server.lua`. |
| `System = false` | Aucune clé n'est donnée (ESX sans script de clés, par exemple). |
| `RemoveOnEnd = true` | Retire les clés à la fin du job, avant la suppression du véhicule. |

Scripts pris en charge, dans l'ordre de détection automatique : `qbx_vehiclekeys`, `qs-vehiclekeys`, `wasabi_carlock`, `MrNewbVehicleKeys`, `ak47_vehiclekeys`, `vehicles_keys`, `qb-vehiclekeys`.

Non intégrés (utilisez `'custom'`) : Renewed-Vehiclekeys, clés de cd_garage, t1ger_keys, okokGarage / okokVehicleKeys.

## Catégories de véhicules et butin

Le serveur choisit le véhicule. `Config.Tiers` regroupe les modèles en catégories (`low`, `mid`, `high` par défaut) :

| Champ | Description |
| :--- | :--- |
| `label` | Clé de locale (ou texte) affichée au début du job. |
| `weight` | Probabilité relative de la catégorie parmi celles auxquelles le joueur peut prétendre. |
| `minLevel` | Niveau de réputation requis. Ignoré quand la réputation est désactivée. |
| `minPolice` | Facultatif. Agents en service requis pour cette catégorie. |
| `payout` | Multiplicateur du paiement final (`Config.Payment`). |
| `quality` | Qualité donnée aux objets de pièce de cette catégorie : `standard`, `premium` ou `exotic`. Les objets de qualités différentes ne s'empilent pas. |
| `models` | Noms de modèles de véhicules ; l'un d'eux est tiré au hasard. |
| `loot` | Tirages supplémentaires pour chaque pièce retirée : `{ item, chance (0-100), min, max, parts = { bones }, quality = true }`. |

- La catégorie, le modèle et le butin sont tirés côté serveur.
- Avant de retirer une pièce, le serveur vérifie que la pièce, ses objets bonus et tout le butin tiennent en même temps. Sinon, rien n'est donné et la pièce reste sur la voiture.
- **Vente :** le ped de vente paie `price x QualityMultiplier[quality] x sellMultiplier de la réputation` pour chaque pile. Valeurs par défaut de `Config.SellPed.QualityMultiplier` : standard 1.0, premium 1.5, exotic 2.5.
- Les objets uniquement obtenus en butin (`scrap_metal`, `sport_wheel`, `turbo_kit`) doivent être enregistrés dans votre inventaire et figurer dans `Config.SellPed.Items` pour pouvoir être vendus.
- Une configuration qui contient encore l'ancienne liste plate `Config.Vehicles` et pas de `Config.Tiers` continue de fonctionner comme une seule catégorie `low`.

## Réputation

Enregistrée par personnage dans la table oxmysql `nek_chopshop_reputation` (`identifier`, `xp`, `jobs`, `last_job`), créée automatiquement. `identifier` est l'identifiant de personnage du framework (`identifier` pour ESX, `citizenid` pour QBCore/Qbox).

- **Gain d'XP (serveur uniquement) :** un job terminé donne au propriétaire `Base + PerPart x pièces retirées + TimeBonusMax x (fraction du temps de démontage restant)`. Le partenaire reçoit `PartnerShare` (0-1) de ce montant. Un job hors délai ou dont le véhicule est perdu coûte `PenaltyExpired` au propriétaire ; quitter le serveur avec un job actif coûte `PenaltyAbandoned`. L'XP ne descend jamais sous 0.
- **Niveaux** (`Config.Reputation.Levels`) : la première entrée est le niveau 0 (`xp = 0`). Chaque niveau liste ses propres avantages :

| Avantage | Effet |
| :--- | :--- |
| `sellMultiplier` | Multiplie le prix du ped de vente (en plus du multiplicateur de qualité). |
| `cooldownMultiplier` | Multiplie `Config.Cooldown` à la prise d'un job (0-1). |
| `extraPartChance` | Probabilité (0-100) d'obtenir un exemplaire supplémentaire de chaque pièce retirée. |
| catégories de véhicules | Débloquées via `Config.Tiers[].minLevel` (par défaut : moyenne au niveau 2, haute au niveau 4). |

- **Dégradation** (`Config.Reputation.Decay`, désactivée par défaut) : chaque semaine complète sans job terminé retire `PerWeek` d'XP. Calculée à la lecture de la réputation ; il n'y a pas de minuteur.
- **Désactivée** (`Enabled = false`) : pas d'XP, pas d'avantages, toutes les catégories disponibles, pas de SQL.
- Le tableau affiche le niveau et la progression ; un passage de niveau envoie une notification et, avec `Config.Logs.EnableReputation`, un log Discord.

## Pièces

Entrées de `Config.ChopParts` : `bone`, `part` (index de porte ou de roue), `item`, `label` (clé de locale), `isDoor` / `isWheel`, `bonus` (objets supplémentaires), `anim` (`'repair'` pour l'animation sous le capot), `optional` et `requires`.

- Pièces par défaut : 4 portes, capot (donne `car-battery`), coffre, moteur (nécessite d'avoir retiré le capot), 2 sièges avant (nécessitent d'avoir retiré leur porte) et 4 roues.
- Seules les 4 roues sont obligatoires. Toutes les autres pièces sont facultatives : elles font partie du job uniquement si le modèle du véhicule possède cet os, de sorte qu'un modèle sans un os ne rend jamais le job impossible à terminer.
- `requires` est appliqué côté serveur. Si la pièce requise ne fait pas partie du job, l'exigence est considérée comme satisfaite.

## Langues

Tous les textes visibles par le joueur se trouvent dans `locales/<lang>.json`, chargés avec le module de locale d'ox_lib.

Incluses : anglais (`en`), espagnol (`es`), français (`fr`), allemand (`de`), italien (`it`), portugais du Brésil (`pt-br`), polonais (`pl`), néerlandais (`nl`), turc (`tr`) et tchèque (`cs`).

- **Changer de langue :** ajoutez `setr ox:locale "fr"` à `server.cfg` (par défaut `en`). Les joueurs peuvent aussi choisir une langue dans le menu de paramètres d'ox_lib ; la NUI se met à jour quand ils le font.
- **Repli :** une clé manquante retombe sur l'anglais ; un fichier manquant retombe sur l'anglais.
- **Ajouter une langue :** copiez `locales/en.json` vers `locales/<code>.json` (même code que dans `ox_lib/locales`, par exemple `ru`, `zh-cn`), traduisez les valeurs et conservez les clés. Gardez `%s` / `%d` dans le même ordre et les `{placeholders}` de la section `nui` inchangés. N'utilisez pas `${...}` dans les textes.
- Ne modifiez pas `ChopLocale` / `LoadChopLocale` dans la configuration.

## Administration

| Commande | Description |
| :--- | :--- |
| `chopshop_resetcd all` | Efface le délai d'attente de job de tous les personnages et licences. |
| `chopshop_resetcd <player id>` | Efface le délai d'attente d'un joueur connecté (personnage actuel et licence). |
| `chopshopui` | Commande joueur : ferme toutes les vues de la NUI et libère le focus de la souris si une erreur de page le laisse bloqué. |

Les délais d'attente sont stockés dans le stockage KVP de cette ressource (le dossier `db/` du serveur), pas dans MySQL.

`Config.AdminAce` (par défaut `'admin'`) :

- Les joueurs ayant cet ACE peuvent exécuter `chopshop_resetcd` en jeu (l'ACE `command.chopshop_resetcd` fonctionne aussi). La console du serveur peut toujours l'exécuter.
- Les joueurs ayant cet ACE ignorent le contrôle anti-téléportation de la livraison, afin que le staff puisse tester avec des téléportations.

```cfg
add_ace group.admin admin allow
```

## Exports

Utilisez le nom du dossier de la ressource dans `exports[...]`.

### Client

```lua
-- Renvoie { active = boolean, pedCoords = vector4 }
-- active : le joueur local a un job de casse actif. pedCoords : Config.Ped.Coords.
local status = exports.nek_chopshop:GetJobStatus()
if status.active then
    print('Working on a chop job')
end
```

### Serveur

```lua
-- GetReputation(identifier: string) -> { xp = number, level = number, jobs = number } | nil
-- nil quand la réputation est désactivée, que l'identifiant est invalide ou que la base de données n'a pas pu être lue.
-- Peut attendre la base de données la première fois qu'un identifiant est lu : appelez-le depuis un thread.
CreateThread(function()
    local rep = exports.nek_chopshop:GetReputation(citizenid)
    if rep then print(rep.xp, rep.level, rep.jobs) end
end)

-- AddReputation(identifier: string, amount: number, reason?: string) -> boolean
-- amount : non nul ; positif ajoute et négatif retire (les fractions sont tronquées, maximum 1000000).
-- reason : texte pour le log (coupé à 100 caractères, par défaut 'export').
-- Enregistré de façon asynchrone, affiché dans la console et journalisé sur Discord (Config.Logs.EnableReputation).
-- Renvoie false pour un identifiant ou un montant invalide, quand la réputation est désactivée ou quand la
-- ligne n'a pas pu être lue (la modification est alors mise en file d'attente et appliquée une fois à la prochaine lecture réussie).
-- Peut attendre la base de données la première fois qu'un identifiant est utilisé : appelez-le depuis un thread.
CreateThread(function()
    exports.nek_chopshop:AddReputation(citizenid, 50, 'event reward')
    exports.nek_chopshop:AddReputation(citizenid, -25, 'admin correction')
end)
```

## Fonctions modifiables

Ces fichiers sont faits pour être modifiés :

| Fichier | Fonction | Rôle |
| :--- | :--- | :--- |
| `editable/server.lua` | `Editable.Webhook` | URL du webhook Discord. |
| `editable/server.lua` | `Editable.Server.SendDiscordLog(title, description, color)` | Envoi de logs personnalisé. |
| `editable/server.lua` | `Editable.Server.CustomReward(source)` | Récompense supplémentaire à la fin d'un job (crypto, XP, objets...). |
| `editable/server.lua` | `Editable.Server.DispatchAlert(data, source)` | Dispatch personnalisé (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Server.GiveVehicleKeys` / `RemoveVehicleKeys` | Clés personnalisées (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Inventory` | Adaptateur d'inventaire personnalisé (`Config.Inventory = 'custom'`). |
| `editable/client.lua` | `Editable.Client.MiniGame()` | Mini-jeu de crochetage ; renvoyez `true` en cas de réussite. Par défaut `lib.skillCheck`. |
| `editable/client.lua` | `Editable.Client.DispatchAlert(data)` | Dispatch personnalisé sur le client du voleur. |
| `editable/client.lua` | `Editable.Client.Notify(data)` | Style de notification (utilisé quand la NUI est désactivée ou pas prête). |

Chaque fonction contient des exemples commentés et la forme exacte de ses arguments.

## Personnalisation de la NUI

La NUI se trouve dans `web/` (Web Components simples, sans étape de build). Le côté Lua et la page partagent un seul contrat : [web/CONTRACT.md](../../web/CONTRACT.md) (messages, callbacks, payloads des vues, clés de locale).

- **Couleurs, polices, espacements et positionnement** sont des variables CSS dans `web/styles/tokens.css` : couleurs du papier et de l'encre (`--paper-original`, `--ink`, `--stamp`...), polices (`--font-print`, `--font-hand`, `--font-num`) et position de la fiche de job (`--tracker-top`, `--tracker-right`).
- **Les textes** proviennent de la section `nui` de `locales/<lang>.json`.
- `Config.UseNUI = false` supprime la NUI et utilise les menus et notifications d'ox_lib.

## Objets et icônes

Chaque pièce, objet bonus, récompense de fin et objet de butin de catégorie est vérifié dans la liste d'objets de l'inventaire au démarrage et à chaque redémarrage de l'inventaire (ignoré si l'inventaire n'a pas d'export de liste d'objets). Les entrées de butin inconnues sont retirées avec un avertissement dans la console ; les pièces, objets bonus et récompenses inconnus sont seulement signalés.

| Objet | Origine |
| :--- | :--- |
| `vehicle_door`, `vehicle_hood`, `vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `veh_wheels` | Pièces |
| `car-battery` | Bonus du capot |
| `veh_suspension` | `Config.FinishReward` par défaut |
| `scrap_metal`, `sport_wheel`, `turbo_kit` | Butin de catégorie |

Les icônes se trouvent dans `[assets]`, nommées d'après leur objet. Elles proviennent de la galerie d'images RAINMAD (https://items.rainmad.com/).

## Dépannage

| Problème | Cause et solution |
| :--- | :--- |
| `No such export getSharedObject in resource es_extended` (ou similaire) | `Config.Framework` est forcé sur un framework qui n'est pas démarré. Mettez `'auto'`. Depuis la 2.0.0, un framework forcé qui n'est pas démarré bascule sur la détection automatique et affiche un avertissement. |
| `... item "x" is not registered in <inventory>` dans la console | L'objet est absent de votre inventaire. Ajoutez-le depuis [docs/items](../items/). |
| `No supported inventory detected` | Aucun inventaire de la liste n'est démarré. Démarrez-le avant nek_chopshop, ou utilisez `'custom'`. |
| Le joueur n'a pas de clés après le crochetage | Vérifiez `Config.VehicleKeys.System` : votre script de clés n'est peut-être pas pris en charge (utilisez `'custom'`) ou pas démarré. |
| Pas d'alerte à la police | Vérifiez `Config.Police.Dispatch.System` : le script n'est peut-être pas démarré ou pas pris en charge (utilisez `'custom'`). |
| « Not enough police on duty » | `Config.Police.MinOnDuty` (ou le `minPolice` de la catégorie) est supérieur au nombre d'agents en service. Mettez `0` pour le désactiver. |
| « You have to wait N minutes before working again. » | Délai d'attente du job. Le staff peut exécuter `chopshop_resetcd <id>` ou `chopshop_resetcd all`. |
| « Nobody drives here that fast. Wait N s and try again. » | Le contrôle anti-téléportation a rejeté une livraison plus rapide que `Config.Security.MaxAverageSpeed`. Attendez le nombre de secondes indiqué. Le staff avec `Config.AdminAce` ignore ce contrôle. |
| La souris reste à l'écran | Exécutez `/chopshopui`. |
| `Could not check for updates.` | Le serveur ne peut pas joindre GitHub. Sans conséquence. |
| Erreurs de la table de réputation | oxmysql ne fonctionne pas. Vérifiez sa chaîne de connexion. |

Mettez `Config.Debug = true` pour obtenir plus de sorties dans la console.

Remarque : les messages cités sont les textes anglais ; en jeu, ils apparaissent dans la langue configurée.

## Mise à jour depuis la v1

Changements incompatibles :

- **Objets :** 6 nouveaux objets (`vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `scrap_metal`, `sport_wheel`, `turbo_kit`). Enregistrez-les et copiez leurs images (voir « Installation »).
- **Image renommée :** `[assets]/vehicle_wheel.png` devient `[assets]/veh_wheels.png` (le nom de l'objet `veh_wheels` n'a pas changé). Renommez-la dans les images de votre inventaire si vous aviez copié l'ancienne.
- **Locales :** `Config.Locales` a disparu. Les textes sont passés dans `locales/*.json` (ox_lib). Si vous aviez modifié des textes, copiez-les dans votre fichier de langue.
- **Véhicules :** la liste plate `Config.Vehicles` est devenue `Config.Tiers` (l'ancienne liste fonctionne toujours comme une catégorie `low`).
- **Nouvelles sections de configuration :** `Config.Inventory`, `Config.Police`, `Config.VehicleKeys`, `Config.TimeLimit`, `Config.Reputation`, `Config.Tiers`, `Config.AdminAce`, `Config.UseNUI`, `Config.SellPed.QualityMultiplier`. `Config.Framework` vaut désormais `'auto'` par défaut. Fusionnez-les depuis le nouveau `shared/config.lua`.
- **Fonctions modifiables :** `Editable.Client.DispatchAlert` reçoit désormais une table `data` au lieu du véhicule (`data.vehicle` est l'entité). Nouvelles fonctions : `Editable.Server.DispatchAlert`, `Editable.Server.GiveVehicleKeys`, `Editable.Server.RemoveVehicleKeys`, `Editable.Inventory`.
- **Dépendances :** `oxmysql` est désormais requis. `ox_inventory` n'est plus requis.
- **Exports :** l'export client est `exports.nek_chopshop:GetJobStatus()` (utilisez le vrai nom du dossier de la ressource) ; nouveaux exports serveur `GetReputation` et `AddReputation`.

Sauvegardez votre `shared/config.lua` et les fichiers de `editable/` avant de remplacer la ressource, puis réappliquez vos modifications sur les nouveaux fichiers. Liste complète des changements : [CHANGELOG.md](../../CHANGELOG.md).

## Documentation dans d'autres langues

- [English](../../README.md)
- [Español](README.es.md)
- [Português (Brasil)](README.pt-br.md)
- [Deutsch](README.de.md)

## Licence

Voir [LICENSE](../../LICENSE).

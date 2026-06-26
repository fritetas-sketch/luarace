# LuaRace — Courses de rue pour Garry's Mod (véhicules Glide)

Addon qui permet d'organiser des **courses-poursuites** dans Garry's Mod en
utilisant les véhicules de l'addon [Glide](https://github.com/StyledStrike/gmod-glide).

## Mode actuel : Police vs Fuyards

Un (ou plusieurs) **fuyards** doivent survivre à la traque pendant un chrono.
Tous les autres joueurs sont la **police** et doivent les coffrer avant la fin.

- **Ratio automatique** : `fuyards = max(1, floor(joueurs / 5))`.
  - 7 joueurs → 1 fuyard
  - 10 joueurs → 2 fuyards
  - 15 joueurs → 3 fuyards
  - (le nombre de joueurs par fuyard est réglable)
- **Head start** : les fuyards ont quelques secondes d'avance (les véhicules
  des flics sont gelés pendant ce temps).
- **Chrono** : 2 minutes par défaut.
  - Si **au moins un fuyard survit** → les fuyards gagnent.
  - Si **tous les fuyards sont coffrés** → la police gagne.
- **Arrestation** : un flic doit rester proche d'un fuyard quelques secondes
  d'affilée. Plus il est près, plus ça va vite. Une barre de progression
  prévient le fuyard qu'il est en train de se faire prendre.
- **Repérage (reveal)** : la position des fuyards "flashe" à la police par
  intervalles (ping), et reste affichée en permanence dans les dernières
  secondes. Affichage par marqueur à l'écran + flèche directionnelle quand le
  fuyard est hors champ, avec la distance en mètres.

## Installation

1. Avoir l'addon **Glide** installé sur le serveur et les clients.
2. Placer ce dossier dans `garrysmod/addons/luarace/`.
3. Redémarrer le serveur. L'addon se charge tout seul (`lua/autorun/`).

## Commandes

| Chat            | Console          | Effet                          |
|-----------------|------------------|--------------------------------|
| `!race start`   | `luarace_start`  | Démarre une course (admin)     |
| `!race stop`    | `luarace_stop`   | Arrête la course (admin)       |
| `!race info`    | `luarace_info`   | Affiche l'état courant         |

## Configuration (ConVars)

Tout est réglable à chaud côté serveur :

| ConVar                          | Défaut | Description                                        |
|---------------------------------|--------|----------------------------------------------------|
| `luarace_players_per_runner`    | `5`    | Joueurs par fuyard                                 |
| `luarace_round_time`            | `120`  | Durée de la course (s)                             |
| `luarace_headstart`             | `15`   | Avance laissée aux fuyards (s)                     |
| `luarace_bust_radius`           | `350`  | Distance d'arrestation (units)                     |
| `luarace_bust_time`             | `4`    | Temps de proximité requis pour coffrer (s)         |
| `luarace_reveal_interval`       | `20`   | Intervalle entre deux pings de repérage (s)        |
| `luarace_reveal_duration`       | `5`    | Durée d'un ping (s)                                |
| `luarace_final_reveal`          | `30`   | Repérage permanent dans les N dernières secondes   |
| `luarace_require_vehicle`       | `0`    | 1 = ne compter que les joueurs dans un Glide       |
| `luarace_min_players`           | `2`    | Joueurs minimum pour lancer                        |
| `luarace_results_time`          | `10`   | Durée de l'écran de résultats (s)                  |

## Architecture

```
lua/autorun/luarace_loader.lua   -- chargeur (include/AddCSLuaFile)
lua/luarace/
  sh_config.lua   -- états, rôles, ConVars
  sh_util.lua     -- helpers + net strings
  sv_core.lua     -- machine à états, tick, sync réseau
  sv_roles.lua    -- participants, ratio, attribution des rôles, head start
  sv_bust.lua     -- arrestations par proximité
  sv_reveal.lua   -- pings de repérage
  sv_commands.lua -- commandes admin
  cl_net.lua      -- réception de l'état + events (sons/popups)
  cl_hud.lua      -- HUD (chrono, rôle, scores, barre d'arrestation)
  cl_blips.lua    -- marqueurs/flèches des fuyards repérés
```

## Idées / roadmap

Voir la section « Idées » dans la discussion de développement. Pistes prévues :
power-ups (nitro fuyard, herse/barrage flic, EMP), niveau de recherche
« wanted », argent & stats persistantes, points de réapparition pour fuyards
coffrés en spectateur, et d'autres **types de courses** (circuit à checkpoints,
livraison de colis, dernier survivant…).

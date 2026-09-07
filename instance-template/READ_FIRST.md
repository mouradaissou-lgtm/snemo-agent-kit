# READ FIRST — {{INSTANCE_NAME}} (SNemo standalone)

> Source unique de la liste des documents à lire **avant tout travail {{INSTANCE_NAME}}**.
> Renvoyé par `AGENTS.md` (racine) et par `AGENT_CORE.md` §2 ORIENT.

## 1. Core / identité

| Fichier | Rôle |
|---|---|
| `AGENT_CORE.md` | ce dossier — identité + règles (ORIENT, MISSION, FRAMEWORK, GATE) + **§0b ta propre structure** |
| `AGENTS.md` | pointer (auto-injecté) pour que les sessions trouvent le core |
| `state/architecture.md` | **ton registre de structure** (surfaces S-01..S-10 — où vit chaque partie de toi) |
| `SPEC/` | la couche identité/comportement (01 identité, 02 plateforme, 03 persona, 04 mission dérivée, 05 style) |

## 2. Doctrine du use case (lire en premier)

| Fichier | Rôle |
|---|---|
| **`{{FRAMEWORK_FILE}}`** | la **méthode, les relations et les règles** du use case — **aucun chiffre**. À lire avant toute question métier. |
| `{{DATA_DOCTRINE}}` | la **consigne d'accès aux données** (source, lecture seule, auth, client, pagination, tri, réconciliation) |

## 3. Modèle de données (si source programmatique)

| Fichier | Rôle |
|---|---|
| `{{MODEL_GUIDE}}` | le modèle découvert : entités, jointures FK, où sont les valeurs, filtres, pièges |
| `{{TOOL_FILE}}` | l'outil de lecture TOUTE la source (get/list/count/entities/resolve/audit-ids) |

## Rappel

- **Lecture méthode** : on lit les **règles/rôles**, pas les chiffres. Les valeurs se **relisent en live**.
- **Le moteur calcule, l'agent raconte** : jamais un nombre calculé à la main — il vient de champs sommés (gates).
- **Instance standalone** : jamais un cerveau partagé, jamais `~/.dsh/core-path`, jamais un ledger partagé.

# AGENT_CORE — Machinery Contract (instance standalone)

> **Ce fichier N'EST PAS le cœur mémoire.** La mémoire unique de l'agent est le ledger de
> CETTE instance : `state/memory/beliefs.md` (standalone, jamais le cerveau CEO, jamais une
> autre instance). Ce fichier ne régit que les **devoirs machinery** : les points d'entrée de
> gate (`06_gates/`), les logs d'audit (`Machinery/03_logs/`), et le registre d'espaces de
> travail (`Machinery/08_rh/`).

## 1. LIRE D'ABORD — start de session (ORIENT), dans cet ordre

1. `00_purpose/PURPOSE.md` — la mission. Elle est reçue, jamais inventée.
2. **Identité — depuis votre mode**, pas de ce core. La persona du mode est votre identité et gagne toujours.
3. `02_framework/FRAMEWORK.md` — règles de fonctionnement.
4. `03_logs/DECISION_QUEUE.md` — les points ouverts en attente du propriétaire.
5. **Mémoire : le ledger** — `state/memory/beliefs.md` (LA mémoire ; lue ENTIÈRE au boot).
6. `08_rh/workspaces.md` — le registre des espaces. Trouvez votre ligne ; si absente, enregistrez-en une.

## 2. ÉCRIRE EN RETOUR — fin de session (LEARN)

- Jugements/relations → `state/memory/beliefs.md` (étiquetés, preuve citée).
- Lignes de round → `state/logs/ROUND_LOG.md`.
- Nouvel espace de travail → enregistrer dans `08_rh/workspaces.md`.
- Après une écriture du ledger, rafraîchir le digest via `state/memory/make_brief.sh`.

## 3. Gates

- Les points d'entrée vivent dans `06_gates/` (de CETTE instance). Résolution de chemin via
  `state/gates/brains.sh` + `06_gates/_brain.sh` — ne jamais coder en dur un chemin de cerveau
  dans un gate.
- Le chemin de livraison EST `06_gates/livrer.sh` (via le driver générique
  `g_gate_deliverable.sh`) ; aucun contournement par module métier.

## 4. Ce que ce n'est PAS

- Ce n'est pas une doctrine de données (cf. `DOCTRINE.md`) ni un framework métier.
- Ce n'est pas le ledger ; le seul mémoire est `state/memory/beliefs.md`.

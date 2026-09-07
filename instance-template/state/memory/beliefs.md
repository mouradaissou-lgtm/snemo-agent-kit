# MEMORY — knowledge ledger (only memory of this instance)

Author: SNemo ({{INSTANCE_NAME}} standalone). Not shared with any brain. Core: `../AGENT_CORE.md`.

Bootstrap: created fresh. EMPTY. No prior judgments, no contradictions, no
recovered history. Do not invent any.

---

## HOW TO WRITE (read before appending)

- Save a judgment or relation ONLY if it would change a future decision. Never store
  ground-truth facts/metrics — look those up live.
- Every entry carries TRUST LABELS + SEMANTIC LABELS.

### Trust labels (per column)
| Field | Allowed | Meaning |
|-------|---------|---------|
| type | judgment · doctrine · relation · context · contradiction · label_proposal | what kind of belief |
| conf | high · medium · low | how sure |
| mat | L1 · L2 · L3 · L4 | lifecycle / level |
| scope | short textual scope | where it applies |
| source | method@version or observed | where it came from |
| evidence | short textual evidence | why |
| expiry | date or — | when to re-check |
| status | active · open · superseded | verification state |
| labels | L-00X | semantic label ids |
| notes | provenance / stamps / caveats | extra |

### Lifecycle rules
- Unconfirmed for 90 days -> flagged.
- Contradictions are RECORDED, not erased; the contradicted belief gets scoped or demoted.
- Every run ends with an explicit forget list (a date or a discard) covering entries no
  longer relevant.

---

## LABELS (L-XXX) — owned by the user

Active (approved):
- L-001 `insight` — a reusable judgment, not a fact.

Proposed (awaiting user approval; none active yet):
- *(none)*

---

## Ledger

| id | type | content | conf | mat | scope | source | evidence | expiry | status | labels | notes |
|----|------|---------|------|-----|-------|--------|----------|--------|--------|--------|-------|
| B-001 | doctrine | Instance {{INSTANCE_NAME}} freshly scaffolded : standalone, mémoire propre, aucune connexion à un cerveau partagé. Lire AGENT_CORE.md + READ_FIRST.md au boot ; lire ce ledger EN ENTIER à chaque boot | high | L3 | instance {{INSTANCE_NAME}} | bootstrap | scaffold générique make_instance.sh | — | active | L-001 | boot stamp seed |
| B-002 | doctrine | **Instanciation locale de la doctrine cœur B-126** (gate de calcul universelle g_calc) — tout livrable chiffré passe UNE gate de calcul, deux layers : **layer 1 discipline (toujours, aucun domaine)** — chaque chiffre dérivé porte méthode@version + référence producteur ; enregistrement de vérification indépendante déclarée (autre script/seconde source/échantillon/réconciliation) avec résultat (conforme/écart expliqué) ; tampons fraîcheur + complétude ; **layer 2 règles déclarées** (optionnel, rules.json : complétude, tendance, variation, couverture, ratio extrême) → FAIL/WARN/PASS. **FAIL = pas de livraison, retour producteur** ; WARN = livré avec flags en tête | high | L3 | discipline gate (générique) | core doctrine | g_calc.py dans 06_gates | — | active | L-001 | générique — aucun domaine |
| B-003 | doctrine | **Instanciation locale de la doctrine cœur B-127** (gate mécanique, re-faire pas bloquer) — la collision du gate déclenche un re-travail vérifié, jamais un blocage. `run_calc.py` produit l'artefact + `verification.json` PAR CONSTRUCTION ; `--verify` exécute une seconde voie différente du producteur. `g_calc_delivery.sh` (garde de livraison) : livrable sans verification.json ou non indépendant → **REDO** (re-faire avec `run_calc --verify`), jamais simple blocage. Journal `journal_conformite.jsonl` écrit à chaque tentative | high | L3 | discipline gate (générique) | core doctrine | run_calc.py + g_calc_delivery.sh dans 06_gates | — | active | L-001 | générique |
| B-004 | doctrine | **Instanciation locale de la doctrine cœur B-131** (sens mécanique DOUBLECHECK) — dans production_gate.py, les colonnes dérivées sont re-dérivées et vérifiées : plage par op (ratio/pct ∈ [0,100], share ∈ [0,1]) → >100 % = impossible = FAIL ; zéro-dénominateur/nan → FAIL ; cohérence interne (re-calcul ≈ affiché) → FAIL ; cohérence de périmètre des opérandes d'un « / » (base désalignée) → FAIL. Le producteur déclare la formule en générique via `derived` dans rules.json. **B-131 = mécanique** (script déterministe), distinct du jugement `[SENS]` | high | L3 | discipline gate (générique) | core doctrine | production_gate.py (sens_checks) | — | active | L-001 | générique |
| B-005 | doctrine | **Instanciation locale de la doctrine cœur B-132** (verrou compteur d'étapes) — `g_livraison_verif.py` (appelé par g_calc_delivery.sh) REFUSE de livrer tant que toutes les étapes ne sont pas franches : verification.json indépendant ; dernier production_gate = PASS ; les 3 dimensions (DISCIPLINE/RULES/DOUBLECHECK) = PASS ; la livraison n'a pas précédé le gate. Sinon REFUS → REDO (exit 2). Le compteur lit le journal (trace), ne suppose pas | high | L3 | discipline gate (générique) | core doctrine | g_livraison_verif.py + g_calc_delivery.sh | — | active | L-001 | générique |
| B-006 | doctrine | **Instanciation locale de la doctrine cœur B-133** (discipline mapping de schéma) — avant toute requête sur une source, consulter le **mapping local de l'instance** (colonnes/types, jointures FK, périmètres, plénitude) — ne redécouvre pas le schéma à chaque requête. Le bon join, le bon type de clé, le bon périmètre. Chaque instance fournit son mapping local (db_schema_profile.json généré par schema_profile.py) ; la règle est générique | high | L3 | discipline de l'agent (générique) | core doctrine | schema_profile.py + db_schema_profile.json | — | active | L-001 | générique |
| B-007 | doctrine | **Instanciation locale de la doctrine cœur B-141** (provenance gate) — `provenance_gate.py` rend la preuve mécanique. **P1** chaque nombre livré ← un appel à la source de la session OU livrable gated vérifié (sinon ORPHELIN → FAIL → REDO) ; **P2** toute citation MÉTHODE /chemin ← appel réel au même endpoint dans le tour (sinon citation sans appel → FAIL). Dérivation opt-in (--derived) pour totaux/ratios légitimes. Appel mécanisé : `g_provenance.sh <brouillon>` (exécute + journalise ; FAIL → REDO). Générique : aucune notion métier | high | L3 | discipline gate (générique) | core doctrine | provenance_gate.py + g_provenance.sh | — | active | L-001 | générique |
| B-008 | doctrine | **Instanciation locale de la doctrine cœur B-144** (moteur Python + indépendance réelle) — tout nombre dérivé est produit par un moteur (run_calc/produce_*.py → artefact + verification.json), jamais par calcul mental. Golden source = l'application (l'API) ; vérifier = re-confirmer contre le golden (chemin AGRÉGÉ ≠ : re-fetch + agrégation différente, cross-tab, cohérence), jamais un artefact statique ni un re-scan. `independent = verify_source != source_ref` (pas une différence de script) | high | L3 | discipline gate (générique) | core doctrine | run_calc + production_gate DISCIPLINE | — | active | L-001 | générique |
| B-009 | doctrine | **Instanciation locale de la doctrine cœur B-147** (production fraîche + FAIL→REDO auto-check) — un nombre qui répond à la question est produit DANS CE tour (source vive + compute + fenêtre) — re-servir un résultat antérieur est interdit → FAIL → REDO. Auto-check : l'agent écrit un brouillon, exécute `g_provenance.sh --draft` ; PASS → livre ; FAIL (orphelin/claim sans appel/reuse/conflit) → REFAIRE (borné ~2) ; échec persistant → flag + remonter à l'humain, jamais un chiffre orphelin silencieux. Chaque tentative journalisée | high | L3 | discipline gate (générique) | core doctrine | g_provenance.sh (auto-check) | — | active | L-001 | générique — regroupe B-146 + B-147 |

---

## CONTRADICTIONS

*(none)*

---

## FORGET LIST (end of each run)

- *(nothing)*

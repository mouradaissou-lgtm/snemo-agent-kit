# Doctrine — RULE-NO-HEAD-CALC : le modèle ne calcule jamais, il utilise un outil

> **Statut : PROPOSÉE** (à valider par le principal). Complète B-134 (source vivante) et
> B-133 (read-first). Née du constat mesuré : deux instances posant la **même formule exacte**
> (un ratio %) ont rendu **180,5 vs 134,3** pour le même compte — le LLM calculait de tête.

## La règle (interdiction)

**Tout chiffre du livrable doit venir du RÉSULTAT d'un appel d'outil** (SQL · API · script exécuté).
**Le modèle ne calcule jamais un chiffre métier de tête** — ni ratio, ni total, ni pourcentage,
ni écart, ni croissance. Il orchestre, formule, présente, raisonne — **il ne compte pas.**

## Le mécanisme obligatoire (dans l'ordre)

1. **IDENTIFIER** le KPI et sa définition canonique (registre : notion → formule + périmètre + unité + fenêtre).
2. **EXÉCUTER** le calcul via un **outil** (SQL/endpoint/script) — la formule tourne dans l'outil, pas dans le modèle.
3. **CITER** la trace : endpoint ou requête exécutée + filtres + fenêtre.
4. **NE JAMAIS** combler un chiffre manquant par un calcul de tête : chiffre absent = question ou signalement.

## Le verrou dans le gate (application mécanique)

Le livrable est refusé si un chiffre ne trace pas vers un résultat d'outil. Le gate vérifie :
- chaque table/bloc chiffré porte la **référence de l'appel** (endpoint/SQL + filtres + fenêtre) ;
- `tool/result` présent pour les valeurs livrées (l'appel a bien tourné) ;
- chiffres présents **sans appel tracé** → FAIL (pas WARN).

## Pourquoi (la preuve mesurée)

- 2 instances, même formule exacte (FDV/CA %) → **180,5 vs 134,3** (écart 46 pts) : le LLM calculait de tête.
- **Claude Code ne calcule pas de tête** : il écrit/exécute du code et raisonne sur le résultat. L'agent de domaine doit faire pareil — **l'orchestration oui, le calcul non.**

## Ce que le LLM garde le droit de faire

- **Formuler** la question et choisir le KPI.
- **Présenter** les résultats (blocs, tableaux, reporting).
- **Raisonner** sur les chiffres **déjà calculés par la source** (comparer, expliquer, recommander).
- **Interpréter qualitativement** (tendances, causes, recommandations) — en le signalant comme jugement.

## Ce que le LLM n'a PAS le droit de faire

- Calculer un ratio/total/pourcentage/écart de tête.
- « Estimer » un chiffre absent.
- Dériver un KPI depuis son contexte au lieu de le requêter.

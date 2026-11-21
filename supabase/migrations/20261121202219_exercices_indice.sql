-- Phase 5, idées D35 : « Un indice avant le corrigé » (maquette `Indice`).
--
-- Décisions de Bocar du 21/11/2026 (D39) :
-- * Un indice par exercice (un écran d'exercice), pas par question.
-- * L'indice est facultatif : sans indice, l'écran ne montre pas le bouton
--   « Voir un indice ». Les indices sont rédigés à part, relus par Bocar,
--   puis écrits en base avec son accord (comme les scripts oraux, D37).
-- * Le suivi des parents ne sait pas qu'un indice a été vu : rien ne change
--   dans `resultats`.
--
-- Effet sur la sécurité : aucun. La colonne suit les règles RLS existantes
-- de `exercices` : lisible par tous pour les exercices d'une leçon publiée,
-- par les rédacteurs pour toutes les leçons ; aucune écriture depuis
-- l'application.

alter table public.exercices
  add column indice text
  constraint exercices_indice_longueur check (indice is null or char_length(btrim(indice)) between 3 and 500);

comment on column public.exercices.indice is
  'Indice montré avant le corrigé (D39), Markdown court. Ne donne jamais la réponse. Null : pas de bouton « Voir un indice ».';

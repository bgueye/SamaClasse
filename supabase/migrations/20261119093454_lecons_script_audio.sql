-- « Écouter la leçon » (D34) : script de lecture à voix haute de chaque
-- leçon, lu par la synthèse vocale du téléphone (flutter_tts).
--
-- Recopiée depuis la base (appliquée le 19/11/2026) pour que le dépôt reste
-- la référence. Aucun effet sur les règles RLS : la colonne suit celles de
-- `lecons` (lisible par anon pour les leçons publiées).

alter table public.lecons add column if not exists script_audio jsonb;

alter table public.lecons add constraint lecons_script_audio_is_array
  check (script_audio is null or jsonb_typeof(script_audio) = 'array');

comment on column public.lecons.script_audio is 'Script de lecture à voix haute : liste ordonnée de segments [{"lang":"fr-FR","texte":"..."}]. lang = code BCP-47 passé au moteur de synthèse vocale (fr-FR, en-GB, es-ES). Texte rédigé pour l''oral : pas de Markdown, tableaux et symboles convertis en phrases.';

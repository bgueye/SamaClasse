-- « Écouter l'essentiel » (D37) : script oral du résumé « À retenir »,
-- au même format que script_audio (D34).
--
-- Aucun effet sur les règles RLS : la colonne suit celles de `lecons`
-- (lecture des leçons publiées par anon et authenticated, de toutes les
-- leçons par les rédacteurs ; aucune écriture depuis l'application).
-- Appliquée le 20/11/2026, vérifiée en rôle anon.
alter table public.lecons add column if not exists script_retenir jsonb;

alter table public.lecons add constraint lecons_script_retenir_is_array
  check (script_retenir is null or jsonb_typeof(script_retenir) = 'array');

comment on column public.lecons.script_retenir is
  'Script oral de « À retenir » : liste ordonnée [{"lang":"fr-FR","texte":"..."}], '
  'comme script_audio. Texte rédigé pour l''oral, sans symbole ni Markdown. '
  'null : pas de bouton « Écouter l''essentiel ».';

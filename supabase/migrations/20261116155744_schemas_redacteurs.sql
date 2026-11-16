-- Phase 5 : les rédacteurs ajoutent les schémas des leçons depuis
-- l'application (photo du cahier ou image de la galerie), sans passer par le
-- tableau de bord (complète D15).
--
-- Déroulé côté application :
--   1. l'image, réduite sous 150 Ko, est déposée dans l'espace `schemas` à
--      l'adresse `lecons/<id de la leçon>/<uuid>.<jpg|png|webp>` ;
--   2. la fonction `ajouter_schema` vérifie que le fichier existe, écrit la
--      ligne Markdown `![description](adresse)` à l'endroit choisi de
--      l'introduction ou du corps, et garde une trace dans `schemas_lecons` ;
--   3. en cas d'erreur à l'étape 2, l'application supprime le fichier déposé.
-- Retirer un schéma : `retirer_schema` enlève la ligne et la trace, puis
-- l'application supprime le fichier (permis seulement quand plus aucune
-- leçon ne l'utilise).
--
-- Effet sur la sécurité :
-- * Élèves, parents, visiteurs (anon, authenticated non rédacteur) : rien ne
--   change. Ils ne peuvent toujours ni lister, ni déposer, ni supprimer de
--   fichier, ni modifier une leçon. Les images restent lisibles par leur
--   adresse publique, comme avant.
-- * Rédacteurs : peuvent déposer un fichier, mais seulement sous `lecons/`,
--   avec un nom généré (uuid) et une extension d'image. Les garde-fous de
--   l'espace restent (150 Ko, PNG/JPEG/WebP, pas de SVG). Ils peuvent lister
--   l'espace et supprimer un fichier de `lecons/` qu'aucune leçon n'utilise.
--   Les fichiers déposés par Bocar ailleurs dans l'espace (tableau de bord)
--   ne peuvent pas être supprimés depuis l'application.
-- * Aucune règle ne permet de modifier `lecons` directement : seules les deux
--   fonctions ci-dessous (security definer, comme `publier_lecon`) écrivent
--   dans le texte, et elles n'ajoutent ou n'enlèvent qu'une ligne d'image.
--   Le reste du texte n'est jamais réécrit.
-- * Ajouter un schéma à une leçon publiée est permis : il apparaît chez les
--   élèves à la synchronisation suivante. C'est voulu (compléter une leçon
--   déjà en ligne) ; la trace dit qui l'a ajouté et quand.

-- ---------------------------------------------------------------------------
-- Trace des schémas ajoutés depuis l'application
-- ---------------------------------------------------------------------------

create table public.schemas_lecons (
  id bigint generated always as identity primary key,
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  champ text not null check (champ in ('introduction', 'corps')),
  -- Chemin dans l'espace `schemas` ; un fichier ne sert qu'une fois.
  chemin text not null unique
    check (chemin ~ '^lecons/[0-9]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'),
  description text not null check (char_length(description) between 3 and 300),
  -- Ligne exacte écrite dans la leçon : sert à la retrouver pour la retirer.
  ligne text not null,
  -- Compte supprimé plus tard : la date reste, le nom du compte s'efface.
  ajoute_par uuid default auth.uid() references auth.users(id) on delete set null,
  ajoute_le timestamptz not null default now()
);

comment on table public.schemas_lecons is
  'Schémas ajoutés aux leçons par un rédacteur depuis l''application : où, qui, quand (phase 5).';

create index schemas_lecons_lecon_idx on public.schemas_lecons(lecon_id);
create index schemas_lecons_ajoute_par_idx on public.schemas_lecons(ajoute_par);

alter table public.schemas_lecons enable row level security;

create policy "redacteur lit les schemas des lecons" on public.schemas_lecons
  for select to authenticated using (public.est_redacteur());

-- Écriture seulement par les fonctions ci-dessous.
revoke all on public.schemas_lecons from anon;
revoke insert, update, delete, truncate on public.schemas_lecons from authenticated;

-- ---------------------------------------------------------------------------
-- Espace `schemas` : dépôt, liste et suppression par les rédacteurs
-- ---------------------------------------------------------------------------

create policy "redacteur depose un schema de lecon" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'schemas'
    and public.est_redacteur()
    and name ~ '^lecons/[0-9]+/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$'
  );

-- Nécessaire à la suppression par l'API de stockage (elle relit le fichier).
create policy "redacteur liste les schemas" on storage.objects
  for select to authenticated
  using (bucket_id = 'schemas' and public.est_redacteur());

-- Seulement un fichier déposé depuis l'application (`lecons/`) et qu'aucune
-- leçon n'utilise plus : retirer d'abord le schéma de la leçon.
create policy "redacteur supprime un schema inutilise" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'schemas'
    and public.est_redacteur()
    and name like 'lecons/%'
    and not exists (select 1 from public.schemas_lecons s where s.chemin = objects.name)
  );

-- ---------------------------------------------------------------------------
-- Ajouter un schéma dans le texte d'une leçon
-- ---------------------------------------------------------------------------

-- p_apres : nombre de paragraphes (blocs séparés par une ligne vide) après
--   lesquels insérer l'image ; 0 = tout au début, null ou trop grand = à la
--   fin. L'application découpe le texte avec la même règle.
-- p_texte_attendu : le texte du champ tel que l'application l'a affiché. S'il
--   a changé entre-temps (autre rédacteur, correction), on refuse plutôt que
--   d'insérer l'image au mauvais endroit.
create function public.ajouter_schema(
  p_lecon_id bigint,
  p_champ text,
  p_apres int,
  p_texte_attendu text,
  p_chemin text,
  p_description text
)
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- Adresse publique de l'espace, la même que dans docs/CONTENU.md.
  c_base constant text := 'https://earcfeorkfeenqprsxpg.supabase.co/storage/v1/object/public/schemas/';
  c_separateur constant text := E'\\n[ \\t]*\\n';
  v_lecon public.lecons%rowtype;
  v_texte text;
  v_description text := btrim(p_description);
  v_ligne text;
  v_nb int;
  v_debut int;
  v_fin int;
  v_nouveau text;
  v_id bigint;
begin
  if not public.est_redacteur() then
    raise exception 'Seul un rédacteur peut ajouter un schéma.' using errcode = '42501';
  end if;
  if p_champ is null or p_champ not in ('introduction', 'corps') then
    raise exception 'Partie de la leçon inconnue.' using errcode = '22023';
  end if;
  if v_description is null or char_length(v_description) not between 3 and 300 then
    raise exception 'La description doit faire de 3 à 300 caractères.' using errcode = '22023';
  end if;
  -- Crochets et retours à la ligne casseraient la syntaxe Markdown de l'image.
  if v_description ~ '[][\r\n]' then
    raise exception 'La description ne peut contenir ni crochets ni retour à la ligne.' using errcode = '22023';
  end if;
  if p_chemin is null or p_chemin !~ ('^lecons/' || p_lecon_id
       || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(jpg|png|webp)$') then
    raise exception 'Chemin d''image invalide pour cette leçon.' using errcode = '22023';
  end if;
  if not exists (select 1 from storage.objects o where o.bucket_id = 'schemas' and o.name = p_chemin) then
    raise exception 'Image introuvable : déposez-la d''abord.' using errcode = 'P0002';
  end if;

  -- Verrou : deux ajouts simultanés sur la même leçon s'attendent.
  select * into v_lecon from public.lecons where id = p_lecon_id for update;
  if not found then
    raise exception 'Leçon introuvable.' using errcode = 'P0002';
  end if;

  v_texte := coalesce(case p_champ when 'introduction' then v_lecon.introduction else v_lecon.corps end, '');
  if v_texte is distinct from coalesce(p_texte_attendu, '') then
    raise exception 'La leçon a changé entre-temps : rechargez-la, puis recommencez.' using errcode = '40001';
  end if;

  v_ligne := '![' || v_description || '](' || c_base || p_chemin || ')';

  if btrim(v_texte, E' \t\r\n') = '' then
    v_nouveau := v_ligne;
  else
    -- Nombre de paragraphes = séparateurs + 1.
    v_nb := (select count(*) from regexp_matches(v_texte, c_separateur, 'g')) + 1;
    if p_apres is not null and p_apres <= 0 then
      v_nouveau := v_ligne || E'\n\n' || v_texte;
    elsif p_apres is null or p_apres >= v_nb then
      v_nouveau := rtrim(v_texte, E' \t\r\n') || E'\n\n' || v_ligne;
    else
      -- Remplace le p_apres-ième séparateur par « ligne vide, image, ligne
      -- vide » : le reste du texte est gardé à l'identique.
      v_debut := regexp_instr(v_texte, c_separateur, 1, p_apres, 0);
      v_fin := regexp_instr(v_texte, c_separateur, 1, p_apres, 1);
      v_nouveau := left(v_texte, v_debut - 1) || E'\n\n' || v_ligne || E'\n\n' || substr(v_texte, v_fin);
    end if;
  end if;

  update public.lecons
  set introduction = case when p_champ = 'introduction' then v_nouveau else introduction end,
      corps = case when p_champ = 'corps' then v_nouveau else corps end
  where id = p_lecon_id;

  insert into public.schemas_lecons (lecon_id, champ, chemin, description, ligne, ajoute_par)
  values (p_lecon_id, p_champ, p_chemin, v_description, v_ligne, (select auth.uid()))
  returning id into v_id;

  return v_id;
end;
$$;

revoke execute on function public.ajouter_schema(bigint, text, int, text, text, text) from public, anon;
grant execute on function public.ajouter_schema(bigint, text, int, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Retirer un schéma ajouté depuis l'application
-- ---------------------------------------------------------------------------

-- Enlève la ligne de l'image (et une seule ligne vide autour), efface la
-- trace et renvoie le chemin du fichier, que l'application supprime ensuite.
-- Si la ligne a déjà disparu du texte (corrigé à la main), seule la trace
-- est effacée.
create function public.retirer_schema(p_schema_id bigint)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_schema public.schemas_lecons%rowtype;
  v_lecon public.lecons%rowtype;
  v_texte text;
  v_position int;
  v_avant text;
  v_apres text;
  v_nouveau text;
begin
  if not public.est_redacteur() then
    raise exception 'Seul un rédacteur peut retirer un schéma.' using errcode = '42501';
  end if;

  select * into v_schema from public.schemas_lecons where id = p_schema_id;
  if not found then
    raise exception 'Schéma introuvable.' using errcode = 'P0002';
  end if;

  select * into v_lecon from public.lecons where id = v_schema.lecon_id for update;
  v_texte := case v_schema.champ when 'introduction' then v_lecon.introduction else v_lecon.corps end;
  v_position := strpos(coalesce(v_texte, ''), v_schema.ligne);

  if v_position > 0 then
    v_avant := rtrim(left(v_texte, v_position - 1), E' \t\r\n');
    v_apres := ltrim(substr(v_texte, v_position + char_length(v_schema.ligne)), E' \t\r\n');
    v_nouveau := case
      when v_avant = '' then v_apres
      when v_apres = '' then v_avant
      else v_avant || E'\n\n' || v_apres
    end;
    update public.lecons
    set introduction = case when v_schema.champ = 'introduction' then nullif(v_nouveau, '') else introduction end,
        corps = case when v_schema.champ = 'corps' then nullif(v_nouveau, '') else corps end
    where id = v_schema.lecon_id;
  end if;

  delete from public.schemas_lecons where id = p_schema_id;
  return v_schema.chemin;
end;
$$;

revoke execute on function public.retirer_schema(bigint) from public, anon;
grant execute on function public.retirer_schema(bigint) to authenticated;

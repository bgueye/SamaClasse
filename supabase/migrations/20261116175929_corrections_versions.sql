-- Phase 5 : corrections des leçons publiées, versions et rôle validateur
-- (D33).
--
-- Circuit (décidé par Bocar le 16/11/2026) :
--   1. Un rédacteur demande une correction d'une leçon publiée
--      (`demander_correction`) : raison et points à vérifier. Une copie de
--      travail du texte est créée (`corrections_lecons`). La leçon reste en
--      ligne, inchangée pour les élèves.
--   2. Le texte corrigé est écrit dans la copie de travail par le circuit
--      habituel (artefact, puis Claude Code avec les droits
--      d'administration), jamais directement dans la leçon en ligne.
--   3. Les rédacteurs lèvent les points de la correction (`points_leves`,
--      rattachés à la correction).
--   4. Un validateur publie la correction (`publier_correction`) : le texte
--      en ligne est remplacé, et la nouvelle version est archivée
--      (`versions_lecons`). Il peut aussi l'abandonner
--      (`abandonner_correction`), ou revenir à une version précédente
--      (`revenir_a_version`).
-- Le texte seul est concerné (titre, objectifs, introduction, corps,
-- « À retenir ») : les exercices se corrigent sur place, car les résultats
-- des enfants y sont rattachés.
--
-- Rôles :
-- * rédacteur (table `redacteurs`) : lève les points, demande une
--   correction, ajoute des schémas (dans la copie de travail quand la leçon
--   est publiée) ;
-- * validateur (`redacteurs.validateur`, attribué à la main) : publie les
--   nouvelles leçons et les corrections, abandonne une correction, revient à
--   une version, ajoute ou retire un schéma directement en ligne.
--
-- Effet sur la sécurité :
-- * Élèves, parents, téléphones d'enfants : rien ne change. Les copies de
--   travail et les versions ne sont lisibles que par les rédacteurs ; les
--   élèves ne voient toujours que le texte en ligne des leçons publiées.
-- * `publier_lecon` est désormais réservée aux validateurs (un rédacteur
--   simple ne publie plus).
-- * Aucune règle ne permet d'écrire directement dans `corrections_lecons`
--   ou `versions_lecons` depuis l'application : seulement par les
--   fonctions (security definer, contrôles faits dans chacune).

-- ---------------------------------------------------------------------------
-- Rôle validateur
-- ---------------------------------------------------------------------------

alter table public.redacteurs add column validateur boolean not null default false;

comment on column public.redacteurs.validateur is
  'Peut publier, abandonner une correction, revenir à une version (D33). Attribué à la main.';

-- Même construction qu'`est_redacteur` (security invoker : la règle de
-- `redacteurs` laisse chacun lire sa propre ligne). Jamais vrai pour une
-- session anonyme.
create function public.est_validateur()
returns boolean
language sql stable
set search_path = ''
as $$
  select not public.est_anonyme()
     and exists (select 1 from public.redacteurs r where r.id = (select auth.uid()) and r.validateur);
$$;

revoke execute on function public.est_validateur() from public, anon;
grant execute on function public.est_validateur() to authenticated;

-- ---------------------------------------------------------------------------
-- Copies de travail des corrections
-- ---------------------------------------------------------------------------

create table public.corrections_lecons (
  id bigint generated always as identity primary key,
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  etat text not null default 'ouverte' check (etat in ('ouverte', 'publiee', 'abandonnee')),
  -- Texte de travail : copie du texte en ligne à la demande, puis corrigé.
  titre text not null,
  objectifs text[] not null default '{}',
  introduction text,
  corps text,
  a_retenir jsonb not null default '[]',
  points_a_verifier text[] not null default '{}',
  motif text not null check (char_length(btrim(motif)) between 3 and 500),
  demandee_par uuid default auth.uid() references auth.users(id) on delete set null,
  demandee_le timestamptz not null default now(),
  modifiee_le timestamptz not null default now(),
  -- Fin de la correction (publiée ou abandonnée).
  close_par uuid references auth.users(id) on delete set null,
  close_le timestamptz
);

comment on table public.corrections_lecons is
  'Corrections de leçons publiées : copie de travail du texte, points à vérifier, raison (D33).';

-- Une seule correction ouverte par leçon.
create unique index corrections_lecons_une_ouverte on public.corrections_lecons(lecon_id) where etat = 'ouverte';
create index corrections_lecons_lecon_idx on public.corrections_lecons(lecon_id);
create index corrections_lecons_demandee_par_idx on public.corrections_lecons(demandee_par);
create index corrections_lecons_close_par_idx on public.corrections_lecons(close_par);

-- Date de dernière modification du texte de travail (affichée aux
-- rédacteurs : « corrigée le … »).
create function public.noter_modification_correction()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.modifiee_le := now();
  return new;
end;
$$;

create trigger corrections_lecons_modifiee before update on public.corrections_lecons
for each row execute function public.noter_modification_correction();

alter table public.corrections_lecons enable row level security;

create policy "redacteur lit les corrections" on public.corrections_lecons
  for select to authenticated using (public.est_redacteur());

revoke all on public.corrections_lecons from anon;
revoke insert, update, delete, truncate on public.corrections_lecons from authenticated;

-- ---------------------------------------------------------------------------
-- Versions publiées
-- ---------------------------------------------------------------------------

-- Journal : une ligne par version mise en ligne (la dernière est la version
-- en ligne). Jamais modifié ni supprimé depuis l'application.
create table public.versions_lecons (
  id bigint generated always as identity primary key,
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  numero int not null check (numero >= 1),
  titre text not null,
  objectifs text[] not null default '{}',
  introduction text,
  corps text,
  a_retenir jsonb not null default '[]',
  -- « Première publication », raison de la correction, « Retour à la
  -- version 2 »…
  motif text not null,
  correction_id bigint references public.corrections_lecons(id) on delete set null,
  publiee_par uuid references auth.users(id) on delete set null,
  publiee_le timestamptz not null default now(),
  unique (lecon_id, numero)
);

comment on table public.versions_lecons is
  'Versions successives du texte des leçons publiées (D33) : qui, quand, pourquoi.';

create index versions_lecons_correction_idx on public.versions_lecons(correction_id);
create index versions_lecons_publiee_par_idx on public.versions_lecons(publiee_par);

alter table public.versions_lecons enable row level security;

create policy "redacteur lit les versions" on public.versions_lecons
  for select to authenticated using (public.est_redacteur());

revoke all on public.versions_lecons from anon;
revoke insert, update, delete, truncate on public.versions_lecons from authenticated;

-- Point de départ : version 1 des leçons déjà publiées.
insert into public.versions_lecons (lecon_id, numero, titre, objectifs, introduction, corps, a_retenir, motif, publiee_par, publiee_le)
select l.id, 1, l.titre, l.objectifs, l.introduction, l.corps, l.a_retenir,
       'Version en ligne au 16/11/2026', l.publiee_par, coalesce(l.publiee_le, now())
from public.lecons l
where l.statut = 'publiee';

-- Archive le texte en ligne de la leçon comme nouvelle version.
create function public.archiver_version(p_lecon_id bigint, p_motif text, p_correction_id bigint default null)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_numero int;
begin
  select coalesce(max(numero), 0) + 1 into v_numero from public.versions_lecons where lecon_id = p_lecon_id;
  insert into public.versions_lecons (lecon_id, numero, titre, objectifs, introduction, corps, a_retenir, motif, correction_id, publiee_par)
  select l.id, v_numero, l.titre, l.objectifs, l.introduction, l.corps, l.a_retenir, p_motif, p_correction_id, (select auth.uid())
  from public.lecons l where l.id = p_lecon_id;
  return v_numero;
end;
$$;

-- Outil interne des fonctions ci-dessous : personne ne l'appelle directement.
revoke execute on function public.archiver_version(bigint, text, bigint) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Points levés : aussi sur une correction
-- ---------------------------------------------------------------------------

alter table public.points_leves
  add column correction_id bigint references public.corrections_lecons(id) on delete cascade;

create index points_leves_correction_idx on public.points_leves(correction_id);

drop policy "redacteur leve un point" on public.points_leves;
drop policy "redacteur annule un point avant publication" on public.points_leves;

-- Point d'une leçon pas encore publiée (comme avant), ou point d'une
-- correction ouverte de cette leçon.
create policy "redacteur leve un point" on public.points_leves
  for insert to authenticated
  with check (
    public.est_redacteur()
    and leve_par = (select auth.uid())
    and (
      (correction_id is null and exists (
        select 1 from public.lecons l
        where l.id = lecon_id and l.statut <> 'publiee' and point = any (l.points_a_verifier)
      ))
      or (correction_id is not null and exists (
        select 1 from public.corrections_lecons c
        where c.id = correction_id and c.lecon_id = lecon_id and c.etat = 'ouverte'
          and point = any (c.points_a_verifier)
      ))
    )
  );

-- Annuler un point coché par erreur, tant que la leçon (ou la correction)
-- n'est pas publiée. Ensuite, l'historique est figé.
create policy "redacteur annule un point avant publication" on public.points_leves
  for delete to authenticated
  using (
    public.est_redacteur()
    and (
      (correction_id is null and exists (
        select 1 from public.lecons l where l.id = lecon_id and l.statut <> 'publiee'
      ))
      or (correction_id is not null and exists (
        select 1 from public.corrections_lecons c where c.id = correction_id and c.etat = 'ouverte'
      ))
    )
  );

-- ---------------------------------------------------------------------------
-- Publication d'une nouvelle leçon : validateurs seulement, version 1
-- ---------------------------------------------------------------------------

create or replace function public.publier_lecon(p_lecon_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lecon public.lecons%rowtype;
  v_restants int;
begin
  if not public.est_validateur() then
    raise exception 'Seul un validateur peut publier une leçon.' using errcode = '42501';
  end if;

  select * into v_lecon from public.lecons where id = p_lecon_id for update;
  if not found then
    raise exception 'Leçon introuvable.' using errcode = 'P0002';
  end if;
  if v_lecon.statut <> 'a_verifier' then
    raise exception 'Seule une leçon « à vérifier » peut être publiée.' using errcode = 'P0001';
  end if;

  select count(*) into v_restants
  from unnest(v_lecon.points_a_verifier) as p(point)
  where not exists (
    select 1 from public.points_leves pl
    where pl.lecon_id = p_lecon_id and pl.correction_id is null and pl.point = p.point
  );
  if v_restants > 0 then
    raise exception 'Il reste % point(s) à vérifier.', v_restants using errcode = 'P0001';
  end if;

  update public.lecons
  set statut = 'publiee',
      points_a_verifier = '{}',
      publiee_le = now(),
      publiee_par = (select auth.uid())
  where id = p_lecon_id;

  perform public.archiver_version(p_lecon_id, 'Première publication');
end;
$$;

-- ---------------------------------------------------------------------------
-- Demander, publier, abandonner une correction
-- ---------------------------------------------------------------------------

create function public.demander_correction(p_lecon_id bigint, p_motif text, p_points text[])
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_points text[];
  v_id bigint;
begin
  if not public.est_redacteur() then
    raise exception 'Seul un rédacteur peut demander une correction.' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_motif, ''))) not between 3 and 500 then
    raise exception 'Explique en quelques mots ce qu''il faut corriger (3 à 500 caractères).' using errcode = '22023';
  end if;
  -- Points sans espaces superflus, sans doublon ni vide ; 20 au plus.
  select coalesce(array_agg(distinct btrim(p)), '{}') into v_points
  from unnest(coalesce(p_points, '{}')) as t(p) where btrim(p) <> '';
  if cardinality(v_points) = 0 or cardinality(v_points) > 20 then
    raise exception 'Indique de 1 à 20 points à vérifier.' using errcode = '22023';
  end if;
  if exists (select 1 from unnest(v_points) as t(p) where char_length(p) > 500) then
    raise exception 'Un point ne doit pas dépasser 500 caractères.' using errcode = '22023';
  end if;
  if not exists (select 1 from public.lecons l where l.id = p_lecon_id and l.statut = 'publiee') then
    raise exception 'Seule une leçon publiée se corrige ainsi.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.corrections_lecons c where c.lecon_id = p_lecon_id and c.etat = 'ouverte') then
    raise exception 'Une correction de cette leçon est déjà en cours.' using errcode = 'P0001';
  end if;

  insert into public.corrections_lecons (lecon_id, titre, objectifs, introduction, corps, a_retenir, points_a_verifier, motif, demandee_par)
  select l.id, l.titre, l.objectifs, l.introduction, l.corps, l.a_retenir, v_points, btrim(p_motif), (select auth.uid())
  from public.lecons l where l.id = p_lecon_id
  returning id into v_id;
  return v_id;
end;
$$;

revoke execute on function public.demander_correction(bigint, text, text[]) from public, anon;
grant execute on function public.demander_correction(bigint, text, text[]) to authenticated;

create function public.publier_correction(p_correction_id bigint)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_correction public.corrections_lecons%rowtype;
  v_restants int;
begin
  if not public.est_validateur() then
    raise exception 'Seul un validateur peut publier une correction.' using errcode = '42501';
  end if;

  select * into v_correction from public.corrections_lecons where id = p_correction_id for update;
  if not found or v_correction.etat <> 'ouverte' then
    raise exception 'Cette correction n''est plus en cours.' using errcode = 'P0002';
  end if;

  select count(*) into v_restants
  from unnest(v_correction.points_a_verifier) as p(point)
  where not exists (
    select 1 from public.points_leves pl where pl.correction_id = p_correction_id and pl.point = p.point
  );
  if v_restants > 0 then
    raise exception 'Il reste % point(s) à vérifier.', v_restants using errcode = 'P0001';
  end if;

  -- Verrou sur la leçon, puis remplacement du texte en ligne.
  perform 1 from public.lecons where id = v_correction.lecon_id for update;
  update public.lecons
  set titre = v_correction.titre,
      objectifs = v_correction.objectifs,
      introduction = v_correction.introduction,
      corps = v_correction.corps,
      a_retenir = v_correction.a_retenir
  where id = v_correction.lecon_id;

  update public.corrections_lecons
  set etat = 'publiee', close_par = (select auth.uid()), close_le = now()
  where id = p_correction_id;

  return public.archiver_version(v_correction.lecon_id, v_correction.motif, p_correction_id);
end;
$$;

revoke execute on function public.publier_correction(bigint) from public, anon;
grant execute on function public.publier_correction(bigint) to authenticated;

-- Abandon : par un validateur ou par le rédacteur qui l'a demandée. Rend
-- les chemins des schémas ajoutés dans cette correction : l'application
-- supprime ces fichiers (ils ne sont utilisés nulle part en ligne).
create function public.abandonner_correction(p_correction_id bigint)
returns text[]
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_correction public.corrections_lecons%rowtype;
  v_chemins text[];
begin
  select * into v_correction from public.corrections_lecons where id = p_correction_id for update;
  if not found or v_correction.etat <> 'ouverte' then
    raise exception 'Cette correction n''est plus en cours.' using errcode = 'P0002';
  end if;
  if not (public.est_validateur()
          or (public.est_redacteur() and v_correction.demandee_par = (select auth.uid()))) then
    raise exception 'Seul un validateur, ou le rédacteur qui l''a demandée, peut abandonner cette correction.'
      using errcode = '42501';
  end if;

  select coalesce(array_agg(s.chemin), '{}') into v_chemins
  from public.schemas_lecons s where s.correction_id = p_correction_id;
  delete from public.schemas_lecons where correction_id = p_correction_id;

  update public.corrections_lecons
  set etat = 'abandonnee', close_par = (select auth.uid()), close_le = now()
  where id = p_correction_id;
  return v_chemins;
end;
$$;

revoke execute on function public.abandonner_correction(bigint) from public, anon;
grant execute on function public.abandonner_correction(bigint) to authenticated;

-- Retour à une version précédente : son texte repasse en ligne, et ce
-- retour est lui-même archivé (rien ne se perd). Refusé pendant une
-- correction (elle partirait d'un autre texte).
create function public.revenir_a_version(p_version_id bigint)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_version public.versions_lecons%rowtype;
begin
  if not public.est_validateur() then
    raise exception 'Seul un validateur peut revenir à une version précédente.' using errcode = '42501';
  end if;
  select * into v_version from public.versions_lecons where id = p_version_id;
  if not found then
    raise exception 'Version introuvable.' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.corrections_lecons c where c.lecon_id = v_version.lecon_id and c.etat = 'ouverte') then
    raise exception 'Une correction de cette leçon est en cours : publie-la ou abandonne-la d''abord.' using errcode = 'P0001';
  end if;

  perform 1 from public.lecons where id = v_version.lecon_id for update;
  update public.lecons
  set titre = v_version.titre,
      objectifs = v_version.objectifs,
      introduction = v_version.introduction,
      corps = v_version.corps,
      a_retenir = v_version.a_retenir
  where id = v_version.lecon_id;

  return public.archiver_version(v_version.lecon_id, 'Retour à la version ' || v_version.numero);
end;
$$;

revoke execute on function public.revenir_a_version(bigint) from public, anon;
grant execute on function public.revenir_a_version(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- Schémas : dans la copie de travail quand une correction est ouverte
-- ---------------------------------------------------------------------------

-- Schéma ajouté dans une correction (sinon, directement dans la leçon).
alter table public.schemas_lecons
  add column correction_id bigint references public.corrections_lecons(id) on delete set null;

create index schemas_lecons_correction_idx on public.schemas_lecons(correction_id);

-- Où va le schéma :
-- * leçon pas encore publiée : dans la leçon (tout rédacteur) ;
-- * leçon publiée avec une correction ouverte : dans la copie de travail
--   (tout rédacteur) ; il passera en ligne avec la correction ;
-- * leçon publiée sans correction : en ligne, validateurs seulement.
-- Même signature qu'avant : `p_texte_attendu` est le texte de la cible
-- (copie de travail ou leçon), tel que l'application l'a affiché.
create or replace function public.ajouter_schema(
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
  v_correction public.corrections_lecons%rowtype;
  v_dans_correction boolean := false;
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

  select * into v_lecon from public.lecons where id = p_lecon_id for update;
  if not found then
    raise exception 'Leçon introuvable.' using errcode = 'P0002';
  end if;

  if v_lecon.statut = 'publiee' then
    select * into v_correction from public.corrections_lecons
    where lecon_id = p_lecon_id and etat = 'ouverte' for update;
    v_dans_correction := found;
    if not v_dans_correction and not public.est_validateur() then
      raise exception 'Leçon publiée : demande d''abord une correction pour y ajouter un schéma.' using errcode = '42501';
    end if;
  end if;

  if v_dans_correction then
    v_texte := coalesce(case p_champ when 'introduction' then v_correction.introduction else v_correction.corps end, '');
  else
    v_texte := coalesce(case p_champ when 'introduction' then v_lecon.introduction else v_lecon.corps end, '');
  end if;
  if v_texte is distinct from coalesce(p_texte_attendu, '') then
    raise exception 'La leçon a changé entre-temps : rechargez-la, puis recommencez.' using errcode = '40001';
  end if;

  v_ligne := '![' || v_description || '](' || c_base || p_chemin || ')';

  if btrim(v_texte, E' \t\r\n') = '' then
    v_nouveau := v_ligne;
  else
    v_nb := (select count(*) from regexp_matches(v_texte, c_separateur, 'g')) + 1;
    if p_apres is not null and p_apres <= 0 then
      v_nouveau := v_ligne || E'\n\n' || v_texte;
    elsif p_apres is null or p_apres >= v_nb then
      v_nouveau := rtrim(v_texte, E' \t\r\n') || E'\n\n' || v_ligne;
    else
      v_debut := regexp_instr(v_texte, c_separateur, 1, p_apres, 0);
      v_fin := regexp_instr(v_texte, c_separateur, 1, p_apres, 1);
      v_nouveau := left(v_texte, v_debut - 1) || E'\n\n' || v_ligne || E'\n\n' || substr(v_texte, v_fin);
    end if;
  end if;

  if v_dans_correction then
    update public.corrections_lecons
    set introduction = case when p_champ = 'introduction' then v_nouveau else introduction end,
        corps = case when p_champ = 'corps' then v_nouveau else corps end
    where id = v_correction.id;
  else
    update public.lecons
    set introduction = case when p_champ = 'introduction' then v_nouveau else introduction end,
        corps = case when p_champ = 'corps' then v_nouveau else corps end
    where id = p_lecon_id;
  end if;

  insert into public.schemas_lecons (lecon_id, champ, chemin, description, ligne, ajoute_par, correction_id)
  values (p_lecon_id, p_champ, p_chemin, v_description, v_ligne, (select auth.uid()),
          case when v_dans_correction then v_correction.id end)
  returning id into v_id;

  return v_id;
end;
$$;

-- Retrait :
-- * schéma ajouté dans une correction encore ouverte : retiré de la copie
--   de travail (tout rédacteur) ;
-- * schéma d'une leçon pas encore publiée : retiré de la leçon (tout
--   rédacteur) ;
-- * schéma en ligne d'une leçon publiée : validateurs seulement, et pas
--   pendant une correction (la copie de travail le contient aussi).
create or replace function public.retirer_schema(p_schema_id bigint)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_schema public.schemas_lecons%rowtype;
  v_lecon public.lecons%rowtype;
  v_correction public.corrections_lecons%rowtype;
  v_dans_correction boolean := false;
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

  if v_schema.correction_id is not null then
    select * into v_correction from public.corrections_lecons
    where id = v_schema.correction_id and etat = 'ouverte' for update;
    v_dans_correction := found;
  end if;

  if not v_dans_correction and v_lecon.statut = 'publiee' then
    if not public.est_validateur() then
      raise exception 'Ce schéma est en ligne : seul un validateur peut le retirer.' using errcode = '42501';
    end if;
    if exists (select 1 from public.corrections_lecons c where c.lecon_id = v_lecon.id and c.etat = 'ouverte') then
      raise exception 'Une correction de cette leçon est en cours : publie-la ou abandonne-la d''abord.' using errcode = 'P0001';
    end if;
  end if;

  if v_dans_correction then
    v_texte := case v_schema.champ when 'introduction' then v_correction.introduction else v_correction.corps end;
  else
    v_texte := case v_schema.champ when 'introduction' then v_lecon.introduction else v_lecon.corps end;
  end if;
  v_position := strpos(coalesce(v_texte, ''), v_schema.ligne);

  if v_position > 0 then
    v_avant := rtrim(left(v_texte, v_position - 1), E' \t\r\n');
    v_apres := ltrim(substr(v_texte, v_position + char_length(v_schema.ligne)), E' \t\r\n');
    v_nouveau := case
      when v_avant = '' then v_apres
      when v_apres = '' then v_avant
      else v_avant || E'\n\n' || v_apres
    end;
    if v_dans_correction then
      update public.corrections_lecons
      set introduction = case when v_schema.champ = 'introduction' then nullif(v_nouveau, '') else introduction end,
          corps = case when v_schema.champ = 'corps' then nullif(v_nouveau, '') else corps end
      where id = v_correction.id;
    else
      update public.lecons
      set introduction = case when v_schema.champ = 'introduction' then nullif(v_nouveau, '') else introduction end,
          corps = case when v_schema.champ = 'corps' then nullif(v_nouveau, '') else corps end
      where id = v_schema.lecon_id;
    end if;
  end if;

  delete from public.schemas_lecons where id = p_schema_id;
  return v_schema.chemin;
end;
$$;

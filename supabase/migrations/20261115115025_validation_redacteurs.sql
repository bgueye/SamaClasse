-- Phase 4 : validation et publication des leçons par les rédacteurs (D23, D25).
--
-- Principes :
-- * Un rédacteur (table `redacteurs`, attribuée à la main) voit toutes les
--   leçons, quel que soit leur statut, avec leurs exercices et leurs sources.
--   Les élèves et les parents ne voient toujours que les leçons publiées.
-- * Lever un point à vérifier laisse une trace : qui, quand, et le texte du
--   point au moment où il a été levé (table `points_leves`, D25).
-- * Publier passe par une seule fonction, `publier_lecon`, qui vérifie le rôle
--   et que chaque point a été levé, puis passe la leçon à « publiee » et note
--   qui l'a publiée et quand. Aucune modification directe de `lecons` depuis
--   l'application : le texte des leçons reste édité dans les artefacts.

-- ---------------------------------------------------------------------------
-- Rôle rédacteur
-- ---------------------------------------------------------------------------

-- security invoker : la règle de `redacteurs` laisse chacun lire sa propre
-- ligne, cela suffit. Réservée à `authenticated` : les règles qui l'utilisent
-- ne concernent que les comptes connectés, `anon` ne l'évalue jamais.
create function public.est_redacteur()
returns boolean
language sql stable
set search_path = ''
as $$
  select exists (select 1 from public.redacteurs r where r.id = (select auth.uid()));
$$;

revoke execute on function public.est_redacteur() from public, anon;
grant execute on function public.est_redacteur() to authenticated;

-- Le rédacteur voit tout le contenu, publié ou non. Ces règles s'ajoutent
-- aux règles existantes (lecture des leçons publiées), qui ne changent pas.
create policy "redacteur lit toutes les lecons" on public.lecons
  for select to authenticated using (public.est_redacteur());
create policy "redacteur lit tous les exercices" on public.exercices
  for select to authenticated using (public.est_redacteur());
create policy "redacteur lit toutes les sources de lecons" on public.lecon_sources
  for select to authenticated using (public.est_redacteur());

-- ---------------------------------------------------------------------------
-- Trace de la publication sur la leçon
-- ---------------------------------------------------------------------------

alter table public.lecons
  add column publiee_le timestamptz,
  -- Compte supprimé plus tard : la date reste, le nom du compte s'efface.
  add column publiee_par uuid references auth.users(id) on delete set null;

create index lecons_publiee_par_idx on public.lecons(publiee_par);

-- ---------------------------------------------------------------------------
-- Historique des points levés (D25)
-- ---------------------------------------------------------------------------

create table public.points_leves (
  id bigint generated always as identity primary key,
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  -- Copie du texte du point : l'historique reste lisible même si la liste
  -- `points_a_verifier` est vidée à la publication.
  point text not null,
  leve_par uuid default auth.uid() references auth.users(id) on delete set null,
  leve_le timestamptz not null default now(),
  -- Facultatif : comment le point a été vérifié (« conforme au cahier p. 12 »).
  commentaire text check (commentaire is null or char_length(commentaire) <= 500)
);

comment on table public.points_leves is
  'Points à vérifier levés par un rédacteur avant publication : qui, quand, comment (phase 4, D25).';

create index points_leves_lecon_idx on public.points_leves(lecon_id);
create index points_leves_leve_par_idx on public.points_leves(leve_par);

alter table public.points_leves enable row level security;

create policy "redacteur lit les points leves" on public.points_leves
  for select to authenticated using (public.est_redacteur());

-- Lever un point : seulement un point réellement à vérifier sur une leçon non
-- publiée, en son propre nom.
create policy "redacteur leve un point" on public.points_leves
  for insert to authenticated
  with check (
    public.est_redacteur()
    and leve_par = (select auth.uid())
    and exists (
      select 1 from public.lecons l
      where l.id = lecon_id and l.statut <> 'publiee' and point = any (l.points_a_verifier)
    )
  );

-- Annuler un point coché par erreur, tant que la leçon n'est pas publiée.
-- Après publication, l'historique est figé.
create policy "redacteur annule un point avant publication" on public.points_leves
  for delete to authenticated
  using (
    public.est_redacteur()
    and exists (select 1 from public.lecons l where l.id = lecon_id and l.statut <> 'publiee')
  );

revoke all on public.points_leves from anon;
revoke update, truncate on public.points_leves from authenticated;

-- ---------------------------------------------------------------------------
-- Publication
-- ---------------------------------------------------------------------------

-- security definer : indispensable, car aucune règle ne permet de modifier
-- `lecons` depuis l'application. La fonction fait elle-même les contrôles.
create function public.publier_lecon(p_lecon_id bigint)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_lecon public.lecons%rowtype;
  v_restants int;
begin
  if not public.est_redacteur() then
    raise exception 'Seul un rédacteur peut publier une leçon.' using errcode = '42501';
  end if;

  -- Verrou : deux publications simultanées de la même leçon s'attendent.
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
    select 1 from public.points_leves pl where pl.lecon_id = p_lecon_id and pl.point = p.point
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
end;
$$;

revoke execute on function public.publier_lecon(bigint) from public, anon;
grant execute on function public.publier_lecon(bigint) to authenticated;

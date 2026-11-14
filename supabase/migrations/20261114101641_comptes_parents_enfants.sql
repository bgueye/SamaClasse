-- Phase 2 : comptes parents, profils enfants et rôle rédacteur (D21 à D23).
--
-- Principes :
-- * Seul le parent a un compte (auth.users, connexion par code reçu par
--   e-mail). Ses enfants sont de simples profils : un prénom et une classe,
--   aucune autre donnée, aucun identifiant (D21).
-- * Le contenu (programme, leçons publiées, schémas) reste lisible sans
--   compte : aucune règle existante n'est modifiée.
-- * Le rôle rédacteur se donne à la main, par le tableau de bord ; personne
--   ne peut se l'attribuer depuis l'application (D23).

-- ---------------------------------------------------------------------------
-- Profils enfants
-- ---------------------------------------------------------------------------

create table public.enfants (
  id bigint generated always as identity primary key,
  -- Rempli automatiquement avec le compte connecté : l'application n'a pas à
  -- l'envoyer, et la règle d'insertion refuse toute autre valeur.
  parent_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  prenom text not null check (char_length(btrim(prenom)) between 1 and 40),
  classe_id smallint not null references public.classes(id),
  created_at timestamptz not null default now()
);

comment on table public.enfants is
  'Profils enfants rattachés à un compte parent (D21) : prénom et classe seulement.';

create index enfants_parent_idx on public.enfants(parent_id);
create index enfants_classe_idx on public.enfants(classe_id);

-- Garde-fou contre les abus : 10 profils au plus par compte.
-- security invoker : le comptage passe par la règle de lecture, qui ne montre
-- au parent que ses propres enfants ; c'est exactement ce qu'on veut compter.
create function public.limiter_enfants()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (select count(*) from public.enfants where parent_id = new.parent_id) >= 10 then
    raise exception 'Nombre maximal de profils enfants atteint (10).'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger enfants_limite before insert on public.enfants
for each row execute function public.limiter_enfants();

alter table public.enfants enable row level security;

-- Chaque parent voit, ajoute, modifie et supprime ses enfants, et seulement
-- les siens. `(select auth.uid())` : évalué une fois par requête (conseil de
-- performance Supabase) au lieu d'une fois par ligne.
create policy "parent lit ses enfants" on public.enfants
  for select to authenticated using (parent_id = (select auth.uid()));
create policy "parent ajoute ses enfants" on public.enfants
  for insert to authenticated with check (parent_id = (select auth.uid()));
-- with check : un parent ne peut pas « donner » un profil à un autre compte.
create policy "parent modifie ses enfants" on public.enfants
  for update to authenticated
  using (parent_id = (select auth.uid()))
  with check (parent_id = (select auth.uid()));
create policy "parent supprime ses enfants" on public.enfants
  for delete to authenticated using (parent_id = (select auth.uid()));

-- Sans compte, rien : on retire aussi les droits de table (double sécurité).
revoke all on public.enfants from anon;

-- ---------------------------------------------------------------------------
-- Rédacteurs
-- ---------------------------------------------------------------------------

-- Table séparée plutôt qu'une colonne « rôle » : un rédacteur peut aussi être
-- parent, et il n'existe aucun chemin d'écriture depuis l'application.
-- Ajout d'un rédacteur (tableau de bord, éditeur SQL) :
--   insert into public.redacteurs (id) select id from auth.users where email = '…';
create table public.redacteurs (
  id uuid primary key references auth.users(id) on delete cascade,
  ajoute_le timestamptz not null default now()
);

comment on table public.redacteurs is
  'Comptes autorisés à valider et publier les leçons (phase 4). Attribué à la main (D23).';

alter table public.redacteurs enable row level security;

-- Un compte peut seulement savoir s'il est lui-même rédacteur (pour afficher
-- ou non l'écran de validation en phase 4). Aucune règle d'écriture.
create policy "compte voit son statut de redacteur" on public.redacteurs
  for select to authenticated using (id = (select auth.uid()));

revoke all on public.redacteurs from anon;
revoke insert, update, delete, truncate on public.redacteurs from authenticated;

-- Phase 3 : leçons lues et résultats des exercices des enfants (D24).
--
-- Principes :
-- * Seuls les enfants qui ont un profil (table `enfants`, D21) et dont le
--   parent est connecté sur le téléphone envoient quelque chose. Sans profil,
--   rien ne part, comme aujourd'hui.
-- * Jamais le texte libre des élèves : seulement « réussi ou non », le score
--   et la date. Le brouillon reste sur le téléphone (promesse de l'écran).
-- * Hors connexion, le téléphone garde les lignes et les envoie au retour du
--   réseau (D24). Chaque résultat porte un identifiant fabriqué par le
--   téléphone : un envoi répété (réseau coupé au mauvais moment) ne crée pas
--   de doublon.
-- * Chaque parent ne lit et n'écrit que pour ses propres enfants. Supprimer
--   un profil enfant supprime ses lectures et ses résultats.

-- ---------------------------------------------------------------------------
-- Leçons lues : une ligne par enfant et par leçon (la dernière ouverture)
-- ---------------------------------------------------------------------------

create table public.lectures (
  enfant_id bigint not null references public.enfants(id) on delete cascade,
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  -- Heure du téléphone au moment de la lecture, même si l'envoi a lieu plus
  -- tard (hors connexion).
  lue_le timestamptz not null,
  primary key (enfant_id, lecon_id)
);

comment on table public.lectures is
  'Dernière ouverture de chaque leçon par un enfant (phase 3, D24).';

create index lectures_lecon_idx on public.lectures(lecon_id);

-- ---------------------------------------------------------------------------
-- Résultats : une ligne par exercice validé
-- ---------------------------------------------------------------------------

create table public.resultats (
  -- Fabriqué par le téléphone (UUID) : renvoyer la même ligne est sans effet.
  id uuid primary key,
  enfant_id bigint not null references public.enfants(id) on delete cascade,
  exercice_id bigint not null references public.exercices(id) on delete cascade,
  reussi boolean not null,
  -- Exercice corrigé par l'application : bonnes réponses sur le total.
  -- Exercice comparé au corrigé (« Avais-tu juste ? ») : score vide et
  -- auto_evaluation vraie.
  bonnes smallint,
  total smallint,
  auto_evaluation boolean not null,
  fait_le timestamptz not null,           -- heure du téléphone
  recu_le timestamptz not null default now(),
  constraint resultats_score check (
    (auto_evaluation and bonnes is null and total is null)
    or (not auto_evaluation and total between 1 and 100 and bonnes between 0 and total)
  ),
  -- « Réussi » doit correspondre au score quand il y en a un.
  constraint resultats_reussi check (auto_evaluation or reussi = (bonnes = total))
);

comment on table public.resultats is
  'Résultats des exercices des enfants, sans aucun texte saisi (phase 3, D24).';

create index resultats_enfant_date_idx on public.resultats(enfant_id, fait_le desc);
create index resultats_exercice_idx on public.resultats(exercice_id);

-- ---------------------------------------------------------------------------
-- Règles RLS
-- ---------------------------------------------------------------------------
-- « L'enfant est à moi » : on passe par la table `enfants`, dont la règle de
-- lecture ne montre au parent que ses propres enfants.
-- À l'écriture, on vérifie aussi que la leçon ou l'exercice est publié : les
-- règles de `lecons` et `exercices` ne laissent voir que le contenu publié.

alter table public.lectures enable row level security;
alter table public.resultats enable row level security;

create policy "parent lit les lectures de ses enfants" on public.lectures
  for select to authenticated
  using (exists (select 1 from public.enfants e where e.id = enfant_id and e.parent_id = (select auth.uid())));

create policy "parent enregistre les lectures de ses enfants" on public.lectures
  for insert to authenticated
  with check (
    exists (select 1 from public.enfants e where e.id = enfant_id and e.parent_id = (select auth.uid()))
    and exists (select 1 from public.lecons l where l.id = lecon_id)
  );

-- Relire une leçon met à jour sa date (envoi en « upsert »).
create policy "parent met a jour les lectures de ses enfants" on public.lectures
  for update to authenticated
  using (exists (select 1 from public.enfants e where e.id = enfant_id and e.parent_id = (select auth.uid())))
  with check (exists (select 1 from public.enfants e where e.id = enfant_id and e.parent_id = (select auth.uid())));

create policy "parent lit les resultats de ses enfants" on public.resultats
  for select to authenticated
  using (exists (select 1 from public.enfants e where e.id = enfant_id and e.parent_id = (select auth.uid())));

create policy "parent enregistre les resultats de ses enfants" on public.resultats
  for insert to authenticated
  with check (
    exists (select 1 from public.enfants e where e.id = enfant_id and e.parent_id = (select auth.uid()))
    and exists (select 1 from public.exercices x where x.id = exercice_id)
  );

-- Pas de modification ni de suppression d'un résultat depuis l'application :
-- un résultat est un fait. Il disparaît avec le profil de l'enfant.
revoke all on public.lectures from anon;
revoke all on public.resultats from anon;
revoke delete, truncate on public.lectures from authenticated;
revoke update, delete, truncate on public.resultats from authenticated;

-- Types
create type public.statut_programme as enum ('officiel','source','cahier','a_valider','a_completer');
create type public.statut_lecon as enum ('brouillon','a_verifier','publiee');
create type public.niveau_exercice as enum ('je_connais','j_applique','je_reflechis');
create type public.type_exercice as enum ('qcm','vrai_faux','relier','tableau','question_cours','documents','experience','calcul','redaction','epreuve');
create type public.nature_source as enum ('cahier','complement','programme');

-- Référentiels
create table public.classes (
  id smallint generated always as identity primary key,
  code text not null unique,
  libelle text not null,
  cycle text not null check (cycle in ('elementaire','moyen','secondaire')),
  ordre smallint not null
);

create table public.matieres (
  id smallint generated always as identity primary key,
  slug text not null unique,
  nom text not null
);

create table public.sources (
  id smallint generated always as identity primary key,
  libelle text not null unique,
  fiabilite text,
  url text
);

-- Programme
create table public.chapitres (
  id bigint generated always as identity primary key,
  classe_id smallint not null references public.classes(id) on delete restrict,
  matiere_id smallint not null references public.matieres(id) on delete restrict,
  numero smallint not null,
  titre text not null,
  partie text,
  statut public.statut_programme not null default 'a_valider',
  source_id smallint references public.sources(id) on delete set null,
  remarque text,
  unique (classe_id, matiere_id, numero)
);
create index chapitres_matiere_idx on public.chapitres(matiere_id);
create index chapitres_source_idx on public.chapitres(source_id);

-- Leçons
create table public.lecons (
  id bigint generated always as identity primary key,
  chapitre_id bigint not null references public.chapitres(id) on delete cascade,
  numero smallint not null default 1,
  titre text not null,
  date_cours date,
  objectifs text[] not null default '{}',
  introduction text,
  corps text,
  a_retenir jsonb not null default '[]'::jsonb,
  points_a_verifier text[] not null default '{}',
  statut public.statut_lecon not null default 'brouillon',
  artefact_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (chapitre_id, numero)
);

create table public.exercices (
  id bigint generated always as identity primary key,
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  ordre smallint not null,
  niveau public.niveau_exercice not null,
  type public.type_exercice not null,
  enonce text not null,
  donnees jsonb,
  reponse jsonb,
  corrige text,
  unique (lecon_id, ordre)
);

create table public.lecon_sources (
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  source_id smallint not null references public.sources(id) on delete restrict,
  nature public.nature_source not null,
  primary key (lecon_id, source_id)
);
create index lecon_sources_source_idx on public.lecon_sources(source_id);

-- updated_at
create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger lecons_updated_at before update on public.lecons
for each row execute function public.set_updated_at();

-- RLS : lecture publique du programme ; leçons et exercices visibles seulement une fois publiés.
-- Aucune écriture côté client pour l'instant (saisie via la clé service / tableau de bord).
alter table public.classes enable row level security;
alter table public.matieres enable row level security;
alter table public.sources enable row level security;
alter table public.chapitres enable row level security;
alter table public.lecons enable row level security;
alter table public.exercices enable row level security;
alter table public.lecon_sources enable row level security;

create policy "lecture publique" on public.classes for select to anon, authenticated using (true);
create policy "lecture publique" on public.matieres for select to anon, authenticated using (true);
create policy "lecture publique" on public.sources for select to anon, authenticated using (true);
create policy "lecture publique" on public.chapitres for select to anon, authenticated using (true);
create policy "lecons publiees" on public.lecons for select to anon, authenticated using (statut = 'publiee');
create policy "exercices des lecons publiees" on public.exercices for select to anon, authenticated
  using (exists (select 1 from public.lecons l where l.id = lecon_id and l.statut = 'publiee'));
create policy "sources des lecons publiees" on public.lecon_sources for select to anon, authenticated
  using (exists (select 1 from public.lecons l where l.id = lecon_id and l.statut = 'publiee'));

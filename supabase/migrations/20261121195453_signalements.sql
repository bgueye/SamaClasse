-- Phase 5, idées D35 : « Signaler une erreur » sur une leçon ou un exercice.
--
-- Décisions de Bocar du 21/11/2026 :
-- * Tout le monde peut signaler, y compris un élève sans profil ni compte
--   (rôle `anon`) : c'est la grande majorité des lecteurs.
-- * Un motif parmi quatre (maquette `Signaler`) et une précision facultative
--   de 500 caractères au plus. L'application avertit sous le champ :
--   « N’écris pas ton nom ni ton numéro. »
--
-- Effet sur la sécurité :
-- * Personne n'écrit directement dans `signalements` : l'envoi passe par
--   `signaler_erreur` (security definer), qui vérifie que la leçon est
--   publiée et que l'exercice lui appartient.
-- * Seuls les rédacteurs (`est_redacteur()`, jamais une session anonyme)
--   lisent les signalements et les traitent (`traiter_signalement`).
-- * Aucune identité gardée dans `signalements` : ni compte, ni profil, ni
--   appareil, ni adresse IP.
-- * Contre l'envoi en masse : 5 signalements par heure par « envoyeur » et
--   100 par heure en tout. L'envoyeur est la session connectée (parent,
--   téléphone lié) ou, sans session, l'adresse IP de la requête. On ne garde
--   que l'empreinte SHA-256 de cette clé, dans `envois_signalements`, et la
--   ligne est effacée une heure après (ménage à chaque envoi).
-- * Pour la lecture des leçons et le suivi, rien ne change.

-- ---------------------------------------------------------------------------
-- Signalements
-- ---------------------------------------------------------------------------

create table public.signalements (
  id bigint generated always as identity primary key,
  lecon_id bigint not null references public.lecons(id) on delete cascade,
  -- Vide : le signalement porte sur la leçon elle-même.
  exercice_id bigint references public.exercices(id) on delete cascade,
  motif text not null check (motif in ('faute', 'corrige_faux', 'pas_comme_cahier', 'autre')),
  precision_texte text check (precision_texte is null or char_length(precision_texte) between 1 and 500),
  etat text not null default 'nouveau' check (etat in ('nouveau', 'traite', 'ecarte')),
  recu_le timestamptz not null default now(),
  -- Rempli quand un rédacteur le traite ou l'écarte.
  traite_le timestamptz,
  traite_par uuid references auth.users(id) on delete set null,
  constraint signalements_traitement check ((etat = 'nouveau') = (traite_le is null))
);

comment on table public.signalements is
  'Erreurs signalées par les lecteurs (D35). Aucune identité. Lues et traitées par les rédacteurs seulement.';

create index signalements_lecon_idx on public.signalements(lecon_id);
create index signalements_exercice_idx on public.signalements(exercice_id);
-- L'écran des rédacteurs ne montre que les signalements à traiter.
create index signalements_nouveaux_idx on public.signalements(recu_le desc) where etat = 'nouveau';

alter table public.signalements enable row level security;

create policy "redacteur lit les signalements" on public.signalements
  for select to authenticated using (public.est_redacteur());

-- Écriture seulement par les fonctions ci-dessous.
revoke all on public.signalements from anon;
revoke insert, update, delete, truncate on public.signalements from authenticated;

-- ---------------------------------------------------------------------------
-- Compteurs d'envois (limite contre l'envoi en masse)
-- ---------------------------------------------------------------------------

create table public.envois_signalements (
  -- Empreinte SHA-256 de « compte:<uuid> » ou « ip:<adresse> ».
  cle bytea primary key,
  nombre smallint not null default 0,
  depuis timestamptz not null default now()
);

comment on table public.envois_signalements is
  'Nombre de signalements par envoyeur sur l''heure en cours (empreinte seulement, effacée après une heure).';

-- Aucune règle : seule la fonction y accède.
alter table public.envois_signalements enable row level security;
revoke all on public.envois_signalements from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Envoyer un signalement (tout le monde)
-- ---------------------------------------------------------------------------

create function public.signaler_erreur(
  p_lecon_id bigint,
  p_exercice_id bigint,
  p_motif text,
  p_precision text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_entetes jsonb := coalesce(nullif(current_setting('request.headers', true), ''), '{}')::jsonb;
  v_ip text;
  v_cle bytea;
  v_nombre smallint;
  v_precision text := nullif(btrim(coalesce(p_precision, '')), '');
begin
  -- Contenu signalé : seulement une leçon publiée, et un exercice de cette
  -- leçon. Même filtre que l'application (statut = 'publiee').
  if not exists (select 1 from public.lecons l where l.id = p_lecon_id and l.statut = 'publiee') then
    raise exception 'Cette leçon n''existe pas.' using errcode = 'P0002';
  end if;
  if p_exercice_id is not null
     and not exists (select 1 from public.exercices x where x.id = p_exercice_id and x.lecon_id = p_lecon_id) then
    raise exception 'Cet exercice n''appartient pas à cette leçon.' using errcode = 'P0002';
  end if;
  if p_motif is null or p_motif not in ('faute', 'corrige_faux', 'pas_comme_cahier', 'autre') then
    raise exception 'Motif inconnu.' using errcode = '22023';
  end if;
  if char_length(v_precision) > 500 then
    raise exception 'La précision ne doit pas dépasser 500 caractères.' using errcode = '22023';
  end if;

  -- Envoyeur : la session si elle existe, sinon l'adresse IP (Cloudflare
  -- donne cf-connecting-ip ; sinon la première adresse de x-forwarded-for).
  -- Sans aucune des deux, tous partagent la même clé « ip:inconnue ».
  if (select auth.uid()) is not null then
    v_cle := extensions.digest('compte:' || (select auth.uid())::text, 'sha256');
  else
    v_ip := coalesce(
      nullif(btrim(v_entetes ->> 'cf-connecting-ip'), ''),
      nullif(btrim(split_part(v_entetes ->> 'x-forwarded-for', ',', 1)), ''),
      'inconnue'
    );
    v_cle := extensions.digest('ip:' || v_ip, 'sha256');
  end if;

  -- Ménage : compteurs de plus d'une heure.
  delete from public.envois_signalements e where e.depuis < now() - interval '1 hour';

  -- Plafond global : 100 signalements par heure, tous envoyeurs confondus.
  if (select count(*) from public.signalements s where s.recu_le > now() - interval '1 hour') >= 100 then
    raise exception 'Trop de signalements en ce moment. Réessaie plus tard.' using errcode = 'P0001';
  end if;

  -- 5 par heure et par envoyeur.
  insert into public.envois_signalements (cle) values (v_cle) on conflict (cle) do nothing;
  select e.nombre into v_nombre from public.envois_signalements e where e.cle = v_cle for update;
  if v_nombre >= 5 then
    raise exception 'Tu as déjà envoyé plusieurs signalements. Réessaie dans une heure.' using errcode = 'P0001';
  end if;
  update public.envois_signalements set nombre = nombre + 1 where cle = v_cle;

  insert into public.signalements (lecon_id, exercice_id, motif, precision_texte)
  values (p_lecon_id, p_exercice_id, p_motif, v_precision);
end;
$$;

revoke execute on function public.signaler_erreur(bigint, bigint, text, text) from public;
grant execute on function public.signaler_erreur(bigint, bigint, text, text) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Traiter un signalement (rédacteurs)
-- ---------------------------------------------------------------------------

-- `traite` : l'erreur est corrigée (ou une correction est demandée) ;
-- `ecarte` : pas d'erreur ; `nouveau` : annuler un traitement par erreur.
create function public.traiter_signalement(p_id bigint, p_etat text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not public.est_redacteur() then
    raise exception 'Seul un rédacteur peut traiter un signalement.' using errcode = '42501';
  end if;
  if p_etat is null or p_etat not in ('nouveau', 'traite', 'ecarte') then
    raise exception 'État inconnu.' using errcode = '22023';
  end if;

  update public.signalements s
  set etat = p_etat,
      traite_le = case when p_etat = 'nouveau' then null else now() end,
      traite_par = case when p_etat = 'nouveau' then null else (select auth.uid()) end
  where s.id = p_id;

  if not found then
    raise exception 'Ce signalement n''existe pas.' using errcode = 'P0002';
  end if;
end;
$$;

revoke execute on function public.traiter_signalement(bigint, text) from public, anon;
grant execute on function public.traiter_signalement(bigint, text) to authenticated;

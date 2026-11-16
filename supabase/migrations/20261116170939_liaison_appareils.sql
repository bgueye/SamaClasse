-- Phase 5 : lier le téléphone d'un enfant à son profil par un code donné
-- par le parent (D32). L'enfant n'a jamais le compte de son parent.
--
-- Déroulé :
--   1. Sur son téléphone, le parent connecté demande un code pour Awa
--      (`creer_code_liaison`) : 6 chiffres, valable 10 minutes, à usage
--      unique.
--   2. Sur le téléphone d'Awa, l'application ouvre une session Supabase
--      anonyme (aucun e-mail, aucune donnée personnelle), puis donne le code
--      (`utiliser_code_liaison`). Le téléphone est lié au profil d'Awa
--      (table `appareils`).
--   3. Ce téléphone envoie alors les leçons lues et les résultats d'Awa, et
--      ne peut rien faire d'autre. Le parent voit le suivi sur son propre
--      téléphone, comme aujourd'hui.
--   4. Le parent délie un téléphone (`delier_appareil`) : la session anonyme
--      est supprimée, le téléphone ne peut plus rien envoyer.
--
-- Effet sur la sécurité :
-- * Session anonyme = rôle `authenticated` avec `is_anonymous = true` dans
--   le jeton. Sans précaution, elle pourrait créer des profils enfants comme
--   un parent : des règles RESTRICTIVES l'interdisent (ajout, modification,
--   suppression de profils). Les autres écritures possibles pour un compte
--   connecté demandent déjà le rôle rédacteur (vérifié dans les règles et
--   les fonctions), qu'une session anonyme n'a jamais.
-- * Un téléphone lié lit seulement le prénom et la classe de SON enfant, et
--   les leçons lues et résultats de cet enfant (nécessaire à l'envoi en
--   « upsert ») ; il écrit seulement pour cet enfant, sur du contenu publié.
--   Il ne voit ni les autres profils, ni le compte du parent.
-- * Le parent voit les téléphones liés à ses enfants et peut les délier.
-- * Codes : 6 chiffres, 10 minutes, usage unique, gardés seulement sous
--   forme d'empreinte (SHA-256). Un téléphone a droit à 5 essais par heure ;
--   la création de sessions anonymes est elle-même limitée par Supabase
--   (30 par heure et par adresse IP par défaut). 3 téléphones au plus par
--   enfant.
-- * Pour les parents, les élèves sans compte et les rédacteurs : rien ne
--   change.
--
-- À faire dans le tableau de bord avant d'utiliser l'application : activer
-- « Allow anonymous sign-ins » (Authentication › Sign In / Providers).

-- ---------------------------------------------------------------------------
-- Session anonyme (téléphone d'enfant)
-- ---------------------------------------------------------------------------

-- Vrai pour une session anonyme. `(select auth.jwt())` : évalué une fois
-- par requête.
create function public.est_anonyme()
returns boolean
language sql stable
set search_path = ''
as $$
  select coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false);
$$;

revoke execute on function public.est_anonyme() from public, anon;
grant execute on function public.est_anonyme() to authenticated;

-- Une session anonyme ne gère pas de profils enfants. Règles restrictives :
-- elles s'ajoutent (ET) aux règles des parents, qui ne changent pas.
create policy "pas de profils pour une session anonyme (ajout)" on public.enfants
  as restrictive for insert to authenticated with check (not public.est_anonyme());
create policy "pas de profils pour une session anonyme (modification)" on public.enfants
  as restrictive for update to authenticated using (not public.est_anonyme());
create policy "pas de profils pour une session anonyme (suppression)" on public.enfants
  as restrictive for delete to authenticated using (not public.est_anonyme());

-- ---------------------------------------------------------------------------
-- Téléphones liés
-- ---------------------------------------------------------------------------

create table public.appareils (
  -- La session anonyme du téléphone : la supprimer délie le téléphone.
  id uuid primary key references auth.users(id) on delete cascade,
  enfant_id bigint not null references public.enfants(id) on delete cascade,
  -- Type d'appareil donné par l'application (« Android », « iPhone »,
  -- « Navigateur ») pour que le parent s'y retrouve ; rien de plus précis.
  appareil text check (appareil is null or char_length(appareil) <= 40),
  lie_le timestamptz not null default now()
);

comment on table public.appareils is
  'Téléphones d''enfants liés à un profil par un code du parent (D32). Aucune donnée personnelle.';

create index appareils_enfant_idx on public.appareils(enfant_id);

alter table public.appareils enable row level security;

create policy "parent voit les appareils de ses enfants" on public.appareils
  for select to authenticated
  using (exists (select 1 from public.enfants e where e.id = enfant_id and e.parent_id = (select auth.uid())));
create policy "appareil se voit lui-meme" on public.appareils
  for select to authenticated using (id = (select auth.uid()));

-- Écriture seulement par les fonctions ci-dessous.
revoke all on public.appareils from anon;
revoke insert, update, delete, truncate on public.appareils from authenticated;

-- Enfant du téléphone connecté (null pour un parent ou un téléphone non
-- lié). security definer : lit `appareils` sans dépendre de ses règles, ce
-- qui évite une boucle entre les règles de `enfants` et d'`appareils`.
create function public.enfant_de_cet_appareil()
returns bigint
language sql stable
security definer
set search_path = ''
as $$
  select a.enfant_id from public.appareils a where a.id = (select auth.uid());
$$;

revoke execute on function public.enfant_de_cet_appareil() from public, anon;
grant execute on function public.enfant_de_cet_appareil() to authenticated;

-- Le téléphone lié lit le prénom et la classe de son enfant (accueil
-- « Bonjour Awa ! », classe affichée), et rien d'autre.
create policy "appareil lit son enfant" on public.enfants
  for select to authenticated using (id = (select public.enfant_de_cet_appareil()));

-- Lectures et résultats : le téléphone lié écrit pour son enfant seulement,
-- sur du contenu visible (publié). Il relit ces lignes : l'envoi en
-- « upsert » des lectures en a besoin.
create policy "appareil lit les lectures de son enfant" on public.lectures
  for select to authenticated using (enfant_id = (select public.enfant_de_cet_appareil()));
create policy "appareil enregistre les lectures de son enfant" on public.lectures
  for insert to authenticated
  with check (
    enfant_id = (select public.enfant_de_cet_appareil())
    and exists (select 1 from public.lecons l where l.id = lecon_id)
  );
create policy "appareil met a jour les lectures de son enfant" on public.lectures
  for update to authenticated
  using (enfant_id = (select public.enfant_de_cet_appareil()))
  with check (enfant_id = (select public.enfant_de_cet_appareil()));

create policy "appareil lit les resultats de son enfant" on public.resultats
  for select to authenticated using (enfant_id = (select public.enfant_de_cet_appareil()));
create policy "appareil enregistre les resultats de son enfant" on public.resultats
  for insert to authenticated
  with check (
    enfant_id = (select public.enfant_de_cet_appareil())
    and exists (select 1 from public.exercices x where x.id = exercice_id)
  );

-- ---------------------------------------------------------------------------
-- Codes de liaison
-- ---------------------------------------------------------------------------

-- Un code actif au plus par enfant (en demander un nouveau remplace
-- l'ancien). Seule l'empreinte est gardée.
create table public.codes_liaison (
  enfant_id bigint primary key references public.enfants(id) on delete cascade,
  empreinte bytea not null,
  expire_le timestamptz not null
);

comment on table public.codes_liaison is
  'Codes de liaison en cours (empreinte SHA-256, 10 minutes, usage unique, D32).';

create index codes_liaison_empreinte_idx on public.codes_liaison(empreinte);

-- Essais de code par téléphone (5 par heure).
create table public.essais_liaison (
  appareil uuid primary key references auth.users(id) on delete cascade,
  nombre smallint not null default 0,
  depuis timestamptz not null default now()
);

-- Aucune règle : seules les fonctions y accèdent.
alter table public.codes_liaison enable row level security;
alter table public.essais_liaison enable row level security;
revoke all on public.codes_liaison from anon, authenticated;
revoke all on public.essais_liaison from anon, authenticated;

-- Le parent demande un code pour un de SES enfants.
create function public.creer_code_liaison(p_enfant_id bigint)
returns table (code text, expire_le timestamptz)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
  v_expire timestamptz := now() + interval '10 minutes';
  v_essai int := 0;
begin
  if (select auth.uid()) is null or public.est_anonyme() then
    raise exception 'Connectez-vous avec votre compte parent.' using errcode = '42501';
  end if;
  if not exists (select 1 from public.enfants e where e.id = p_enfant_id and e.parent_id = (select auth.uid())) then
    raise exception 'Ce profil n''est pas le vôtre.' using errcode = '42501';
  end if;
  if (select count(*) from public.appareils a where a.enfant_id = p_enfant_id) >= 3 then
    raise exception 'Ce profil a déjà 3 téléphones liés : déliez-en un d''abord.' using errcode = 'P0001';
  end if;

  -- Ménage : codes expirés.
  delete from public.codes_liaison c where c.expire_le < now();

  -- 6 chiffres tirés au hasard (générateur cryptographique), sans doublon
  -- parmi les codes en cours.
  loop
    v_code := lpad(((('x' || encode(extensions.gen_random_bytes(4), 'hex'))::bit(32)::bigint) % 1000000)::text, 6, '0');
    exit when not exists (
      select 1 from public.codes_liaison c
      where c.empreinte = extensions.digest(v_code, 'sha256') and c.enfant_id <> p_enfant_id
    );
    v_essai := v_essai + 1;
    if v_essai > 20 then
      raise exception 'Réessayez dans un instant.' using errcode = 'P0001';
    end if;
  end loop;

  insert into public.codes_liaison (enfant_id, empreinte, expire_le)
  values (p_enfant_id, extensions.digest(v_code, 'sha256'), v_expire)
  on conflict (enfant_id) do update set empreinte = excluded.empreinte, expire_le = excluded.expire_le;

  return query select v_code, v_expire;
end;
$$;

revoke execute on function public.creer_code_liaison(bigint) from public, anon;
grant execute on function public.creer_code_liaison(bigint) to authenticated;

-- Le téléphone de l'enfant (session anonyme) donne le code. Rend un objet
-- JSON plutôt qu'une erreur pour un mauvais code : une erreur annulerait le
-- décompte des essais.
--   { "lie": true, "enfant_id": 12, "prenom": "Awa", "classe_id": 1 }
--   { "lie": false, "essais_restants": 3 }
create function public.utiliser_code_liaison(p_code text, p_appareil text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_moi uuid := (select auth.uid());
  v_essais public.essais_liaison%rowtype;
  v_enfant public.enfants%rowtype;
  v_code text := regexp_replace(coalesce(p_code, ''), '\s', '', 'g');
begin
  if v_moi is null or not public.est_anonyme() then
    raise exception 'Seul le téléphone d''un enfant (session anonyme) peut utiliser un code.' using errcode = '42501';
  end if;

  -- Essais : 5 par heure et par téléphone.
  insert into public.essais_liaison (appareil) values (v_moi) on conflict (appareil) do nothing;
  select * into v_essais from public.essais_liaison where appareil = v_moi for update;
  if v_essais.depuis < now() - interval '1 hour' then
    update public.essais_liaison set nombre = 0, depuis = now() where appareil = v_moi;
    v_essais.nombre := 0;
  end if;
  if v_essais.nombre >= 5 then
    raise exception 'Trop d''essais. Réessaie dans une heure.' using errcode = 'P0001';
  end if;

  select e.* into v_enfant
  from public.codes_liaison c join public.enfants e on e.id = c.enfant_id
  where v_code ~ '^[0-9]{6}$'
    and c.empreinte = extensions.digest(v_code, 'sha256')
    and c.expire_le >= now()
  for update of c;

  if not found then
    update public.essais_liaison set nombre = nombre + 1 where appareil = v_moi;
    return jsonb_build_object('lie', false, 'essais_restants', 4 - v_essais.nombre);
  end if;

  if (select count(*) from public.appareils a where a.enfant_id = v_enfant.id and a.id <> v_moi) >= 3 then
    raise exception 'Ce profil a déjà 3 téléphones liés : ton parent doit en délier un.' using errcode = 'P0001';
  end if;

  -- Code bon : usage unique, et le téléphone passe à ce profil (s'il était
  -- lié à un autre, il le quitte).
  delete from public.codes_liaison where enfant_id = v_enfant.id;
  delete from public.essais_liaison where appareil = v_moi;
  insert into public.appareils (id, enfant_id, appareil)
  values (v_moi, v_enfant.id, nullif(left(btrim(coalesce(p_appareil, '')), 40), ''))
  on conflict (id) do update set enfant_id = excluded.enfant_id, appareil = excluded.appareil, lie_le = now();

  return jsonb_build_object('lie', true, 'enfant_id', v_enfant.id, 'prenom', v_enfant.prenom, 'classe_id', v_enfant.classe_id);
end;
$$;

revoke execute on function public.utiliser_code_liaison(text, text) from public, anon;
grant execute on function public.utiliser_code_liaison(text, text) to authenticated;

-- Le parent délie un téléphone d'un de ses enfants : la session anonyme du
-- téléphone est supprimée (et sa ligne d'`appareils` avec elle). Les leçons
-- lues et résultats déjà envoyés restent dans le suivi de l'enfant.
create function public.delier_appareil(p_appareil uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or public.est_anonyme() then
    raise exception 'Connectez-vous avec votre compte parent.' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.appareils a join public.enfants e on e.id = a.enfant_id
    where a.id = p_appareil and e.parent_id = (select auth.uid())
  ) then
    raise exception 'Ce téléphone n''est pas lié à l''un de vos enfants.' using errcode = 'P0002';
  end if;
  -- Par sécurité, on ne supprime jamais qu'un compte anonyme.
  delete from auth.users u where u.id = p_appareil and u.is_anonymous;
end;
$$;

revoke execute on function public.delier_appareil(uuid) from public, anon;
grant execute on function public.delier_appareil(uuid) to authenticated;

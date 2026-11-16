-- Sécurité supplémentaire (D32) : une session anonyme (téléphone d'enfant
-- lié par un code) n'est jamais rédactrice, même si son identifiant se
-- retrouvait par erreur dans `redacteurs`. Toutes les règles et fonctions
-- réservées aux rédacteurs passent par `est_redacteur()` : elles sont
-- toutes couvertes d'un coup.
--
-- `create or replace` garde la même signature et les mêmes droits
-- (authenticated seulement).
create or replace function public.est_redacteur()
returns boolean
language sql stable
set search_path = ''
as $$
  select not public.est_anonyme()
     and exists (select 1 from public.redacteurs r where r.id = (select auth.uid()));
$$;

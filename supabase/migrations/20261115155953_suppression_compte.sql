-- Phase 5 : suppression du compte par son titulaire (exigée par Google Play
-- pour toute application qui permet de créer un compte).
--
-- Le parent connecté supprime SON compte, et lui seul. Effets, par les clés
-- étrangères déjà en place :
-- * profils enfants supprimés (enfants.parent_id, on delete cascade), donc
--   leurs leçons lues et leurs résultats (lectures, resultats : cascade) ;
-- * rôle rédacteur retiré (redacteurs.id : cascade) ;
-- * historique de validation gardé, mais anonymisé : points_leves.leve_par et
--   lecons.publiee_par passent à vide (on delete set null). La leçon reste
--   publiée et l'on sait encore quand chaque point a été levé ;
-- * sessions et identités de Supabase Auth supprimées avec le compte.
-- Le contenu pédagogique n'est pas touché.

-- security definer : indispensable, car seul le propriétaire de la base peut
-- supprimer une ligne de auth.users. La fonction ne prend aucun paramètre :
-- elle ne peut viser que le compte de la session (auth.uid()).
create function public.supprimer_mon_compte()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := (select auth.uid());
begin
  if v_id is null then
    raise exception 'Aucun compte connecté.' using errcode = '42501';
  end if;
  delete from auth.users where id = v_id;
end;
$$;

revoke execute on function public.supprimer_mon_compte() from public, anon;
grant execute on function public.supprimer_mon_compte() to authenticated;

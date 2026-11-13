-- Matières d'une classe avec le nombre de chapitres et de leçons publiées.
-- security_invoker : la vue applique les règles RLS de la personne qui lit.
create view public.matieres_par_classe
with (security_invoker = true) as
select
  c.id   as classe_id,
  m.id   as matiere_id,
  m.slug,
  m.nom,
  count(distinct ch.id) as nb_chapitres,
  count(distinct l.id) filter (where l.statut = 'publiee') as nb_lecons
from public.chapitres ch
join public.classes  c on c.id = ch.classe_id
join public.matieres m on m.id = ch.matiere_id
left join public.lecons l on l.chapitre_id = ch.id
group by c.id, m.id, m.slug, m.nom;

grant select on public.matieres_par_classe to anon, authenticated;

create index if not exists lecons_chapitre_idx on public.lecons(chapitre_id);
create index if not exists chapitres_classe_matiere_idx on public.chapitres(classe_id, matiere_id, numero);

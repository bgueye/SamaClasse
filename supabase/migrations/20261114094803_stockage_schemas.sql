-- Espace de stockage public des schémas des leçons (décision D15).
--
-- Les images sont insérées dans le Markdown des leçons et des exercices :
--   ![Description lue par les lecteurs d'écran](https://<projet>.supabase.co/storage/v1/object/public/schemas/<chemin>)
-- Bocar les dépose par le tableau de bord Supabase.
--
-- Effet sur la sécurité :
-- * « public = true » : chaque fichier se télécharge par son adresse publique
--   (/storage/v1/object/public/schemas/…), sans clé et sans règle RLS. C'est
--   ce qu'il faut pour un téléphone non connecté à un compte.
-- * Aucune politique n'est ajoutée sur storage.objects : avec la clé
--   publishable (rôles anon et authenticated), on ne peut ni lister le
--   contenu de l'espace, ni déposer, ni remplacer, ni supprimer un fichier.
--   Une politique « select » n'est pas nécessaire pour lire un espace public ;
--   elle ne servirait qu'à permettre de lister tous les fichiers.
-- * Le tableau de bord agit avec les droits d'administration : le dépôt par
--   Bocar fonctionne sans politique d'écriture.
-- * Garde-fous côté serveur : 150 Ko maximum par fichier (chargement en 3G),
--   formats PNG, JPEG et WebP seulement. Le SVG est exclu : l'application ne
--   sait pas l'afficher sans nouvelle dépendance, et un SVG peut contenir du
--   script, ce qui est risqué sur le web.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'schemas',
  'schemas',
  true,
  153600, -- 150 Ko (150 × 1 024 octets)
  array['image/png', 'image/jpeg', 'image/webp']
);

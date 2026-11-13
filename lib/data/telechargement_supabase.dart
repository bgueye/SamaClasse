// Téléchargement de tout le contenu publié depuis Supabase, en quatre
// requêtes lancées ensemble (environ 50 Ko au 13/11/2026).
//
// Colonnes nommées une à une plutôt que `*` : les données de rédaction
// (`chapitres.remarque`, `lecons.points_a_verifier`, `lecons.artefact_url`)
// ne sont ni téléchargées ni gardées sur les téléphones des élèves
// (BASE_DE_DONNEES.md, « Données de travail interdites à l'affichage »).
//
// Limite : PostgREST renvoie au plus 1 000 lignes par requête (réglage par
// défaut de Supabase). Il y a 192 chapitres pour deux classes ; avant
// d'approcher la limite (tout le cursus), passer à une synchronisation par
// classe.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'instantane.dart';

/// Source du contenu complet. Interface pour pouvoir la remplacer dans les tests.
abstract interface class SourceContenu {
  Future<Instantane> telechargerTout();
}

class TelechargementSupabase implements SourceContenu {
  TelechargementSupabase(this._db);

  final SupabaseClient _db;

  static const _colonnesExercice = 'id, ordre, niveau, type, enonce, donnees, reponse, corrige';

  @override
  Future<Instantane> telechargerTout() async {
    // Future.wait plutôt que `(…).wait` : en cas d'échec, on récupère l'erreur
    // d'origine (réseau, RLS…) et non une ParallelWaitError qui la cache.
    final resultats = await Future.wait<List<Map<String, dynamic>>>([
      _db.from('classes').select('id, code, libelle, cycle, ordre').order('ordre'),
      _db
          .from('matieres_par_classe')
          .select('classe_id, matiere_id, slug, nom, nb_chapitres, nb_lecons')
          .order('nom'),
      _db
          .from('chapitres')
          .select('id, classe_id, matiere_id, numero, titre, partie, statut, '
              'lecons(id, numero, titre, exercices(count))')
          .order('numero')
          .order('numero', referencedTable: 'lecons'),
      // Les règles RLS ne renvoient que les leçons publiées.
      _db
          .from('lecons')
          .select('id, chapitre_id, numero, titre, date_cours, objectifs, introduction, corps, '
              'a_retenir, statut, exercices($_colonnesExercice), '
              'chapitres(titre, partie, classes(libelle), matieres(nom, slug))')
          .order('ordre', referencedTable: 'exercices'),
    ]);

    return Instantane(
      classesBrutes: resultats[0],
      matieresBrutes: resultats[1],
      chapitresBruts: resultats[2],
      leconsBrutes: resultats[3],
    );
  }
}

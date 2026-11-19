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
              'lecons(id, numero, titre, statut, exercices(count))')
          // Leçons publiées seulement, même pour un rédacteur connecté (qui
          // peut lire les autres depuis la phase 4).
          .eq('lecons.statut', 'publiee')
          .order('numero')
          .order('numero', referencedTable: 'lecons'),
      // Filtre explicite : les règles RLS laissent un rédacteur connecté
      // lire aussi les leçons non publiées (phase 4).
      _db
          .from('lecons')
          .select('id, chapitre_id, numero, titre, date_cours, objectifs, introduction, corps, '
              // script_audio : « Écouter la leçon », gardé hors connexion
              // avec le reste de la leçon (lignes brutes de l'Instantane).
              'a_retenir, script_audio, statut, exercices($_colonnesExercice), '
              'chapitres(titre, partie, classes(libelle), matieres(nom, slug))')
          .eq('statut', 'publiee')
          .order('ordre', referencedTable: 'exercices'),
    ]);

    // Second garde-fou côté téléphone (voir Instantane.seulementPublie).
    return Instantane(
      classesBrutes: resultats[0],
      matieresBrutes: resultats[1],
      chapitresBruts: resultats[2],
      leconsBrutes: resultats[3],
    ).seulementPublie();
  }
}

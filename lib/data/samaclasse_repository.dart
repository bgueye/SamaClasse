// Accès aux données SamaClasse dans Supabase.
//
// Lecture seule : les élèves et les parents lisent le programme et les
// leçons publiées. Les règles RLS de la base masquent automatiquement les
// leçons au statut « brouillon » ou « à vérifier ».

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

class SamaClasseRepository {
  SamaClasseRepository(this._db);

  final SupabaseClient _db;

  /// Toutes les classes, dans l'ordre du cursus.
  Future<List<Classe>> classes() async {
    final lignes = await _db
        .from('classes')
        .select('id, code, libelle, cycle, ordre')
        .order('ordre');
    return lignes.map(Classe.fromJson).toList();
  }

  /// Les matières d'une classe, avec le nombre de chapitres et de leçons publiées.
  Future<List<MatiereDeClasse>> matieres(int classeId) async {
    final lignes = await _db
        .from('matieres_par_classe')
        .select()
        .eq('classe_id', classeId)
        .order('nom');
    return lignes.map(MatiereDeClasse.fromJson).toList();
  }

  /// Les chapitres d'une matière dans une classe, dans l'ordre du programme,
  /// chacun avec ses leçons publiées et leur nombre d'exercices.
  Future<List<Chapitre>> chapitres({required int classeId, required int matiereId}) async {
    final lignes = await _db
        .from('chapitres')
        .select('id, numero, titre, partie, statut, remarque, lecons(id, numero, titre, exercices(count))')
        .eq('classe_id', classeId)
        .eq('matiere_id', matiereId)
        .order('numero')
        .order('numero', referencedTable: 'lecons');
    return lignes.map(Chapitre.fromJson).toList();
  }

  /// Une leçon complète avec ses exercices, ou `null` si elle n'existe pas
  /// ou n'est pas encore publiée.
  Future<Lecon?> lecon(int id) async {
    final ligne = await _db
        .from('lecons')
        .select('*, exercices(*), chapitres(titre, partie, classes(libelle), matieres(nom, slug))')
        .eq('id', id)
        .order('ordre', referencedTable: 'exercices')
        .maybeSingle();
    return ligne == null ? null : Lecon.fromJson(ligne);
  }
}

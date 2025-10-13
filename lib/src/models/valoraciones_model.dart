import 'package:supabase_flutter/supabase_flutter.dart';

class ValoracionService {
  final supabase = Supabase.instance.client;

  /// Crear una valoración
  Future<void> agregarValoracion({
    required String profesorId,
    required int puntaje,
    String? comentario,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw Exception("Usuario no autenticado");

    await supabase.from('valoraciones').insert({
      'profesor_id': profesorId,
      'estudiante_id': userId,
      'puntaje': puntaje,
      'comentario': comentario ?? '',
    });
  }

  /// Obtener valoraciones de un profesor
  Future<List<Map<String, dynamic>>> obtenerValoraciones(String profesorId) async {
    final data = await supabase
        .from('valoraciones')
        .select('puntaje, comentario, created_at, estudiante_id')
        .eq('profesor_id', profesorId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Obtener promedio del profesor
  Future<double> obtenerPromedio(String profesorId) async {
    final data = await supabase
        .from('valoraciones')
        .select('puntaje')
        .eq('profesor_id', profesorId);

    if (data.isEmpty) return 0.0;

    final puntajes = data.map((v) => (v['puntaje'] ?? 0) as int).toList();
    final promedio = puntajes.reduce((a, b) => a + b) / puntajes.length;
    return double.parse(promedio.toStringAsFixed(1));
  }
}

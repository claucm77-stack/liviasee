import 'package:flutter_test/flutter_test.dart';
import 'package:micronegocios_app/data/models/content_model.dart';
import 'package:micronegocios_app/domain/entities/content.dart';

void main() {
  test('preserva evento y nombre visible del autor', () {
    final content = ContentModel.fromMap('event-1', const {
      'titulo': 'Taller',
      'descripcion': 'Evento del cronograma',
      'tipo': 'evento',
      'url': '',
      'imagen': '',
      'categoria': 'Cronograma Actividades',
      'autorId': 'firebase-123',
      'autorNombre': 'María Pérez',
      'metadata': {
        'starts_at': '2026-07-30T09:00:00-05:00',
        'location': 'Auditorio',
      },
      'fechaCreacion': '2026-07-27T10:00:00Z',
      'estado': 'activo',
    });

    expect(content.tipo, ContentType.evento);
    expect(content.autorId, 'firebase-123');
    expect(content.autorNombre, 'María Pérez');
    expect(content.metadata['location'], 'Auditorio');
    expect(content.toMap()['autorNombre'], 'María Pérez');
  });
}

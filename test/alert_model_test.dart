import 'package:flutter_test/flutter_test.dart';
import 'package:micronegocios_app/data/models/alert_model.dart';

void main() {
  test('convierte el contrato de alertas entre Laravel y Flutter', () {
    final alert = AlertModel.fromMap(const {
      'id': '12',
      'source': 'DIAN',
      'title': 'Calendario tributario',
      'description': 'Fechas oficiales',
      'linkUrl': 'https://example.com',
      'sortOrder': 8,
      'isActive': true,
    });

    expect(alert.id, '12');
    expect(alert.source, 'DIAN');
    expect(alert.isActive, isTrue);
    expect(alert.toMap()['id'], 12);
    expect(alert.toMap()['sortOrder'], 8);
  });
}

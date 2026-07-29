import 'package:flutter_test/flutter_test.dart';
import 'package:micronegocios_app/data/models/app_user_model.dart';

void main() {
  test('conserva el estado obligatorio del registro de micronegocio', () {
    final incomplete = AppUserModel.fromMap(const {
      'uid': 'firebase-user',
      'name': 'Nuevo usuario',
      'email': 'nuevo@example.com',
      'role': 'microempresario',
      'has_microbusiness': false,
    });

    expect(incomplete.hasMicrobusiness, isFalse);

    final complete = incomplete.copyWith(hasMicrobusiness: true);
    expect(complete.hasMicrobusiness, isTrue);
  });
}

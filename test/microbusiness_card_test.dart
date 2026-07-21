import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:micronegocios_app/domain/entities/microbusiness.dart';
import 'package:micronegocios_app/presentation/widgets/microbusiness/microbusiness_card.dart';

void main() {
  testWidgets('muestra estrellas y cantidad de calificaciones', (tester) async {
    final business = Microbusiness(
      id: 'business-1',
      nombre: 'Negocio calificado',
      descripcion: 'Descripción',
      categoria: 'Servicios',
      direccion: 'Bogotá',
      latitud: 4.7,
      longitud: -74.0,
      imagen: '',
      propietarioId: 'owner-1',
      contacto: '3000000000',
      horario: '8:00 a 17:00',
      estado: MicrobusinessStatus.activo,
      fechaCreacion: DateTime(2026),
      ratingPromedio: 4.3,
      totalCalificaciones: 7,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MicrobusinessCard(
            business: business,
            onTap: () {},
            onHowToGet: () {},
            onToggleFavorite: () {},
            isFavorite: false,
          ),
        ),
      ),
    );

    expect(find.text('4.3 · 7 calificaciones'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.byIcon(Icons.star_half), findsOneWidget);
  });
}

import 'package:cloud_firestore/cloud_firestore.dart';

class LogModel {
  final String id;
  final String usuarioId;
  final String accion;
  final String modulo;
  final DateTime fecha;
  final String origen;
  final String detalle;

  const LogModel({
    required this.id,
    required this.usuarioId,
    required this.accion,
    required this.modulo,
    required this.fecha,
    required this.origen,
    this.detalle = '',
  });

  factory LogModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final rawFecha = data['fecha'];
    DateTime parsedFecha = DateTime.now();

    if (rawFecha is Timestamp) {
      parsedFecha = rawFecha.toDate();
    } else if (rawFecha is String) {
      parsedFecha = DateTime.tryParse(rawFecha) ?? DateTime.now();
    }

    return LogModel(
      id: id,
      usuarioId: (data['usuarioId'] ?? '').toString(),
      accion: (data['accion'] ?? '').toString(),
      modulo: (data['modulo'] ?? '').toString(),
      fecha: parsedFecha,
      origen: (data['origen'] ?? 'mobile').toString(),
      detalle: (data['detalle'] ?? '').toString(),
    );
  }

  factory LogModel.fromMap(Map<String, dynamic> data) {
    final rawDate = data['fecha'] ?? data['createdAt'] ?? data['created_at'];
    return LogModel(
      id: (data['id'] ?? '').toString(),
      usuarioId: (data['usuarioId'] ?? data['user_id'] ?? '').toString(),
      accion: (data['accion'] ?? data['action'] ?? '').toString(),
      modulo: (data['modulo'] ?? data['module'] ?? '').toString(),
      fecha: rawDate is String
          ? DateTime.tryParse(rawDate) ?? DateTime.now()
          : DateTime.now(),
      origen: (data['origen'] ?? data['origin'] ?? 'laravel').toString(),
      detalle: (data['detalle'] ?? data['description'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'accion': accion,
      'modulo': modulo,
      'fecha': Timestamp.fromDate(fecha),
      'origen': origen,
      'detalle': detalle,
    };
  }
}

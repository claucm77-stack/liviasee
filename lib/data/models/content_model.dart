import '../../domain/entities/content.dart';

class ContentModel extends Content {
  const ContentModel({
    required super.id,
    required super.titulo,
    required super.descripcion,
    required super.tipo,
    required super.url,
    super.contenido,
    required super.imagen,
    required super.categoria,
    required super.autorId,
    super.autorNombre,
    super.metadata,
    required super.fechaCreacion,
    required super.estado,
    super.destacado,
    super.favoritos,
    super.vistos,
  });

  factory ContentModel.fromMap(String id, Map<String, dynamic> map) {
    return ContentModel(
      id: id,
      titulo: (map['titulo'] ?? '') as String,
      descripcion: (map['descripcion'] ?? '') as String,
      tipo: _typeFromString((map['tipo'] ?? 'texto') as String),
      url: (map['url'] ?? '') as String,
      contenido: (map['contenido'] ??
              (map['metadata'] is Map ? map['metadata']['body'] : '') ??
              '')
          .toString(),
      imagen: (map['imagen'] ?? '') as String,
      categoria: (map['categoria'] ?? '') as String,
      autorId: (map['autorId'] ?? '') as String,
      autorNombre: (map['autorNombre'] ?? '') as String,
      metadata: _parseMetadata(map['metadata']),
      fechaCreacion: _parseDate(map['fechaCreacion']),
      estado: _statusFromString((map['estado'] ?? 'activo') as String),
      destacado: (map['destacado'] ?? false) as bool,
      favoritos: _parseStringList(map['favoritos']),
      vistos: _parseStringList(map['vistos']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'descripcion': descripcion,
      'tipo': tipo.name,
      'url': url,
      'contenido': contenido,
      'imagen': imagen,
      'categoria': categoria,
      'autorId': autorId,
      'autorNombre': autorNombre,
      'metadata': metadata,
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'estado': estado.name,
      'destacado': destacado,
      'favoritos': favoritos,
      'vistos': vistos,
    };
  }

  static ContentType _typeFromString(String value) {
    switch (value) {
      case 'video':
        return ContentType.video;
      case 'pdf':
        return ContentType.pdf;
      case 'evento':
        return ContentType.evento;
      case 'texto':
      default:
        return ContentType.texto;
    }
  }

  static ContentStatus _statusFromString(String value) {
    switch (value) {
      case 'inactivo':
        return ContentStatus.inactivo;
      case 'activo':
      default:
        return ContentStatus.activo;
    }
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static Map<String, dynamic> _parseMetadata(dynamic value) {
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  factory ContentModel.fromEntity(Content content) {
    return ContentModel(
      id: content.id,
      titulo: content.titulo,
      descripcion: content.descripcion,
      tipo: content.tipo,
      url: content.url,
      contenido: content.contenido,
      imagen: content.imagen,
      categoria: content.categoria,
      autorId: content.autorId,
      autorNombre: content.autorNombre,
      metadata: content.metadata,
      fechaCreacion: content.fechaCreacion,
      estado: content.estado,
      destacado: content.destacado,
      favoritos: content.favoritos,
      vistos: content.vistos,
    );
  }
}

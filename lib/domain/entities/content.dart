import 'package:equatable/equatable.dart';

enum ContentType { video, pdf, texto, evento }

enum ContentStatus { activo, inactivo }

class Content extends Equatable {
  final String id;
  final String titulo;
  final String descripcion;
  final ContentType tipo;
  final String url;
  final String contenido;
  final String imagen;
  final String categoria;
  final String autorId;
  final String autorNombre;
  final Map<String, dynamic> metadata;
  final DateTime fechaCreacion;
  final ContentStatus estado;
  final bool destacado;
  final List<String> favoritos;
  final List<String> vistos;

  const Content({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.tipo,
    required this.url,
    this.contenido = '',
    required this.imagen,
    required this.categoria,
    required this.autorId,
    this.autorNombre = '',
    this.metadata = const {},
    required this.fechaCreacion,
    required this.estado,
    this.destacado = false,
    this.favoritos = const [],
    this.vistos = const [],
  });

  bool get isActivo => estado == ContentStatus.activo;

  bool isFavoriteFor(String userId) => favoritos.contains(userId);

  bool isViewedBy(String userId) => vistos.contains(userId);

  Uri? get externalUri {
    final uri = Uri.tryParse(url.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  bool get hasReadableDetails =>
      contenido.trim().isNotEmpty ||
      descripcion.trim().isNotEmpty ||
      (tipo == ContentType.evento &&
          metadata.values.any((value) => value.toString().trim().isNotEmpty));

  bool get hasUsableDestination {
    if (tipo == ContentType.video || tipo == ContentType.pdf) {
      return externalUri != null || hasReadableDetails;
    }
    return hasReadableDetails || externalUri != null;
  }

  Content copyWith({
    String? id,
    String? titulo,
    String? descripcion,
    ContentType? tipo,
    String? url,
    String? contenido,
    String? imagen,
    String? categoria,
    String? autorId,
    String? autorNombre,
    Map<String, dynamic>? metadata,
    DateTime? fechaCreacion,
    ContentStatus? estado,
    bool? destacado,
    List<String>? favoritos,
    List<String>? vistos,
  }) {
    return Content(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      tipo: tipo ?? this.tipo,
      url: url ?? this.url,
      contenido: contenido ?? this.contenido,
      imagen: imagen ?? this.imagen,
      categoria: categoria ?? this.categoria,
      autorId: autorId ?? this.autorId,
      autorNombre: autorNombre ?? this.autorNombre,
      metadata: metadata ?? this.metadata,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      estado: estado ?? this.estado,
      destacado: destacado ?? this.destacado,
      favoritos: favoritos ?? this.favoritos,
      vistos: vistos ?? this.vistos,
    );
  }

  @override
  List<Object?> get props => [
        id,
        titulo,
        descripcion,
        tipo,
        url,
        contenido,
        imagen,
        categoria,
        autorId,
        autorNombre,
        metadata,
        fechaCreacion,
        estado,
        destacado,
        favoritos,
        vistos,
      ];
}

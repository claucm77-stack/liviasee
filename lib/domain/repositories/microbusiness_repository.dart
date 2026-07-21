import '../entities/microbusiness.dart';

abstract class MicrobusinessRepository {
  Future<void> createMicrobusiness({
    required Microbusiness business,
    required String currentUserId,
    required String currentUserRole,
  });

  Future<void> updateMicrobusiness({
    required Microbusiness business,
    required String currentUserId,
    required String currentUserRole,
  });

  Future<void> deleteMicrobusiness({
    required String businessId,
    required String currentUserId,
    required String currentUserRole,
  });

  Future<Microbusiness?> getMicrobusinessById(String businessId);

  Stream<List<Microbusiness>> watchMicrobusinesses({
    required String currentUserRole,
    String? categoria,
    String? searchText,
  });

  Future<void> toggleFavorite({
    required String businessId,
    required String userId,
  });

  Future<Microbusiness> rateBusiness({
    required String businessId,
    required double rating,
  });

  Future<List<Microbusiness>> fetchNearby({
    required String currentUserRole,
    required double userLat,
    required double userLng,
    double maxDistanceKm = 10,
    String? categoria,
    String? searchText,
  });
}

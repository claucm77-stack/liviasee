import '../../data/models/app_user_model.dart';
import '../../data/models/dashboard_metrics_model.dart';
import '../../domain/entities/content.dart';
import '../../domain/entities/microbusiness.dart';

abstract class DashboardRepository {
  Stream<DashboardMetricsModel> watchMetrics();

  Stream<List<AppUserModel>> watchUsers({
    String? role,
    bool? isActive,
  });

  Stream<List<Content>> watchContents({
    String? categoria,
  });

  Stream<List<Microbusiness>> watchMicrobusinesses({
    String? categoria,
  });

  Future<void> updateUser({
    required String uid,
    required String role,
    required bool isActive,
    required String description,
  });

  Future<void> updateContentStatus({
    required String contentId,
    required bool isActive,
  });

  Future<void> deleteContent(String contentId);

  Future<void> updateMicrobusinessStatus({
    required String businessId,
    required bool isActive,
  });

  Future<void> deleteMicrobusiness(String businessId);
}

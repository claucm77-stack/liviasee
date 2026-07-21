import 'package:flutter_test/flutter_test.dart';
import 'package:micronegocios_app/core/constants/app_roles.dart';

void main() {
  group('matriz de permisos de roles', () {
    test('normaliza roles heredados', () {
      expect(AppRoles.normalize('admin'), AppRoles.adminTi);
      expect(AppRoles.normalize('coordinador'), AppRoles.docenteAdmin);
      expect(AppRoles.normalize('educador'), AppRoles.docente);
      expect(AppRoles.normalize('usuario'), AppRoles.microempresario);
    });

    test('solo TI administra usuarios y sistema', () {
      for (final role in AppRoles.all) {
        expect(AppRoles.canManageUsers(role), role == AppRoles.adminTi);
        expect(AppRoles.canManageSystem(role), role == AppRoles.adminTi);
      }
    });

    test('docente administrador y TI abren la gestion academica', () {
      expect(AppRoles.canManageAcademic(AppRoles.microempresario), isFalse);
      expect(AppRoles.canManageAcademic(AppRoles.docente), isFalse);
      expect(AppRoles.canManageAcademic(AppRoles.docenteAdmin), isTrue);
      expect(AppRoles.canManageAcademic(AppRoles.adminTi), isTrue);
    });

    test('docentes, coordinador y TI gestionan contenidos y foros', () {
      expect(AppRoles.canCreateContent(AppRoles.microempresario), isFalse);
      expect(AppRoles.canModerateForums(AppRoles.microempresario), isFalse);
      for (final role in [
        AppRoles.docente,
        AppRoles.docenteAdmin,
        AppRoles.adminTi,
      ]) {
        expect(AppRoles.canCreateContent(role), isTrue);
        expect(AppRoles.canModerateForums(role), isTrue);
      }
    });

    test('todos los roles activos acceden a funciones compartidas', () {
      for (final role in AppRoles.all) {
        expect(AppRoles.canViewContent(role), isTrue);
        expect(AppRoles.canViewDirectory(role), isTrue);
        expect(AppRoles.canUseForums(role), isTrue);
        expect(AppRoles.canCreateBusiness(role), isTrue);
      }
    });

    test('propietario o administrador pueden editar un negocio', () {
      expect(
        AppRoles.canEditBusiness(
          role: AppRoles.microempresario,
          currentUserId: 'owner-1',
          ownerId: 'owner-1',
        ),
        isTrue,
      );
      expect(
        AppRoles.canEditBusiness(
          role: AppRoles.docente,
          currentUserId: 'teacher-1',
          ownerId: 'owner-1',
        ),
        isFalse,
      );
      expect(
        AppRoles.canEditBusiness(
          role: AppRoles.docenteAdmin,
          currentUserId: 'coordinator-1',
          ownerId: 'owner-1',
        ),
        isTrue,
      );
      expect(
        AppRoles.canEditBusiness(
          role: AppRoles.adminTi,
          currentUserId: 'admin-1',
          ownerId: 'owner-1',
        ),
        isTrue,
      );
    });
  });
}

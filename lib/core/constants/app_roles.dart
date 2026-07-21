class AppRoles {
  AppRoles._();

  static const microempresario = 'microempresario';
  static const docente = 'docente';
  static const docenteAdmin = 'docente_admin';
  static const adminTi = 'admin_ti';

  static const legacyAdmin = 'admin';
  static const legacyCoord = 'coord';
  static const legacyCoordinador = 'coordinador';
  static const legacyEducador = 'educador';
  static const legacyUsuario = 'usuario';
  static const legacyEmprendedor = 'emprendedor';

  static const all = [
    microempresario,
    docente,
    docenteAdmin,
    adminTi,
  ];

  static String normalize(String? role) {
    switch ((role ?? '').trim()) {
      case legacyAdmin:
        return adminTi;
      case legacyCoord:
      case legacyCoordinador:
        return docenteAdmin;
      case legacyEducador:
        return docente;
      case legacyUsuario:
      case legacyEmprendedor:
        return microempresario;
      case docenteAdmin:
      case docente:
      case adminTi:
      case microempresario:
        return role!.trim();
      default:
        return microempresario;
    }
  }

  static String label(String role) {
    switch (normalize(role)) {
      case adminTi:
        return 'Experto TI';
      case docenteAdmin:
        return 'Docente administrador';
      case docente:
        return 'Docente / experto académico';
      case microempresario:
      default:
        return 'Microempresario';
    }
  }

  static bool isMicroempresario(String? role) =>
      normalize(role) == microempresario;

  static bool isDocente(String? role) => normalize(role) == docente;

  static bool isDocenteAdmin(String? role) => normalize(role) == docenteAdmin;

  static bool isAdminTi(String? role) => normalize(role) == adminTi;

  static bool canManageUsers(String? role) => isAdminTi(role);

  static bool canManageSystem(String? role) => isAdminTi(role);

  static bool canManageAcademic(String? role) =>
      isDocenteAdmin(role) || isAdminTi(role);

  static bool canCreateContent(String? role) =>
      isDocente(role) || isDocenteAdmin(role) || isAdminTi(role);

  static bool canModerateForums(String? role) =>
      isDocente(role) || isDocenteAdmin(role) || isAdminTi(role);

  static bool canManageOwnBusiness(String? role) => isMicroempresario(role);

  static bool canCreateBusiness(String? role) =>
      isMicroempresario(role) ||
      isDocente(role) ||
      isDocenteAdmin(role) ||
      isAdminTi(role);

  static bool canEditBusiness({
    required String? role,
    required String? currentUserId,
    required String ownerId,
  }) {
    if (isDocenteAdmin(role) || isAdminTi(role)) return true;
    return (isMicroempresario(role) || isDocente(role)) &&
        currentUserId == ownerId;
  }

  static bool canViewDirectory(String? role) => all.contains(normalize(role));

  static bool canViewContent(String? role) => all.contains(normalize(role));

  static bool canUseForums(String? role) =>
      isMicroempresario(role) ||
      isDocente(role) ||
      isDocenteAdmin(role) ||
      isAdminTi(role);
}

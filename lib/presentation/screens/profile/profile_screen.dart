import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_roles.dart';
import '../../../core/utils/image_bytes_picker.dart';
import '../../viewmodels/auth_viewmodel.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _photoCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String? _loadedUid;
  bool _isUploadingPhoto = false;

  static const _yellow = Color(0xFFF8DA30);
  static const _iconBlue = Color(0xFF86A9B3);
  static const _textDark = Color(0xFF424242);

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _photoCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  void _syncFields(AuthState state) {
    final user = state.user;
    if (user == null || _loadedUid == user.uid) return;
    _loadedUid = user.uid;
    _nameCtrl.text = user.name;
    _emailCtrl.text = user.email;
    _photoCtrl.text = user.photoUrl;
    _descriptionCtrl.text = user.description;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authViewModelProvider.notifier).updateProfile(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          photoUrl: _photoCtrl.text.trim(),
          description: _descriptionCtrl.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(authViewModelProvider);
    final message = state.errorMessage ?? state.successMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    if (state.errorMessage == null && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _pickAndUploadProfileImage([StateSetter? sheetSetState]) async {
    final authUser = ref.read(authViewModelProvider).user;
    if (authUser == null) return;

    final picked = await pickImageBytes();
    if (picked == null) return;

    _updateInfoSheet(sheetSetState, () => _isUploadingPhoto = true);
    try {
      final safeName =
          picked.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final url = await ref
          .read(authViewModelProvider.notifier)
          .uploadProfilePhoto(bytes: picked.bytes, fileName: safeName);
      if (!mounted) return;
      if (url == null || url.isEmpty) {
        throw Exception(
          ref.read(authViewModelProvider).errorMessage ??
              'Laravel no pudo guardar la imagen.',
        );
      }
      _updateInfoSheet(sheetSetState, () => _photoCtrl.text = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto de perfil actualizada.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar la imagen: $error')),
      );
    } finally {
      if (mounted) {
        _updateInfoSheet(sheetSetState, () => _isUploadingPhoto = false);
      }
    }
  }

  void _updateInfoSheet(StateSetter? sheetSetState, VoidCallback changes) {
    if (!mounted) return;
    setState(changes);
    sheetSetState?.call(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final user = state.user;
    _syncFields(state);

    if (user == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: FilledButton.icon(
              onPressed: () => context.go('/login'),
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesión'),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(30, 16, 30, 28),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Volver',
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(_homeByRole(user.role));
                      }
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      size: 44,
                      color: Color(0xFF96989B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Text(
                          'Perfil',
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: _textDark,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                        ),
                      ),
                    ),
                    _ProfileAvatar(
                      imageUrl: user.photoUrl,
                      name: user.name.isEmpty ? user.email : user.name,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  'Administra tu cuenta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF838383),
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 34),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 42,
                  childAspectRatio: 1,
                  children: [
                    _ProfileActionCard(
                      label: 'Tu información',
                      assetPath: 'assets/images/info.png',
                      onTap: () => _showInfoSheet(context),
                    ),
                    _ProfileActionCard(
                      label: 'Tus Mensajes',
                      assetPath: 'assets/images/speech-bubble_14197144.png',
                      onTap: () => context.go('/docentes'),
                    ),
                    _ProfileActionCard(
                      label: 'Configuración',
                      assetPath: 'assets/images/setting_14197001.png',
                      onTap: () => _showSettingsSheet(context, user.role),
                    ),
                    _ProfileActionCard(
                      label: 'Servicio Técnico',
                      assetPath: 'assets/images/customer-service.png',
                      onTap: () => _openSupport(user.role),
                    ),
                  ],
                ),
                const SizedBox(height: 34),
                Text(
                  'Comparte Livi@se con otros\nemprendedores',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF838383),
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShareIconButton(
                      icon: Icons.share,
                      onPressed: _shareApp,
                    ),
                    _ShareIconButton(
                      icon: Icons.chat,
                      onPressed: _shareByWhatsApp,
                    ),
                    _ShareIconButton(
                      icon: Icons.copy,
                      onPressed: _copyShareText,
                    ),
                    _ShareIconButton(
                      icon: Icons.forward_to_inbox,
                      onPressed: _shareByEmail,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _ProfileBottomNav(
        onHome: () => context.go(_homeByRole(user.role)),
        onSearch: () => context.go('/micronegocios'),
        onLibrary: () => context.go('/contenidos'),
        onSupport: () => context.go('/soporte-ti'),
        onProfile: () {},
        showSupport: AppRoles.isMicroempresario(user.role) ||
            AppRoles.isDocente(user.role),
      ),
    );
  }

  void _showInfoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, sheetSetState) {
          final state = ref.watch(authViewModelProvider);
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 18,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text(
                    'Tu información',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value == null || value.trim().length < 2
                            ? 'Ingresa tu nombre.'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || !value.contains('@')
                        ? 'Ingresa un correo válido.'
                        : null,
                  ),
                  if (AppRoles.isDocente(state.user?.role)) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionCtrl,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: 2000,
                      decoration: const InputDecoration(
                        labelText: 'Descripción profesional',
                        hintText:
                            'Describe tu experiencia, especialidad y acompañamiento.',
                        prefixIcon: Icon(Icons.description_outlined),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _ProfileImageUploadField(
                    imageUrl: _photoCtrl.text,
                    isUploading: _isUploadingPhoto,
                    onPickImage: () =>
                        _pickAndUploadProfileImage(sheetSetState),
                    onRemove: _photoCtrl.text.isEmpty
                        ? null
                        : () => _updateInfoSheet(
                              sheetSetState,
                              () => _photoCtrl.clear(),
                            ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: state.isLoading || _isUploadingPhoto
                        ? null
                        : _saveProfile,
                    icon: state.isLoading || _isUploadingPhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Guardar cambios'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSettingsSheet(BuildContext context, String role) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        final user = ref.read(authViewModelProvider).user;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.verified_user_outlined),
                  title: Text(AppRoles.label(role)),
                  subtitle: Text(user?.email ?? ''),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_outlined),
                  title: const Text('Cambiar o recuperar contraseña'),
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/forgot-password');
                  },
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF193760),
                    minimumSize: const Size.fromHeight(46),
                  ),
                  onPressed: () async {
                    await ref.read(authViewModelProvider.notifier).signOut();
                    if (context.mounted) {
                      context.go('/');
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Cerrar sesión'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSupport(String role) async {
    context.go('/soporte-ti');
  }

  Future<void> _shareApp() async {
    await Share.share(_shareText, subject: 'Livi@se');
  }

  Future<void> _shareByWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(_shareText)}',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyShareText() async {
    await Clipboard.setData(const ClipboardData(text: _shareText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mensaje copiado para compartir.')),
    );
  }

  Future<void> _shareByEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Conoce Livi@se',
        'body': _shareText,
      },
    );
    await launchUrl(uri);
  }

  static const _shareText =
      'Conoce Livi@se, una plataforma de acompañamiento académico y empresarial para microempresarios.';

  String _homeByRole(String role) {
    switch (AppRoles.normalize(role)) {
      case AppRoles.adminTi:
        return '/admin';
      case AppRoles.docenteAdmin:
        return '/admin-dashboard';
      case AppRoles.docente:
        return '/educator';
      case AppRoles.microempresario:
      default:
        return '/entrepreneur';
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.imageUrl,
    required this.name,
  });

  final String imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'L' : name.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: 54,
      backgroundColor: const Color(0xFFE8EEF0),
      backgroundImage: imageUrl.trim().isEmpty ? null : NetworkImage(imageUrl),
      child: imageUrl.trim().isEmpty
          ? Text(
              initial,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: const Color(0xFF4C8D93),
                    fontWeight: FontWeight.w900,
                  ),
            )
          : null,
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.label,
    required this.onTap,
    this.assetPath,
  });

  final String label;
  final String? assetPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ProfileScreenState._yellow,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: assetPath != null
                      ? Image.asset(
                          assetPath!,
                          width: 76,
                          height: 76,
                          fit: BoxFit.contain,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileImageUploadField extends StatelessWidget {
  const _ProfileImageUploadField({
    required this.imageUrl,
    required this.isUploading,
    required this.onPickImage,
    required this.onRemove,
  });

  final String imageUrl;
  final bool isUploading;
  final VoidCallback onPickImage;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: const Color(0xFFE8EEF0),
                backgroundImage:
                    imageUrl.trim().isEmpty ? null : NetworkImage(imageUrl),
                child: imageUrl.trim().isEmpty
                    ? const Icon(
                        Icons.person_outline,
                        color: Color(0xFF4C8D93),
                        size: 34,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Foto de perfil',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      imageUrl.trim().isEmpty
                          ? 'Carga una imagen desde tu equipo.'
                          : 'Imagen cargada correctamente.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF707070),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isUploading ? null : onPickImage,
                  icon: isUploading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(
                    isUploading
                        ? 'Cargando imagen...'
                        : imageUrl.trim().isEmpty
                            ? 'Cargar imagen'
                            : 'Cambiar imagen',
                  ),
                ),
              ),
              if (onRemove != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar imagen',
                  onPressed: isUploading ? null : onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ShareIconButton extends StatelessWidget {
  const _ShareIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: _ProfileScreenState._iconBlue, size: 25),
      tooltip: 'Compartir',
      constraints: const BoxConstraints.tightFor(width: 38, height: 38),
    );
  }
}

class _ProfileBottomNav extends StatelessWidget {
  const _ProfileBottomNav({
    required this.onHome,
    required this.onSearch,
    required this.onLibrary,
    required this.onSupport,
    required this.onProfile,
    required this.showSupport,
  });

  final VoidCallback onHome;
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  final VoidCallback onSupport;
  final VoidCallback onProfile;
  final bool showSupport;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E1E1))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              tooltip: 'Inicio',
              onPressed: onHome,
              icon: const Icon(Icons.home_outlined, size: 34),
            ),
            IconButton(
              tooltip: 'Buscar',
              onPressed: onSearch,
              icon: const Icon(Icons.search, size: 34),
            ),
            IconButton(
              tooltip: 'Repositorio',
              onPressed: onLibrary,
              icon: const Icon(Icons.view_week_outlined, size: 34),
            ),
            if (showSupport)
              IconButton(
                tooltip: 'Soporte TI',
                onPressed: onSupport,
                icon: const Icon(Icons.support_agent_outlined, size: 34),
              ),
            IconButton(
              tooltip: 'Perfil',
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline, size: 34),
            ),
          ],
        ),
      ),
    );
  }
}

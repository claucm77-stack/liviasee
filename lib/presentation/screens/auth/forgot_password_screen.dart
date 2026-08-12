import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/app_scaffold.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    await ref
        .read(authViewModelProvider.notifier)
        .resetPassword(email: _emailCtrl.text.trim());

    if (!mounted) return;
    final state = ref.read(authViewModelProvider);

    if (state.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.errorMessage!)),
      );
      return;
    }

    if (state.successMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(state.successMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);

    return AppScaffold(
      title: 'Recuperar contraseña',
      showBack: true,
      child: ListView(
        children: [
          const SectionHeader(
            title: 'Restablecer acceso',
            subtitle:
                'Ingresa tu correo y enviaremos un enlace para crear una nueva contraseña.',
            icon: Icons.lock_reset_outlined,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: state.isLoading ? null : _handleReset,
                    icon: state.isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                    label: const Text('Enviar enlace'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Si no recibes el enlace o necesitas apoyo para recuperar tu cuenta, escribe a juan.drodriguez@sanmartin.edu.co.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

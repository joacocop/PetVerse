import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/firebase/firebase_bootstrap.dart';
import '../../providers/auth_provider.dart';

/// Pantalla de recuperación de contraseña de PV1.
class ForgotPasswordScreen extends StatefulWidget {
  /// Crea la pantalla de recuperación.
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDemo = !FirebaseBootstrap.isReady;
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        '¿No recuerdas tu contraseña?',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isDemo
                            ? 'Modo demo: este formulario es una simulación. '
                                'No se enviará ningún correo.'
                            : 'Te enviaremos un enlace para crear una nueva.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) =>
                            value != null && value.contains('@')
                                ? null
                                : 'Ingresa un email válido.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.isBusy ? null : _submit,
                        child: auth.isBusy
                            ? const SizedBox.square(
                                dimension: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(isDemo
                                ? 'Probar recuperación'
                                : 'Enviar enlace'),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          auth.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final success = await context
        .read<AuthProvider>()
        .sendPasswordResetEmail(_emailController.text);
    if (!mounted || !success) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          FirebaseBootstrap.isReady
              ? 'Revisa tu bandeja de entrada.'
              : 'Simulación completada. No se envió ningún correo.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}

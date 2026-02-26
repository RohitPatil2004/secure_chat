import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../Firebase/Auth provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Generating encryption keys...')
          ]),
          duration: Duration(seconds: 10),
        ),
      );
    }

    final success = await auth.register(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
      displayName: _nameCtrl.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (!success && auth.error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(auth.error!)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A unique RSA-2048 key pair will be generated and stored securely on your device.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Display Name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v != null && v.trim().isNotEmpty ? null : 'Required',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) =>
                      v != null && v.contains('@') ? null : 'Enter valid email',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => v != null && v.length >= 8
                      ? null
                      : 'Min 8 characters',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) => v == _passwordCtrl.text
                      ? null
                      : 'Passwords do not match',
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: auth.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
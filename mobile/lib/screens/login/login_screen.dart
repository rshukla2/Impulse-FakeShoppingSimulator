import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:impulse/core/icons/app_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/user_provider.dart';
import '../main_navigation_screen.dart';

/// Name-only local onboarding. This is deliberately not authentication.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.destinationBuilder});

  /// Test seam for verifying local onboarding without starting catalog calls.
  /// Production always uses [MainNavigationScreen].
  final WidgetBuilder? destinationBuilder;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    await ref.read(userProvider.notifier).setUserName(_controller.text.trim());
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            widget.destinationBuilder ?? (_) => const MainNavigationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.forestGreen,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.forestGreen.withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.shoppingBag,
                      size: 40,
                      color: AppColors.warmBeigeLight,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome to Impulse',
                  style: TextStyle(
                    color: AppColors.forestGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fake Shopping Simulator',
                  style: TextStyle(
                    color: AppColors.terracotta,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Experience the fun of browsing without spending real money.',
                  style: TextStyle(
                    color: AppColors.slateGrey,
                    fontSize: 14,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                const Text(
                  'What should we call you?',
                  style: TextStyle(
                    color: AppColors.forestGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                    prefixIcon:
                        Icon(LucideIcons.user, color: AppColors.forestGreen),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Please enter your name'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.warmBeigeLight,
                          ),
                        )
                      : const Text('Login'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No account, password, email, or phone number is required. Your name stays on this device.',
                  style: TextStyle(
                    color: AppColors.slateGreyLight,
                    fontSize: 11,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

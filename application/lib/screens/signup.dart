import 'package:application/screens/paginaHome.dart';
import 'package:application/services/auth_service.dart';
import 'package:application/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../core/theme/app_colors.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() {
    return _SignupScreenState();
  }
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  String? _authError;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isPasswordValid = false;
  bool _isLoading = false;

  @override
  void initState() {
    _authError = null;
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nicknameController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submitSignUp(BuildContext context) async {
    final isValid = _formKey.currentState!.validate();

    if (!isValid) return;

    setState(() {
      _authError = null;
      _isLoading = true;
    });

    try {
      final user = await AuthService().registerUser(_emailController.text, _passwordController.text);
      if (user == null) {
        throw Exception('User creation failed');
      }

      // Add user record to database
      await DatabaseService().createUser(_emailController.text.trim(), _nicknameController.text.trim());

      // When user created close dialogue and load homepage
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            //TODO: sostituire con la vera homepage
            builder: (_) => const HomePage(),
          ),
        );
      }
    } catch (e) {
      debugPrint(e.toString());
      _authError = '$e';
    }

  }

  void goToLogin(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.terrain,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to start organizing your hiking trails.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),

                    if(_authError != null) ... [
                      const SizedBox(height: 16,),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.errorBorder),
                        ),
                        child: Text(
                          _authError!,
                          style: const TextStyle(color: AppColors.errorText),
                        ),
                      ),
                    ],
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Insert your email';
                              }

                              if (!value.contains('@') || !value.contains('.')) {
                                return 'Insert a valid email address';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _nicknameController,
                            keyboardType: TextInputType.name,
                            decoration: const InputDecoration(
                              labelText: 'Nickname',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.account_circle,),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Insert your nickname';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16,),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            onChanged: (value) {
                              final isValid = value.isNotEmpty && value.length >= 6;
                          
                              if (isValid != _isPasswordValid) {
                                setState(() {
                                  _isPasswordValid = isValid;
                                });
                              }
                            },
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Insert your password';
                              }

                              if (value.length < 6) {
                                return 'Password must be at least six-characters long';
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: 16,),

                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscureConfirm,
                            enabled: _isPasswordValid,
                            decoration: InputDecoration(
                              labelText: 'Confirm password',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  });
                                },
                                icon: Icon(
                                  _obscureConfirm
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Confirm your password';
                              }

                              if (value != _passwordController.text) {
                                return 'Password mismatch';
                              }

                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : () {
                          _submitSignUp(context);
                        },
                        child: _isLoading ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ) : const Text('Sign Up'),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Already have an account?'),
                        TextButton(
                          onPressed: () {
                            goToLogin(context);
                          },
                          child: const Text('Login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
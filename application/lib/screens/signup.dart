import 'package:application/services/auth_service.dart';
import 'package:application/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:hike_core/hike_core.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() {
    return _SignupScreenState();
  }
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers for text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  // Focus nodes for navigating with keyboard
  final FocusNode _nicknameFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  // Variable to hold authentication error messages
  String? _authError;

  // Variables for password visibility and validation
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isPasswordValid = false;

  // State variable
  bool _isLoading = false;

  @override
  void initState() {
    _authError = null;
    super.initState();
  }

  @override
  // Dispose controllers and focus nodes to free resources
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

    // Reset authentication error and set loading state
    setState(() {
      _authError = null;
      _isLoading = true;
    });

    try {
      final user = await AuthService().registerUser(
        _emailController.text,
        _passwordController.text,
      );
      if (user == null) {
        throw Exception('User creation failed');
      }

      // Add user record to database
      await DatabaseService().createUser(
        _emailController.text.trim(),
        _nicknameController.text.trim(),
      );

      if (context.mounted) {
        Navigator.of(context).pop(); //go back to login screen so that AuthGate handles navigation
      }
    } catch (e) {
      setState(() {
        _authError = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // Build the error banner widget to display authentication errors
  Widget _buildErrorBanner() {
    return Column(
      children: [
        const SizedBox(height: 16),
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
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_nicknameFocusNode),
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
            focusNode: _nicknameFocusNode,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passwordFocusNode),
            decoration: const InputDecoration(
              labelText: 'Nickname',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_circle),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Insert your nickname';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          TextFormField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_confirmPasswordFocusNode),
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
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
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
          const SizedBox(height: 16),

          TextFormField(
            controller: _confirmController,
            focusNode: _confirmPasswordFocusNode,
            obscureText: _obscureConfirm,
            enabled: _isPasswordValid,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitSignUp(context),
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
                  _obscureConfirm ? Icons.visibility_off : Icons.visibility,
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
    );
  }

  Widget _buildSignInRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account?'),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Login'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: Key('signup'),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.terrain, size: 80),
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
                  // Show error banner if there's an authentication error
                  if (_authError != null) _buildErrorBanner(),
                  const SizedBox(height: 32),

                  _buildForm(),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      // Disable button when loading
                      onPressed: _isLoading
                          ? null
                          : () {
                              _submitSignUp(context);
                            },
                      // Show loading indicator when processing sign up
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign Up'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildSignInRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

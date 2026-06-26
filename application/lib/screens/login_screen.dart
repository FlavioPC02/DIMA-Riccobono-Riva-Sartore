import 'package:application/screens/signup.dart';
import 'package:flutter/material.dart';
import 'package:hike_core/hike_core.dart';
import '../services/auth_service.dart';

// Regular expression for validating email addresses
final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // State variables
  bool _isLoading = false;
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  // Controllers for text fields
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // Variable for password visibility
  bool _obscurePassword = true;
  // Variable to hold authentication error messages
  String? _authError;
  // Focus node for password when navigating with keyboard
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  // Dispose controllers and focus nodes to free resources
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  // Method to handle login submission
  Future<void> _submitLogin() async {
    // Prevent multiple submissions while loading and validate form inputs
    if (_isLoading) return;
    // Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // Reset authentication error and set loading state
    setState(() {
      _authError = null;
      _isLoading = true;
    });

    try {
      final user = await AuthService().signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (user == null) throw Exception('Login failed');
    } catch (e) {
      if (!mounted) return;

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

  // Build the form with email and password fields
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            key: const ValueKey("login_mail"),
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            onFieldSubmitted: (_) =>
                FocusScope.of(context).requestFocus(_passwordFocusNode),
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email';
              }
              if (!_emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey("login_password"),
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isLoading) _submitLogin();
            },
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter your password';
              }
              if (value.length < 6) {
                return 'The password must contain at least 6 characters';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // Build the row with "Don't have an account?" and "Sign Up" button
  Widget _buildSignUpRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Don't have an account?"),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupScreen()),
          ),
          child: const Text('Sign Up'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('login'),
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
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Log in to continue organizing your hikes.',
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
                      key: const ValueKey('login_button'),
                      // Disable button when loading to prevent multiple submissions
                      onPressed: _isLoading ? null : _submitLogin,
                      // Show loading indicator when processing login
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sign In'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSignUpRow(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

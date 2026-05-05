// auth_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login
  final _loginEmailController    = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Sign up
  final _signupNameController     = TextEditingController();
  final _signupEmailController    = TextEditingController();
  final _signupPasswordController = TextEditingController();

  // UI state
  bool _loginLoading  = false;
  bool _signupLoading = false;
  bool _loginObscure  = true;
  bool _signupObscure = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _onLogin() async {
    setState(() => _loginLoading = true);

    final error = await AuthService.instance.login(
      email:    _loginEmailController.text,
      password: _loginPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _loginLoading = false);

    if (error != null) {
      _showError(error);
    } else {
      context.go('/home');
    }
  }

  Future<void> _onSignUp() async {
    setState(() => _signupLoading = true);

    final error = await AuthService.instance.signUp(
      name:     _signupNameController.text,
      email:    _signupEmailController.text,
      password: _signupPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _signupLoading = false);

    if (error != null) {
      _showError(error);
    } else {
      // Auto-login after sign up
      await AuthService.instance.login(
        email:    _signupEmailController.text,
        password: _signupPasswordController.text,
      );
      if (mounted) context.go('/home');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'Welcome',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Login or Sign Up to continue',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 30),

            // ── Tab bar ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C3E),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(
                    width: 3,
                    color: Colors.blueAccent.shade400,
                  ),
                  insets: const EdgeInsets.symmetric(horizontal: 32),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(text: 'Login'),
                  Tab(text: 'Sign Up'),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoginTab(),
                  _buildSignUpTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Login tab ──────────────────────────────────────────────────────────────

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _inputField(
            hint: 'Email',
            controller: _loginEmailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _inputField(
            hint: 'Password',
            controller: _loginPasswordController,
            icon: Icons.lock_outline,
            obscureText: _loginObscure,
            toggleObscure: () =>
                setState(() => _loginObscure = !_loginObscure),
          ),
          const SizedBox(height: 30),
          _actionButton(
            label: 'Login',
            loading: _loginLoading,
            onTap: _onLogin,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {},
            child: const Text(
              'Forgot Password?',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sign up tab ────────────────────────────────────────────────────────────

  Widget _buildSignUpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          _inputField(
            hint: 'Full Name',
            controller: _signupNameController,
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 20),
          _inputField(
            hint: 'Email',
            controller: _signupEmailController,
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 20),
          _inputField(
            hint: 'Password',
            controller: _signupPasswordController,
            icon: Icons.lock_outline,
            obscureText: _signupObscure,
            toggleObscure: () =>
                setState(() => _signupObscure = !_signupObscure),
          ),
          const SizedBox(height: 30),
          _actionButton(
            label: 'Sign Up',
            loading: _signupLoading,
            onTap: _onSignUp,
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => _tabController.animateTo(0),
            child: const Text(
              'Already have an account? Login',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared widgets ─────────────────────────────────────────────────────────

  Widget _inputField({
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    bool obscureText = false,
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        // Show eye toggle only for password fields
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.white38,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF2C2C3E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(
            color: Colors.blueAccent.shade400,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: loading
                ? [Colors.grey.shade700, Colors.grey.shade600]
                : [const Color(0xFF6A11CB), const Color(0xFF2575FC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
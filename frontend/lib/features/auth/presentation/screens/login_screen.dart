import 'package:flutter/material.dart';
import 'package:college_carpool/features/home/presentation/screens/home_screen.dart';
import 'package:college_carpool/features/auth/presentation/screens/register_screen.dart';
import 'package:college_carpool/core/network/api_client.dart';
import 'package:college_carpool/core/constants/api_constants.dart';
import 'package:college_carpool/core/theme/modern_widgets.dart';
import 'package:dio/dio.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      try {
        final api = ApiClient();
        
        // Form Data for OAuth2
        final formData = FormData.fromMap({
          'username': _emailController.text.trim(),
          'password': _passwordController.text
        });
        
        final response = await api.client.post(ApiConstants.login, data: formData);
        
        if (mounted) {
            final token = response.data['access_token'];
            // TODO: Save token to secure storage
            // api.setAuthToken(token); // Singleton approach needed later
            
            setState(() => _isLoading = false);
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
        }
      } catch (e) {
        if (mounted) {
           setState(() => _isLoading = false);
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Login Failed: ${e.toString()}')),
           );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB)],
          )
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const Icon(Icons.directions_car_filled, size: 80, color: Color(0xFF6A11CB)),
                   const SizedBox(height: 16),
                  const Text(
                    'CampusPool',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your safety, our priority",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  ModernInput(
                    controller: _emailController, 
                    label: "Christ University Email", 
                    icon: Icons.school_outlined,
                    validator: (v) => v!.endsWith('christuniversity.in') ? null : 'Please use your Christ University email',
                  ),
                  const SizedBox(height: 16),
                  
                  ModernInput(
                    controller: _passwordController, 
                    label: "Password", 
                    icon: Icons.lock_outline,
                    isPassword: true,
                    validator: (v) => v!.length < 6 ? 'Password too short' : null,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  ModernButton(
                    text: "Login", 
                    onPressed: _isLoading ? null : _login,
                    isLoading: _isLoading,
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: const Text('New here? Create Account', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A11CB))),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

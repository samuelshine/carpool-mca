import 'package:flutter/material.dart';
import 'package:college_carpool/core/network/api_client.dart';
import 'package:college_carpool/core/constants/api_constants.dart';
import 'package:college_carpool/core/theme/modern_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _gender = "MALE";
  bool _isLoading = false;

  void _submit() async {
    if (_formKey.currentState!.validate()) {
       setState(() => _isLoading = true);
       
       try {
         final api = ApiClient();
         final response = await api.client.post(ApiConstants.register, data: {
           "email": _emailController.text.trim(),
           "password": _passwordController.text,
           "full_name": _nameController.text.trim(),
           "gender": _gender
         });
         
         if (mounted) {
           setState(() => _isLoading = false);
           if (response.statusCode == 200) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Account created! Please login.')),
             );
             Navigator.pop(context);
           }
         }
       } catch (e) {
         if (mounted) {
           setState(() => _isLoading = false);
           // Simple error handling
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Registration Failed: ${e.toString()}')),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 const SizedBox(height: 20),
                 const Text(
                   "Join the Community",
                   style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 8),
                 const Text(
                   "Verified Safe Carpooling for Christ University",
                   style: TextStyle(fontSize: 14, color: Colors.grey),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 40),
                 
                 ModernInput(
                   controller: _nameController, 
                   label: "Full Name", 
                   icon: Icons.person_outline
                 ),
                 const SizedBox(height: 16),
                 
                 ModernInput(
                   controller: _emailController, 
                   label: "Christ University Email", 
                   icon: Icons.school_outlined,
                   validator: (v) => v!.endsWith('christuniversity.in') ? null : 'Must be a Christ University email',
                 ),
                 const SizedBox(height: 16),
                 
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                   decoration: BoxDecoration(
                     color: Colors.white,
                     borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                   ),
                   child: DropdownButtonFormField<String>(
                     value: _gender,
                     items: const [
                       DropdownMenuItem(value: "MALE", child: Text("Male")),
                       DropdownMenuItem(value: "FEMALE", child: Text("Female")),
                       DropdownMenuItem(value: "OTHER", child: Text("Other")),
                     ],
                     onChanged: (v) => setState(() => _gender = v!),
                     decoration: const InputDecoration(
                       labelText: 'Gender', 
                       border: InputBorder.none,
                       prefixIcon: Icon(Icons.wc, color: Colors.deepPurple),
                     ),
                   ),
                 ),
                 
                 const SizedBox(height: 16),
                 ModernInput(
                   controller: _passwordController,
                   label: "Password",
                   icon: Icons.lock_outline,
                   isPassword: true,
                   validator: (v) => v!.length < 6 ? 'Too short' : null,
                 ),
                 
                 const SizedBox(height: 40),
                 ModernButton(
                   text: "Create Account", 
                   onPressed: _isLoading ? null : _submit,
                   isLoading: _isLoading,
                 )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

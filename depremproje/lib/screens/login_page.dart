import 'package:flutter/material.dart';
import 'package:depremproje/services/auth_service.dart';
import 'package:depremproje/screens/home_page.dart'; // Anasayfa sayfası import edildi
import 'package:depremproje/screens/register_page.dart';
import 'package:depremproje/screens/forgot_password_page.dart';
import 'package:depremproje/widgets/custom_button.dart';
import 'package:depremproje/widgets/custom_text_field.dart';
import 'package:depremproje/main.dart' show DepremHaritasiSayfasi;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showPassword = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        // Başarılı giriş sonrası işlemler AuthWrapper tarafından yönetilecek
      } catch (e) {
        setState(() {
          _isLoading = false;
        });

        // Hata mesajını göster
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loginAsGuest() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DepremHaritasiSayfasi()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Büyütüldü
                    Image.asset(
                      'assets/images/depmo_logo.png', // Logo dosyanızı eklemeyi unutmayın
                      height: 200, // Daha büyük logo
                      width: 200,
                    ),
                    const SizedBox(height: 36),

                    // Başlık kaldırıldı
                    const SizedBox(height: 8),

                    const Text(
                      'Türkiye Deprem Bilgi Sistemi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Email alanı
                    CustomTextField(
                      controller: _emailController,
                      hintText: 'E-posta',
                      prefixIcon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'E-posta adresi gerekli';
                        }
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                            .hasMatch(value)) {
                          return 'Geçerli bir e-posta adresi girin';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Şifre alanı
                    CustomTextField(
                      controller: _passwordController,
                      hintText: 'Şifre',
                      prefixIcon: Icons.lock,
                      obscureText: !_showPassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Şifre gerekli';
                        }
                        if (value.length < 6) {
                          return 'Şifre en az 6 karakter olmalı';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Şifremi unuttum linki
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Şifremi Unuttum',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Giriş yap butonu
                    CustomButton(
                      text: 'Giriş Yap',
                      isLoading: _isLoading,
                      onPressed: _login,
                    ),
                    const SizedBox(height: 16),

                    // Kayıt ol linki
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Hesabınız yok mu?'),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Kayıt Ol',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Ziyaretçi olarak giriş yap linki yerine Wrap widget'ı eklendi
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: [
                        const Text('Ziyaretçi olarak giriş yapmak için: '),
                        TextButton(
                          onPressed: _loginAsGuest,
                          child: const Text(
                            'Ziyaretçi Giriş',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  import 'package:flutter/material.dart';
  import 'package:depremproje/services/auth_service.dart';
  import 'package:depremproje/widgets/custom_button.dart';
  import 'package:depremproje/widgets/custom_text_field.dart';

  class RegisterPage extends StatefulWidget {
    const RegisterPage({super.key});

    @override
    State<RegisterPage> createState() => _RegisterPageState();
  }

  class _RegisterPageState extends State<RegisterPage> {
    final _formKey = GlobalKey<FormState>();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    bool _isLoading = false;
    bool _showPassword = false;
    bool _showConfirmPassword = false;

    final AuthService _authService = AuthService();

    @override
    void dispose() {
      _nameController.dispose();
      _emailController.dispose();
      _passwordController.dispose();
      _confirmPasswordController.dispose();
      super.dispose();
    }

    Future<void> _register() async {
      if (_formKey.currentState!.validate()) {
        setState(() {
          _isLoading = true;
        });

        try {
          await _authService.createUserWithEmailAndPassword(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          );

          // Başarılı kayıt sonrası otomatik giriş yapılacak
          // Kullanıcı bilgileri güncellenebilir (isim gibi)
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Kayıt başarılı! Giriş yapılıyor...'),
              backgroundColor: Colors.green,
            ),
          );

          // Ana sayfaya otomatik yönlendirme
          Navigator.pop(context);
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

    @override
    Widget build(BuildContext context) {
      return Scaffold(
          appBar: AppBar(
          title: const Text('Kayıt Ol'),
      backgroundColor: Colors.red,
      ),
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
      // Başlık
      const Text(
      'Hesap Oluştur',
      textAlign: TextAlign.center,
      style: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      color: Colors.red,
      ),
      ),
      const SizedBox(height: 36),

      // İsim alanı
      CustomTextField(
      controller: _nameController,
      hintText: 'Ad Soyad',
      prefixIcon: Icons.person,
      validator: (value) {
      if (value == null || value.isEmpty) {
      return 'Ad Soyad gerekli';
      }
      return null;
      },
      ),
      const SizedBox(height: 16),

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
        const SizedBox(height: 16),

        // Şifre tekrar alanı
        CustomTextField(
          controller: _confirmPasswordController,
          hintText: 'Şifre Tekrar',
          prefixIcon: Icons.lock_outline,
          obscureText: !_showConfirmPassword,
          suffixIcon: IconButton(
            icon: Icon(
              _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _showConfirmPassword = !_showConfirmPassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Şifre tekrarı gerekli';
            }
            if (value != _passwordController.text) {
              return 'Şifreler eşleşmiyor';
            }
            return null;
          },
        ),
        const SizedBox(height: 32),

        // Kayıt ol butonu
        CustomButton(
          text: 'Kayıt Ol',
          isLoading: _isLoading,
          onPressed: _register,
        ),
        const SizedBox(height: 16),

        // Giriş yap linki
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Zaten hesabınız var mı?'),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Giriş Yap',
                style: TextStyle(
                  color: Colors.red,
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
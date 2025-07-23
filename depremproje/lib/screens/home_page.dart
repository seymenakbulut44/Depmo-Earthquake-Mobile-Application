import 'package:flutter/material.dart';
import 'package:depremproje/services/auth_service.dart';

// Ana sayfa yapısı
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService _authService = AuthService();
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Depmo'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
    );
  }
}

// Mevcut DepremHaritasiSayfasi sınıfını main.dart'tan buraya taşıyabilirsiniz
// Veya main.dart içinde kullanmaya devam edebilirsiniz
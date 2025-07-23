import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:depremproje/services/auth_service.dart';
import 'package:provider/provider.dart'; // Provider ekledik
import 'package:depremproje/providers/theme_provider.dart'; // ThemeProvider ekledik

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSettingsEditing = false;

  // Kullanıcı verileri
  String _username = '';
  String _email = '';
  String _phoneNumber = '';
  String _address = '';
  String _emergencyContact = '';
  String _bloodType = '';
  LatLng _homeLocation = const LatLng(39.0, 35.0);

  // Ayarlar
  bool _notificationsEnabled = true;
  bool _locationTrackingEnabled = false;
  bool _darkModeEnabled = false;
  double _alertThreshold = 4.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserData();
    _checkLocationPermission();

    _tabController.addListener(() {
      if (_isEditing || _isSettingsEditing) {
        setState(() {
          _isEditing = false;
          _isSettingsEditing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Konum izinlerini kontrol etme
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Konum servisi açık mı kontrol et
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum servisleri kapalı. Lütfen açın.')),
        );
      }
      return;
    }

    // Konum izni kontrol et
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni reddedildi')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum izinleri kalıcı olarak reddedildi. Ayarlardan değiştirebilirsiniz.')),
        );
      }
      return;
    }
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          setState(() {
            _username = userData['username'] ?? user.displayName ?? '';
            _email = user.email ?? '';
            _phoneNumber = userData['phoneNumber'] ?? '';
            _address = userData['address'] ?? '';
            _emergencyContact = userData['emergencyContact'] ?? '';
            _bloodType = userData['bloodType'] ?? '';

            if (userData['homeLocation'] != null) {
              _homeLocation = LatLng(
                userData['homeLocation']['latitude'] ?? 39.0,
                userData['homeLocation']['longitude'] ?? 35.0,
              );
            }

            _notificationsEnabled = userData['notificationsEnabled'] ?? true;
            _locationTrackingEnabled = userData['locationTrackingEnabled'] ?? false;
            _darkModeEnabled = userData['darkModeEnabled'] ?? false;
            _alertThreshold = userData['alertThreshold']?.toDouble() ?? 4.0;

            // ThemeProvider'ı güncelle
            final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
            themeProvider.setTheme(_darkModeEnabled);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kullanıcı bilgileri yüklenirken hata: $e')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserData() async {
    if (_isEditing && !_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Kullanıcı verilerini güncelle
        await _firestore.collection('users').doc(user.uid).set({
          'username': _username,
          'phoneNumber': _phoneNumber,
          'address': _address,
          'emergencyContact': _emergencyContact,
          'bloodType': _bloodType,
          'homeLocation': {
            'latitude': _homeLocation.latitude,
            'longitude': _homeLocation.longitude,
          },
          'notificationsEnabled': _notificationsEnabled,
          'locationTrackingEnabled': _locationTrackingEnabled,
          'darkModeEnabled': _darkModeEnabled,
          'alertThreshold': _alertThreshold,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil başarıyla güncellendi')),
        );
        setState(() {
          _isEditing = false;
          _isSettingsEditing = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil güncellenirken hata: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Ayarları güncelle
        await _firestore.collection('users').doc(user.uid).update({
          'notificationsEnabled': _notificationsEnabled,
          'locationTrackingEnabled': _locationTrackingEnabled,
          'darkModeEnabled': _darkModeEnabled,
          'alertThreshold': _alertThreshold,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Tema değişikliğini uygula
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        themeProvider.setTheme(_darkModeEnabled);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ayarlar başarıyla güncellendi')),
        );
        setState(() {
          _isSettingsEditing = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ayarlar güncellenirken hata: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Geolocator ile mevcut konumu alma
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Konum izni kontrolü
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni reddedildi')),
          );
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Konum izinleri kalıcı olarak reddedildi. Ayarlardan değiştirebilirsiniz.')),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Mevcut konumu al
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _homeLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konum başarıyla güncellendi')),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konum alınırken hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: Colors.red,
        actions: [
          if (_tabController.index == 0 && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Profili Düzenle',
            ),
          if (_tabController.index == 0 && _isEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveUserData,
              tooltip: 'Değişiklikleri Kaydet',
            ),
          if (_tabController.index == 0 && _isEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => setState(() => _isEditing = false),
              tooltip: 'İptal Et',
            ),
          if (_tabController.index == 1 && !_isSettingsEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isSettingsEditing = true),
              tooltip: 'Ayarları Düzenle',
            ),
          if (_tabController.index == 1 && _isSettingsEditing)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings, // Ayarları kaydet
              tooltip: 'Ayarları Kaydet',
            ),
          if (_tabController.index == 1 && _isSettingsEditing)
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => setState(() => _isSettingsEditing = false),
              tooltip: 'İptal Et',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Profil Bilgileri', icon: Icon(Icons.person)),
            Tab(text: 'Ayarlar', icon: Icon(Icons.settings)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildSettingsTab(),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileImage(),
            const SizedBox(height: 24),
            _buildProfileForm(),
            const SizedBox(height: 32),
            _buildHomeLocationSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey[300],
          child: Icon(
            Icons.person,
            size: 80,
            color: Colors.grey[600],
          ),
        ),
        if (_isEditing)
          Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bu özellik image_picker paketi gerektirir'),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProfileForm() {
    return Column(
      children: [
        TextFormField(
          initialValue: _username,
          decoration: const InputDecoration(
            labelText: 'Kullanıcı Adı',
            prefixIcon: Icon(Icons.person),
            border: OutlineInputBorder(),
          ),
          enabled: _isEditing,
          validator: (value) => value!.isEmpty ? 'Kullanıcı adı gerekli' : null,
          onChanged: (value) => _username = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _email,
          decoration: const InputDecoration(
            labelText: 'E-posta',
            prefixIcon: Icon(Icons.email),
            border: OutlineInputBorder(),
          ),
          enabled: false, // Email değiştirilemez
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _phoneNumber,
          decoration: const InputDecoration(
            labelText: 'Telefon Numarası',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
          enabled: _isEditing,
          keyboardType: TextInputType.phone,
          onChanged: (value) => _phoneNumber = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _address,
          decoration: const InputDecoration(
            labelText: 'Adres',
            prefixIcon: Icon(Icons.home),
            border: OutlineInputBorder(),
          ),
          enabled: _isEditing,
          maxLines: 2,
          onChanged: (value) => _address = value,
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _emergencyContact,
          decoration: const InputDecoration(
            labelText: 'Acil Durum İletişim Bilgileri',
            prefixIcon: Icon(Icons.emergency),
            border: OutlineInputBorder(),
          ),
          enabled: _isEditing,
          onChanged: (value) => _emergencyContact = value,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _bloodType.isNotEmpty ? _bloodType : null,
          decoration: const InputDecoration(
            labelText: 'Kan Grubu',
            prefixIcon: Icon(Icons.bloodtype),
            border: OutlineInputBorder(),
          ),
          items: ['A Rh+', 'A Rh-', 'B Rh+', 'B Rh-', 'AB Rh+', 'AB Rh-', '0 Rh+', '0 Rh-']
              .map((type) => DropdownMenuItem(value: type, child: Text(type)))
              .toList(),
          onChanged: _isEditing ? (value) => setState(() => _bloodType = value!) : null,
          hint: const Text('Kan grubunuzu seçin'),
        ),
      ],
    );
  }

  Widget _buildHomeLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ev Konumu',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
        ),
        const SizedBox(height: 8),
        Container(
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FlutterMap(
              options: MapOptions(
                center: _homeLocation,
                zoom: 12.0,
                interactiveFlags: _isEditing
                    ? InteractiveFlag.all
                    : InteractiveFlag.drag | InteractiveFlag.pinchZoom,
                onTap: _isEditing ? (tapPosition, point) {
                  setState(() {
                    _homeLocation = point;
                  });
                } : null,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.depremapp',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _homeLocation,
                      width: 40,
                      height: 40,
                      builder: (context) => const Icon(
                        Icons.home,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _getCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Mevcut Konumu Kullan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bildirim Ayarları',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Deprem Bildirimleri'),
                  subtitle: const Text('Yeni depremler hakkında bildirim al'),
                  value: _notificationsEnabled,
                  onChanged: _isSettingsEditing
                      ? (value) => setState(() => _notificationsEnabled = value)
                      : null,
                ),
                const Divider(),
                ListTile(
                  title: const Text('Bildirim Eşiği'),
                  subtitle: Text('${_alertThreshold.toStringAsFixed(1)} ve üzeri depremler için bildirim al'),
                ),
                if (_isSettingsEditing)
                  Slider(
                    min: 3.0,
                    max: 7.0,
                    divisions: 8,
                    label: _alertThreshold.toStringAsFixed(1),
                    value: _alertThreshold,
                    onChanged: (value) => setState(() => _alertThreshold = value),
                    activeColor: Colors.red,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Konum Ayarları',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Konum Takibi'),
                  subtitle: const Text('Acil durumlarda konumunuzu paylaşın'),
                  value: _locationTrackingEnabled,
                  onChanged: _isSettingsEditing
                      ? (value) => setState(() => _locationTrackingEnabled = value)
                      : null,
                ),
                if (_isSettingsEditing && _locationTrackingEnabled)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () async {
                        await _checkLocationPermission();
                      },
                      child: const Text('Konum İzinlerini Kontrol Et'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Görünüm Ayarları',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Montserrat'),
                ),
                const SizedBox(height: 16),
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) {
                    // ThemeProvider'dan gelen değeri kullan
                    return SwitchListTile(
                      title: const Text('Karanlık Mod'),
                      subtitle: const Text('Uygulama arayüzünü koyu renkli görünüme çevir'),
                      value: _darkModeEnabled,
                      onChanged: _isSettingsEditing
                          ? (value) {
                        setState(() => _darkModeEnabled = value);
                      }
                          : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        if (_isSettingsEditing)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Ayarları Kaydet'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Image.asset(
                  'assets/images/depmo_logo.png',
                  width: 50,
                  height: 50,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Depmo',
                  style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold
                  ),
                ),
                const Text(
                  'Sürüm 1.0.0',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:depremproje/firebase_options.dart';
import 'package:depremproje/services/auth_service.dart';
import 'package:depremproje/screens/login_page.dart';
import 'package:depremproje/screens/home_page.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';
import 'package:depremproje/providers/theme_provider.dart';
import 'design.dart';
import 'package:depremproje/screens/profile_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Başlangıçta tema ayarını yükle
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: DepremApp(initialDarkMode: isDarkMode),
    ),
  );
}

class DepremApp extends StatelessWidget {
  final bool initialDarkMode;

  const DepremApp({super.key, this.initialDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        // Provider başlatıldığında tema ayarını yap - SADECE GEREKLI OLDUĞUNDA
        if (initialDarkMode && !themeProvider.isDarkMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            themeProvider.setTheme(initialDarkMode);
          });
        }

        return MaterialApp(
          title: DepmoDesign.appName,
          theme: DepmoDesign.getAppTheme(isDarkMode: false), // Varsayılan light tema
          darkTheme: DepmoDesign.getAppTheme(isDarkMode: true), // Dark tema
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return const DepremHaritasiSayfasi();
  }
}

// Deprem Service Sınıfı
class DepremService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'earthquakes'; // Firestore koleksiyon adı

  // DepremService sınıfına bu fonksiyonu ekleyin
  Future<void> clearCache() async {
    try {
      await _firestore.clearPersistence();
    } catch (e) {
      debugPrint('Cache temizlenirken hata: $e');
    }
  }

  // Tüm depremleri getir
  Future<List<Deprem>> getDepremler() async {
    try {
      print('Koleksiyon: $_collection');
      final querySnapshot = await _firestore
          .collection(_collection)
          .get(); // orderBy kaldırdım

      print('Document sayısı: ${querySnapshot.docs.length}');

      if (querySnapshot.docs.isNotEmpty) {
        print('İlk document: ${querySnapshot.docs.first.data()}');
      }

      return querySnapshot.docs
          .map((doc) => Deprem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Depremler getirilirken hata: $e');
      return [];
    }
  }

  // Gerçek zamanlı deprem akışı
  Stream<List<Deprem>> getDepremlerStream() {
    return _firestore
        .collection(_collection)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => Deprem.fromFirestore(doc))
        .toList());
  }

  // Yeni deprem ekle
  Future<void> addDeprem(Deprem deprem) async {
    try {
      await _firestore.collection(_collection).add(deprem.toFirestore());
    } catch (e) {
      debugPrint('Deprem eklenirken hata: $e');
    }
  }

  // Magnitude'e göre filtreli depremler getir
  Future<List<Deprem>> getDepremlerByMagnitude(double minMagnitude, {double? maxMagnitude}) async {
    try {
      Query query = _firestore
          .collection(_collection)
          .where('magnitude', isGreaterThanOrEqualTo: minMagnitude);

      if (maxMagnitude != null) {
        query = query.where('magnitude', isLessThan: maxMagnitude);
      }

      final querySnapshot = await query.get();

      return querySnapshot.docs
          .map((doc) => Deprem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Filtrelenmiş depremler getirilirken hata: $e');
      return [];
    }
  }
}

class DepremHaritasiSayfasi extends StatefulWidget {
  const DepremHaritasiSayfasi({super.key});

  @override
  State<DepremHaritasiSayfasi> createState() => _DepremHaritasiSayfasiState();
}

class _DepremHaritasiSayfasiState extends State<DepremHaritasiSayfasi> {
  List<Deprem> tumDepremler = [];
  List<Deprem> gosterilecekDepremler = [];
  bool yukleniyor = true;
  double? seciliFiltre;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final DepremService _depremService = DepremService();
  StreamSubscription<List<Deprem>>? _depremStreamSubscription;
  final MapController _mapController = MapController(); // Harita kontrolcüsü

  @override
  void dispose() {
    _audioPlayer.dispose();
    _depremStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _depremleriYukle();
    _gercekZamanliDepremleriDinle();
  }

  // Firestore'dan depremleri yükle
  Future<void> _depremleriYukle() async {
    setState(() {
      yukleniyor = true;
    });

    try {
      // Cache'i temizle
      await _depremService.clearCache();

      print('Depremler yükleniyor...');
      final depremler = await _depremService.getDepremler();

      // Eğer veri yoksa test verisi ekle
      if (depremler.isEmpty) {

        // Test verisi eklendikten sonra tekrar yükle
        final yeniDepremler = await _depremService.getDepremler();
        setState(() {
          tumDepremler = yeniDepremler;
          gosterilecekDepremler = List.from(tumDepremler);
          yukleniyor = false;
        });
      } else {
        setState(() {
          tumDepremler = depremler;
          gosterilecekDepremler = List.from(tumDepremler);
          yukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint('Deprem verileri yüklenirken hata oluştu: $e');
      setState(() {
        yukleniyor = false;
      });

      // Hata durumunda kullanıcıya bilgi ver
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deprem verileri yüklenirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Gerçek zamanlı deprem güncellemelerini dinle
  void _gercekZamanliDepremleriDinle() {
    _depremStreamSubscription = _depremService.getDepremlerStream().listen(
          (depremler) {
        if (mounted) {
          setState(() {
            tumDepremler = depremler;
            _filtrele(seciliFiltre); // Mevcut filtreyi uygula
          });
        }
      },
      onError: (error) {
        debugPrint('Gerçek zamanlı deprem dinlerken hata: $error');
      },
    );
  }

  // Düdük çalma fonksiyonu
  Future<void> _calDuduk() async {
    try {
      if (_audioPlayer.state == PlayerState.playing) {
        await _audioPlayer.stop();
      } else {
        await _audioPlayer.play(AssetSource('sounds/whistle.mp3'));
      }
    } catch (e) {
      debugPrint('Ses çalarken hata: $e');
    }
  }

  // Filtreleme fonksiyonu
  void _filtrele(double? minMagnitude) {
    setState(() {
      seciliFiltre = minMagnitude;

      if (minMagnitude == null) {
        gosterilecekDepremler = List.from(tumDepremler);
      } else if (minMagnitude == 6.0) {
        gosterilecekDepremler = tumDepremler
            .where((deprem) => deprem.magnitude >= 6.0)
            .toList();
      } else {
        double maxMagnitude = minMagnitude + 1.0;
        gosterilecekDepremler = tumDepremler
            .where((deprem) =>
        deprem.magnitude >= minMagnitude &&
            deprem.magnitude < maxMagnitude)
            .toList();
      }
    });
  }

  // Yenile fonksiyonu
  Future<void> _yenile() async {
    await _depremleriYukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depmo'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _yenile,
            tooltip: 'Yenile',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _filtreMenusunuGoster,
            tooltip: 'Deprem Büyüklüğüne Göre Filtrele',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              );
            },
            tooltip: 'Profil',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: yukleniyor
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Deprem verileri yükleniyor...'),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _yenile,
        child: Column(
          children: [
            if (seciliFiltre != null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filtre: ${_filtreTextiniGetir(seciliFiltre)} (${gosterilecekDepremler.length} deprem)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _filtrele(null),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: tumDepremler.isEmpty
                  ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Henüz deprem verisi bulunmuyor',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              )
                  : Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: const LatLng(39.0, 35.0), // Türkiye merkezi
                      zoom: 5.5,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.depremapp',
                      ),
                      MarkerLayer(
                        markers: _depremMarkerlariOlustur(),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      onPressed: _calDuduk,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.notifications_active, color: Colors.white),
                      tooltip: 'Acil Düdük',
                    ),
                  ),
                  // Deprem sayısını gösteren widget
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Toplam: ${gosterilecekDepremler.length} deprem',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Büyüklük Ölçeği:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _olcekItem('< 3.0', Colors.green),
                      _olcekItem('3.0 - 4.0', Colors.yellow),
                      _olcekItem('4.0 - 5.0', Colors.orange),
                      _olcekItem('5.0 - 6.0', Colors.deepOrange),
                      _olcekItem('> 6.0', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _filtreMenusunuGoster() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: const Text(
                  'Deprem Büyüklüğüne Göre Filtrele',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Tüm Depremler'),
                leading: Icon(
                  Icons.circle,
                  color: Colors.blue,
                  size: seciliFiltre == null ? 24 : 18,
                ),
                trailing: Text('${tumDepremler.length}'),
                selected: seciliFiltre == null,
                onTap: () {
                  Navigator.pop(context);
                  _filtrele(null);
                },
              ),
              ListTile(
                title: const Text('3.0 - 4.0 Büyüklüğünde'),
                leading: Icon(
                  Icons.circle,
                  color: Colors.yellow,
                  size: seciliFiltre == 3.0 ? 24 : 18,
                ),
                trailing: Text('${tumDepremler.where((d) => d.magnitude >= 3.0 && d.magnitude < 4.0).length}'),
                selected: seciliFiltre == 3.0,
                onTap: () {
                  Navigator.pop(context);
                  _filtrele(3.0);
                },
              ),
              ListTile(
                title: const Text('4.0 - 5.0 Büyüklüğünde'),
                leading: Icon(
                  Icons.circle,
                  color: Colors.orange,
                  size: seciliFiltre == 4.0 ? 24 : 18,
                ),
                trailing: Text('${tumDepremler.where((d) => d.magnitude >= 4.0 && d.magnitude < 5.0).length}'),
                selected: seciliFiltre == 4.0,
                onTap: () {
                  Navigator.pop(context);
                  _filtrele(4.0);
                },
              ),
              ListTile(
                title: const Text('5.0 - 6.0 Büyüklüğünde'),
                leading: Icon(
                  Icons.circle,
                  color: Colors.deepOrange,
                  size: seciliFiltre == 5.0 ? 24 : 18,
                ),
                trailing: Text('${tumDepremler.where((d) => d.magnitude >= 5.0 && d.magnitude < 6.0).length}'),
                selected: seciliFiltre == 5.0,
                onTap: () {
                  Navigator.pop(context);
                  _filtrele(5.0);
                },
              ),
              ListTile(
                title: const Text('6.0+ Büyüklüğünde'),
                leading: Icon(
                  Icons.circle,
                  color: Colors.red,
                  size: seciliFiltre == 6.0 ? 24 : 18,
                ),
                trailing: Text('${tumDepremler.where((d) => d.magnitude >= 6.0).length}'),
                selected: seciliFiltre == 6.0,
                onTap: () {
                  Navigator.pop(context);
                  _filtrele(6.0);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _filtreTextiniGetir(double? filtre) {
    if (filtre == null) return 'Tüm Depremler';
    if (filtre == 6.0) return '6.0+ Büyüklüğünde';
    return '${filtre.toStringAsFixed(1)} - ${(filtre + 1.0).toStringAsFixed(1)} Büyüklüğünde';
  }

  List<Marker> _depremMarkerlariOlustur() {
    return gosterilecekDepremler.map((deprem) {
      return Marker(
        width: _boyutHesapla(deprem.magnitude),
        height: _boyutHesapla(deprem.magnitude),
        point: LatLng(deprem.latitude, deprem.longitude),
        builder: (context) => GestureDetector(
          onTap: () {
            _depremDetaylariniGoster(deprem);
          },
          child: Container(
            decoration: BoxDecoration(
              color: _renkHesapla(deprem.magnitude).withAlpha(178),
              shape: BoxShape.circle,
              border: Border.all(
                color: _renkHesapla(deprem.magnitude),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                deprem.magnitude.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: deprem.magnitude > 5.0 ? 10 : 8,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _olcekItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  double _boyutHesapla(double magnitude) {
    // Deprem büyüklüğüne göre marker boyutu hesapla
    if (magnitude < 3.0) return 16.0;
    if (magnitude < 4.0) return 20.0;
    if (magnitude < 5.0) return 24.0;
    if (magnitude < 6.0) return 28.0;
    return 32.0;
  }

  Color _renkHesapla(double magnitude) {
    // Deprem büyüklüğüne göre renk hesapla
    if (magnitude < 3.0) {
      return Colors.green;
    } else if (magnitude < 4.0) {
      return Colors.yellow;
    } else if (magnitude < 5.0) {
      return Colors.orange;
    } else if (magnitude < 6.0) {
      return Colors.deepOrange;
    } else {
      return Colors.red;
    }
  }

  void _depremDetaylariniGoster(Deprem deprem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _renkHesapla(deprem.magnitude),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Büyüklük: ${deprem.magnitude}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detayItem(Icons.location_on, 'Konum', deprem.location),
              _detayItem(Icons.calendar_today, 'Tarih', deprem.date),
              _detayItem(Icons.access_time, 'Saat', deprem.time),
              _detayItem(Icons.height, 'Derinlik', '${deprem.depth} km'),
              _detayItem(Icons.place, 'Koordinatlar', '${deprem.latitude.toStringAsFixed(4)}, ${deprem.longitude.toStringAsFixed(4)}'),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Kapat'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Haritada konumu göster
                        Navigator.pop(context);
                        _mapController.move(
                          LatLng(deprem.latitude, deprem.longitude),
                          10.0,
                        );
                      },
                      icon: const Icon(Icons.map),
                      label: const Text('Haritada Göster'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detayItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

// Güncellenmiş Deprem sınıfı - Firestore uyumlu
class Deprem {
  final double latitude;
  final double longitude;
  final double magnitude;
  final double depth;
  final String date;
  final String location;
  final String time;
  final DateTime? timestamp; // Firestore için timestamp eklendi

  const Deprem({
    required this.latitude,
    required this.longitude,
    required this.magnitude,
    required this.depth,
    required this.date,
    required this.location,
    required this.time,
    this.timestamp,
  });

  // JSON'dan Deprem objesi oluştur (eski format uyumluluğu için)
  factory Deprem.fromJson(Map<String, dynamic> json) {
    return Deprem(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      magnitude: json['magnitude'].toDouble(),
      depth: json['depth'].toDouble(),
      date: json['date'],
      location: json['location'],
      time: json['time'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : null,
    );
  }

  // Firestore DocumentSnapshot'tan Deprem objesi oluştur
  factory Deprem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Deprem(
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      magnitude: (data['magnitude'] ?? 0.0).toDouble(),
      depth: (data['depth'] ?? 0.0).toDouble(),
      date: data['date'] ?? '',
      location: data['location'] ?? '',
      time: data['time'] ?? '',
      timestamp: DateTime.now(), // Sabit değer verin
    );
  }
// Firestore'a kaydetmek için Map'e dönüştür
  Map<String, dynamic> toFirestore() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'magnitude': magnitude,
      'depth': depth,
      'date': date,
      'location': location,
      'time': time,
      'timestamp': timestamp ?? DateTime.now(),
    };
  }

  // JSON'a dönüştür (eski format uyumluluğu için)
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'magnitude': magnitude,
      'depth': depth,
      'date': date,
      'location': location,
      'time': time,
      'timestamp': timestamp?.toIso8601String(),
    };
  }

  // Kopya oluştur
  Deprem copyWith({
    double? latitude,
    double? longitude,
    double? magnitude,
    double? depth,
    String? date,
    String? location,
    String? time,
    DateTime? timestamp,
  }) {
    return Deprem(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      magnitude: magnitude ?? this.magnitude,
      depth: depth ?? this.depth,
      date: date ?? this.date,
      location: location ?? this.location,
      time: time ?? this.time,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'Deprem{latitude: $latitude, longitude: $longitude, magnitude: $magnitude, depth: $depth, date: $date, location: $location, time: $time, timestamp: $timestamp}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Deprem &&
              runtimeType == other.runtimeType &&
              latitude == other.latitude &&
              longitude == other.longitude &&
              magnitude == other.magnitude &&
              depth == other.depth &&
              date == other.date &&
              location == other.location &&
              time == other.time;

  @override
  int get hashCode =>
      latitude.hashCode ^
      longitude.hashCode ^
      magnitude.hashCode ^
      depth.hashCode ^
      date.hashCode ^
      location.hashCode ^
      time.hashCode;
}
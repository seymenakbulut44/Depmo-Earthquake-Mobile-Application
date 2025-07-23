import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deprem Verisi',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Deprem Verisi Çekici'),
        ),
        body: const Center(
          child: Text('Deprem verisi alınıyor...'),
        ),
      ),
    );
  }
}

class EarthquakeService {
  static const String url = "https://kandilli.deno.dev/";

  Future<void> fetchAndSaveEarthquakeData() async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        List<dynamic> earthquakeData = json.decode(response.body);

        List<Map<String, dynamic>> filteredData = earthquakeData.map((quake) {
          return {
            "latitude": double.tryParse(quake["latitude"].toString()) ?? 0.0,
            "longitude": double.tryParse(quake["longitude"].toString()) ?? 0.0,
            "magnitude": double.tryParse(quake["ml"].toString()) ?? 0.0,
            "depth": double.tryParse(quake["depth"].toString()) ?? 0.0,
            "date": quake["date"],
            "time": quake["time"],
            "location": quake["location"],
          };
        }).toList();

        await _requestPermissions(); // izin al
        final file = await _localFile; // dosyayı hazırla
        await file.writeAsString(jsonEncode(filteredData), flush: true);

        print("✅ Veriler başarıyla Downloads klasörüne kaydedildi!");
      } else {
        print("❌ İstek başarısız oldu: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Hata oluştu: $e");
    }
  }

  Future<File> get _localFile async {
    final downloadsPath = Directory('/storage/emulated/0/Download/DepremVerisi');

    if (!(await downloadsPath.exists())) {
      await downloadsPath.create(recursive: true);
    }

    return File('${downloadsPath.path}/response.json');
  }

  Future<void> _requestPermissions() async {
    if (await Permission.manageExternalStorage.request().isGranted) {
      // izin verildi
    } else {
      print('⚠️ Depolama izni verilmedi!');
    }
  }
}

class EarthquakeFetcher {
  late Timer _timer;
  final EarthquakeService _service = EarthquakeService();

  EarthquakeFetcher() {
    _startFetching();
  }

  void _startFetching() {
    _service.fetchAndSaveEarthquakeData(); // ilk çalıştır
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) {
      _service.fetchAndSaveEarthquakeData(); // 20 sn'de bir tekrar
    });
  }

  void dispose() {
    _timer.cancel();
  }
}

// Ana uygulamada başlatıyoruz
final EarthquakeFetcher earthquakeFetcher = EarthquakeFetcher();
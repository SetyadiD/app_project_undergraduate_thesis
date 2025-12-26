// ignore_for_file: use_super_parameters, library_private_types_in_public_api, avoid_print, unnecessary_const, prefer_const_literals_to_create_immutables, prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

// Image Selection Class
class AmbilGambar {
  final ImagePicker picker = ImagePicker();

  Future<File?> pilihGambarDari(ImageSource source) async {
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
    );

    return pickedFile != null ? File(pickedFile.path) : null;
  }
}

// Detection Process Class
class MulaiProsesDeteksi {
  static const diseasePat = 'c1ff28076583429590e28a8d00191a61';
  static const diseaseUserId = 'lwailvmm1850';
  static const diseaseAppId = 'disease-pest-detector';
  static const diseaseModelId = 'detection-disease-pest';
  static const diseaseApiUrl =
      'https://api.clarifai.com/v2/users/$diseaseUserId/apps/$diseaseAppId/models/$diseaseModelId/outputs';

  Future<bool> verifikasiTanamanCabai(File image) async {
    try {
      List<int> imageBytes = await image.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer YOUR_OPENAI_API_KEY',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {
              'role': 'system',
              'content': 'Anda harus memberikan jawaban apakah foto tanaman yang diunggah adalah tanaman cabai atau bukan.',
            },
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": "GPT, tugas anda adalah memverifikasi apakah ini tanaman cabai atau bukan, cukup berikan jawaban 'yes' jika tanaman cabai atau 'no' jika bukan tanaman cabai."
                },
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/jpeg;base64,$base64Image"
                  }
                }
              ]
            }
          ],
          "max_tokens": 10
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        String gptResponse = data['choices'][0]['message']['content'].toLowerCase().trim();
        return gptResponse.contains('yes');
      } else {
        print('Error response: ${response.body}');
        throw Exception('Failed to verify plant: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in verification: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> deteksiPenyakit(File image) async {
    try {
      List<int> imageBytes = await image.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(diseaseApiUrl),
        headers: {
          'Authorization': 'Key $diseasePat',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "user_app_id": {"user_id": diseaseUserId, "app_id": diseaseAppId},
          'inputs': [
            {
              'data': {
                'image': {
                  'base64': base64Image,
                }
              }
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['outputs'] != null &&
            data['outputs'].isNotEmpty &&
            data['outputs'][0]['data'] != null &&
            data['outputs'][0]['data']['concepts'] != null) {
          final concepts = data['outputs'][0]['data']['concepts'];

          var highestConfidence = 0.0;
          Map<String, dynamic>? bestPrediction;

          for (var concept in concepts) {
            if (concept['value'] > highestConfidence) {
              highestConfidence = concept['value'];
              bestPrediction = concept;
            }
          }

          return bestPrediction;
        } else {
          throw Exception('Format response tidak sesuai');
        }
      } else {
        throw Exception('Failed to detect disease: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in detectDisease: $e');
      return null;
    }
  }
}

class ChiliDetectionPage extends StatefulWidget {
  const ChiliDetectionPage({super.key});

  @override
  _ChiliDetectionPageState createState() => _ChiliDetectionPageState();
}

class _ChiliDetectionPageState extends State<ChiliDetectionPage> {
  File? _image;
  bool _isLoading = false;
  String? _error;
  bool _isChiliPlant = false;
  Map<String, dynamic>? _diseaseDetection;
  Map<String, dynamic> _recommendationsMap = {};

  // Instances of new classes
  final AmbilGambar _ambilGambar = AmbilGambar();
  final MulaiProsesDeteksi _prosesDeteksi = MulaiProsesDeteksi();

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      final String jsonString = await rootBundle.loadString('assets/disease_recommendations.json');
      final data = json.decode(jsonString);
      setState(() {
        _recommendationsMap = data['recommendations'];
      });
    } catch (e) {
      print('Error loading recommendations: $e');
    }
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    final pickedImage = await _ambilGambar.pilihGambarDari(source);
    
    setState(() {
      if (pickedImage != null) {
        _image = pickedImage;
        _resetDetectionState();
      }
    });
  }

  void _resetDetectionState() {
    setState(() {
      _isChiliPlant = false;
      _diseaseDetection = null;
      _error = null;
    });
  }

  Future<void> _startDetectionProcess() async {
    if (_image == null) {
      setState(() {
        _error = 'Please select an image first';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Step 1: Verifikasi apakah itu tanaman cabai
      bool isChili = await _prosesDeteksi.verifikasiTanamanCabai(_image!);

      if (isChili) {
        // Step 2: Jika foto yang diunggah tanaman cabai, deteksi penyakit dan hama
        final diseaseResult = await _prosesDeteksi.deteksiPenyakit(_image!);
        
        setState(() {
          _isChiliPlant = true;
          _diseaseDetection = diseaseResult;
        });
      } else {
        _showNotChiliDialog();
      }
    } catch (e) {
      setState(() {
        _error = 'Error during detection: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDiseaseResult() {
    if (_diseaseDetection == null || _recommendationsMap.isEmpty) return Container();

    final condition = _diseaseDetection!['name'];
    final confidence = (_diseaseDetection!['value'] * 100).toStringAsFixed(1);

    final confidenceValue = _diseaseDetection!['value'] as double;

    // Jika tingkat kepercayaan kurang dari 30%, tampilkan pesan khusus
    if (confidenceValue < 0.3) {
      return Card(
        margin: const EdgeInsets.all(16),
        color: Colors.yellow[100],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Hasil Tidak Pasti',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                'Tingkat Kepercayaan: $confidence%',
                style: const TextStyle(fontSize: 16, color: Colors.purple),
              ),
              const SizedBox(height: 16),
              const Text(
                'Rekomendasi Umum:',
                style: const TextStyle(fontSize: 16, color: Colors.purple),
              ),
              const SizedBox(height: 8),
              const Text(
                '- Periksa tanaman secara menyeluruh\n'
                '- Konsultasikan dengan ahli pertanian\n'
                '- Lakukan pemeriksaan laboratorium\n'
                '- Ambil gambar dari sudut yang berbeda',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    // Get recommendation from JSON
    final recommendationData = _recommendationsMap[condition] ?? {
      'status_color': Colors.grey,
      'recommendation': 'Kondisi tidak dikenali'
    };

    Color statusColor;
    switch (recommendationData['status_color']) {
      case 'green':
        statusColor = Colors.green;
        break;
      case 'red':
        statusColor = Colors.red;
        break;
      case 'orange':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Kondisi: ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  condition.toUpperCase(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Rekomendasi dan Solusi Perawatan:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              recommendationData['recommendation'],
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showNotChiliDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bukan Tanaman Cabai'),
          content: const Text(
              'Gambar yang Anda unggah bukan tanaman cabai. Silakan ambil gambar lain.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Ambil Ulang'),
              onPressed: () {
                Navigator.of(context).pop();
                _showImageSourceDialog();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pilih Sumber Gambar'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kamera'),
                onTap: () {
                  Navigator.pop(context);
                  _getImageFromSource(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeri'),
                onTap: () {
                  Navigator.pop(context);
                  _getImageFromSource(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade100,
              Colors.green.shade200,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade500.withOpacity(0.2),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Deteksi Tanaman Cabai',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Deteksi jenis penyakit dan hama pada tanaman cabai hidroponik anda',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // Image Display Section
                Container(
                  height: MediaQuery.of(context).size.height * 0.4,  // Set fixed height ratio
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.shade300.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _image != null
                            ? Image.file(
                                _image!,
                                fit: BoxFit.cover,
                              )
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 60,  // Reduced icon size
                                      color: Colors.green.shade300,
                                    ),
                                    const SizedBox(height: 12),  // Reduced spacing
                                    Text(
                                      'Ketuk untuk memilih gambar',
                                      style: TextStyle(
                                        fontSize: 16,  // Reduced font size
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                // Loading and Results Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    children: [
                      if (_isLoading)
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        )
                      else if (_error != null)
                        Card(
                          color: Colors.red[100],
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              _error!,
                              style: TextStyle(color: Colors.red[900]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      else if (_isChiliPlant) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: const Text(
                            'Terverifikasi tanaman cabai ✓',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (_diseaseDetection != null) _buildDiseaseResult(),
                      ],
                    ],
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),  // Adjusted bottom padding
                  child: Column(
                    children: [
                      // Select Image Button
                      Container(
                        height: 48,  // Reduced height
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade200,
                              blurRadius: 8,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _showImageSourceDialog,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  color: Colors.white,
                                  size: 20,  // Reduced icon size
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Pilih Gambar',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,  // Reduced font size
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),  // Reduced spacing
                      // Predict Disease Button
                      if (_image != null)  // Hanya menampilkan tombol prediksi ketika gambar dipilih
                        Container(
                          height: 48,  // Reduced height
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: LinearGradient(
                              colors: _isLoading
                                  ? [Colors.grey.shade400, Colors.grey.shade600]
                                  : [Colors.blue.shade400, Colors.blue.shade600],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _isLoading
                                    ? Colors.grey.shade200
                                    : Colors.blue.shade200,
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _isLoading ? null : _startDetectionProcess,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: Colors.white,
                                    size: 20,  // Reduced icon size
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Deteksi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,  // Reduced font size
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_isLoading) ...[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Selamat Datang di Aplikasi Pendeteksi\nJenis Penyakit dan Hama\nPada Tanaman Cabai',
        style: TextStyle(fontSize: 24),
        textAlign: TextAlign.center,
      ),
    );
  }
}

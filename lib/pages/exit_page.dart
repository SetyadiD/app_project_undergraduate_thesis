// lib/pages/exit_page.dart
// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ExitPage extends StatelessWidget {
  const ExitPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Keluar Aplikasi'),
                content:
                    const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Batal'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: const Text('Keluar'),
                    onPressed: () {
                      SystemNavigator.pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Text('Keluar dari Aplikasi'),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:image_upload/widgets/image.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Uploader'),
      ),
      body: const ImageWidget(),
    );
  }
}

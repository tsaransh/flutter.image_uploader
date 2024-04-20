import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider package

class ImageWidget extends StatefulWidget {
  const ImageWidget({super.key});

  @override
  State<StatefulWidget> createState() {
    return _ImageWidgetState();
  }
}

class _ImageWidgetState extends State<ImageWidget> {
  final List<File> _imageList = [];
  final List<File> _selectedImages = [];
  int uploadImageIndex = 0;
  bool _isUploading = false;
  bool _gettingData = true;
  int fetchImageIndex = 0;

  bool _inViewCard = true;

  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _fetchImages();
    startChangingImage();
  }

  void startChangingImage() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        if (fetchImageIndex < _imageList.length - 1) {
          fetchImageIndex++;
        } else {
          fetchImageIndex = 0;
        }
      });
    });
  }

  Future<void> _uploadImage() async {
    if (_selectedImages.isEmpty) {
      _showMessage("No Image Found");
      return;
    }
    setState(() {
      _isUploading = true;
    });
    for (var i = 0; i < _selectedImages.length; i++) {
      String uid = DateTime.now().toIso8601String();

      final storageRef =
          FirebaseStorage.instance.ref().child("user_images").child('$uid.jpg');

      await storageRef.putFile(_selectedImages[i]);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection("user_images_urls")
          .doc(uid)
          .set({'image_url': downloadUrl});
      setState(() {
        uploadImageIndex = i;
      });
    }
    setState(() {
      _isUploading = false;
      _inViewCard = !_inViewCard;
      _selectedImages.clear();
    });
    _fetchImages();
    _showMessage("Image uploaded");
  }

  Future<void> _fetchImages() async {
    setState(() {
      _imageList.clear();
      _gettingData = true;
    });
    try {
      final images =
          await FirebaseFirestore.instance.collection('user_images_urls').get();
      for (var doc in images.docs) {
        final data = doc.data();
        final imageUrl = data['image_url'];
        final ref = FirebaseStorage.instance.refFromURL(imageUrl);
        final tempDir = await getTemporaryDirectory();
        final String filePath =
            '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await ref.writeToFile(File(filePath));
        setState(() {
          _imageList.add(File(filePath));
          _gettingData = false;
        });
      }
    } catch (error) {
      print('Error fetching images: $error');
      _showMessage(error.toString());
    } finally {
      setState(() {
        _gettingData = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return !_gettingData
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 500,
                  width: 350,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.9),
                        spreadRadius: 1,
                        blurRadius: 7,
                        offset: const Offset(0, 1),
                      ),
                    ],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _imageList.isNotEmpty && _inViewCard
                      ? _buildImageViewCard()
                      : _buildImageUploadCard(),
                ),
              ],
            ),
          )
        : const Center(
            child: CircularProgressIndicator(),
          );
  }

  Widget _buildImageViewCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Your Images",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _inViewCard = !_inViewCard;
                });
              },
              child: const Icon(Icons.add),
            )
          ],
        ),
        SizedBox(
          height: 250,
          width: 250,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: FileImage(
                  _imageList[fetchImageIndex],
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Text("${_imageList.length} images found!")
      ],
    );
  }

  Widget _buildImageUploadCard() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Text(
          _selectedImages.isEmpty ? 'Add Image' : 'Ready to upload',
          style: GoogleFonts.roboto(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(
          height: 250,
          width: 250,
          child: GestureDetector(
            onTap: _showUploadImageAlertBox,
            child: Dismissible(
              key: UniqueKey(),
              onDismissed: (DismissDirection direction) {
                setState(() {
                  if (uploadImageIndex < _selectedImages.length - 1) {
                    uploadImageIndex++;
                  } else {
                    uploadImageIndex = 0;
                  }
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: _selectedImages.isNotEmpty
                      ? DecorationImage(
                          image: FileImage(
                            _selectedImages[uploadImageIndex],
                          ),
                          fit: BoxFit.cover,
                        )
                      : const DecorationImage(
                          image:
                              AssetImage('assets/images/default_profile.png'),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
          ),
        ),
        !_isUploading
            ? ElevatedButton.icon(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(
                      Theme.of(context).colorScheme.secondary),
                  foregroundColor: MaterialStateProperty.all<Color>(
                      Theme.of(context).colorScheme.onSecondary),
                ),
                onPressed: _isUploading ? null : _uploadImage,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload Image'),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  const Text('Uploading'),
                  CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
      ],
    );
  }

  void _showUploadImageAlertBox() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text(
            'Upload an Image',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: _pickFromCamera,
                child: const Icon(Icons.camera),
              ),
              TextButton(
                onPressed: _pickFromPhotos,
                child: const Icon(Icons.photo),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    final pickedImage = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
      maxHeight: 200,
    );
    if (pickedImage == null) {
      return;
    }
    setState(() {
      _selectedImages.add(File(pickedImage.path));
      Navigator.of(context).pop();
    });
  }

  Future<void> _pickFromPhotos() async {
    final pickedImages = await ImagePicker().pickMultiImage(
      imageQuality: 100,
      maxWidth: 200,
    );

    setState(() {
      _selectedImages.clear();
      if (pickedImages != null) {
        _selectedImages.addAll(pickedImages.map((image) => File(image.path)));
      }
      Navigator.of(context).pop();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(message),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).clearSnackBars();
              },
              child: const Text(
                'Okay',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

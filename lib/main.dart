import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  bool _overwriteWithoutPrompt = false;

  void _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        _selectedImages = images.map((e) => File(e.path)).toList();
      });
      _showOptionsDialog();
    }
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select an Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Remove Metadata'),
                onTap: _removeMetadata,
              ),
              ListTile(
                title: Text('Resize Images'),
                onTap: _resizeImages,
              ),
              ListTile(
                title: Text('Convert Image Format'),
                onTap: _convertImageFormat,
              ),
            ],
          ),
        );
      },
    );
  }

  void _removeMetadata() async {
    Navigator.pop(context);
    for (var image in _selectedImages) {
      final data = await image.readAsBytes();
      final decodedImage = img.decodeImage(data);
      if (decodedImage != null) {
        final newData = img.encodeJpg(decodedImage);
        await image.writeAsBytes(newData, flush: true);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Metadata removed from images.')),
    );
  }

  void _resizeImages() async {
    Navigator.pop(context);
    final resolutions = {
      '640x480': [640, 480],
      '1024x768': [1024, 768],
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Choose Resolution'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: resolutions.keys.map((key) {
              return ListTile(
                title: Text(key),
                onTap: () async {
                  await _processResize(resolutions[key]!);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
          actions: [
            CheckboxListTile(
              title: Text('Resize In Place'),
              value: _overwriteWithoutPrompt,
              onChanged: (value) {
                setState(() {
                  _overwriteWithoutPrompt = value ?? false;
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _processResize(List<int> resolution) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String outputDirPath = '${appDir.path}/AlteredPhotos';
    Directory outputDir = Directory(outputDirPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    for (var image in _selectedImages) {
      final data = await image.readAsBytes();
      final decodedImage = img.decodeImage(data);
      if (decodedImage != null) {
        final resizedImage = img.copyResize(decodedImage, width: resolution[0], height: resolution[1]);
        final newFileName = '${outputDir.path}/${image.uri.pathSegments.last}';
        final newFile = File(newFileName);
        if (!await newFile.exists() || _overwriteWithoutPrompt || await _confirmOverwrite()) {
          await newFile.writeAsBytes(img.encodeJpg(resizedImage), flush: true);
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Images resized and saved.')),
    );
  }

  Future<void> _convertImageFormat() async {
    Navigator.pop(context);
    final formats = {
      'JPEG': 'jpg',
      'PNG': 'png',
      'BMP': 'bmp',
      'GIF': 'gif',
      'TIFF': 'tiff',
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Choose Format'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: formats.keys.map((key) {
              return ListTile(
                title: Text(key),
                onTap: () async {
                  await _processFormatConversion(formats[key]!);
                  Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _processFormatConversion(String format) async {
    Directory appDir = await getApplicationDocumentsDirectory();
    String outputDirPath = '${appDir.path}/AlteredPhotos';
    Directory outputDir = Directory(outputDirPath);
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    for (var image in _selectedImages) {
      final data = await image.readAsBytes();
      final decodedImage = img.decodeImage(data);
      if (decodedImage != null) {
        final newFileName = '${outputDir.path}/${image.uri.pathSegments.last.split('.')[0]}.$format';
        final newFile = File(newFileName);
        if (!await newFile.exists() || _overwriteWithoutPrompt || await _confirmOverwrite()) {
          List<int>? encodedData;
          switch (format) {
            case 'jpg':
              encodedData = img.encodeJpg(decodedImage);
              break;
            case 'png':
              encodedData = img.encodePng(decodedImage);
              break;
            case 'bmp':
              encodedData = img.encodeBmp(decodedImage);
              break;
            case 'gif':
              encodedData = img.encodeGif(decodedImage);
              break;
            case 'tiff':
              encodedData = img.encodeTiff(decodedImage);
              break;
          }
          if (encodedData != null) {
            await newFile.writeAsBytes(encodedData, flush: true);
          }
        }
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Images converted and saved.')),
    );
  }

  Future<bool> _confirmOverwrite() async {
    bool overwrite = false;
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Overwrite Confirmation'),
          content: Text('A file with the same name exists. Overwrite?'),
          actions: [
            TextButton(
              onPressed: () {
                overwrite = false;
                Navigator.pop(context);
              },
              child: Text('No'),
            ),
            TextButton(
              onPressed: () {
                overwrite = true;
                Navigator.pop(context);
              },
              child: Text('Yes'),
            ),
          ],
        );
      },
    );
    return overwrite;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Processor')),
      body: Center(
        child: ElevatedButton(
          onPressed: _pickImages,
          child: Text('Select Images'),
        ),
      ),
    );
  }
}

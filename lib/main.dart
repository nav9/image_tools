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
  bool _resizeInPlace = false;
  int _minWidth = 1;
  int _minHeight = 1;
  int _maxWidth = 0;
  int _maxHeight = 0;

  void _pickImages() async {
    final List<XFile>? images = await _picker.pickMultiImage();
    if (images != null) {
      setState(() {
        _selectedImages = images.map((e) => File(e.path)).toList();
      });
      _determineMaxDimensions();
      _showOptionsDialog();
    }
  }

  void _determineMaxDimensions() async {
    for (var image in _selectedImages) {
      final data = await image.readAsBytes();
      final decodedImage = img.decodeImage(data);
      if (decodedImage != null) {
        _maxWidth = _maxWidth < decodedImage.width ? decodedImage.width : _maxWidth;
        _maxHeight = _maxHeight < decodedImage.height ? decodedImage.height : _maxHeight;
      }
    }
  }

  void _showOptionsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select an Option'),
          content: SingleChildScrollView(
            child: Column(
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

    double width = _maxWidth.toDouble();
    double height = _maxHeight.toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Resize Images'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Width: ${width.toInt()}'),
                Slider(
                  value: width,
                  min: _minWidth.toDouble(),
                  max: _maxWidth.toDouble(),
                  divisions: _maxWidth - _minWidth,
                  label: width.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      width = value;
                    });
                  },
                ),
                Text('Height: ${height.toInt()}'),
                Slider(
                  value: height,
                  min: _minHeight.toDouble(),
                  max: _maxHeight.toDouble(),
                  divisions: _maxHeight - _minHeight,
                  label: height.toInt().toString(),
                  onChanged: (value) {
                    setState(() {
                      height = value;
                    });
                  },
                ),
                CheckboxListTile(
                  title: Text('Resize In Place'),
                  value: _resizeInPlace,
                  onChanged: (value) {
                    setState(() {
                      _resizeInPlace = value ?? false;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await _processResize(width.toInt(), height.toInt());
                Navigator.pop(context);
              },
              child: Text('Resize'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processResize(int width, int height) async {
    for (var image in _selectedImages) {
      final data = await image.readAsBytes();
      final decodedImage = img.decodeImage(data);
      if (decodedImage != null) {
        final resizedImage = img.copyResize(decodedImage, width: width, height: height);
        if (_resizeInPlace) {
          await image.writeAsBytes(img.encodeJpg(resizedImage), flush: true);
        } else {
          final directory = image.parent;
          final outputDirPath = '${directory.path}/resizedImages';
          Directory outputDir = Directory(outputDirPath);
          if (!await outputDir.exists()) {
            await outputDir.create(recursive: true);
          }
          final newFileName = '${outputDir.path}/${image.uri.pathSegments.last.split('.')[0]}_${width}x${height}.jpg';
          final newFile = File(newFileName);
          if (!await newFile.exists() || _overwriteWithoutPrompt || await _confirmOverwrite()) {
            await newFile.writeAsBytes(img.encodeJpg(resizedImage), flush: true);
          }
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
      'ICO': 'ico',
      'PSD': 'psd',
      'TGA': 'tga',
      'PNM': 'pnm',
    };

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Choose Format'),
          content: SingleChildScrollView(
            child: Column(
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
          ),
        );
      },
    );
  }

  Future<void> _processFormatConversion(String format) async {
    for (var image in _selectedImages) {
      final data = await image.readAsBytes();
      final decodedImage = img.decodeImage(data);
      if (decodedImage != null) {
        final directory = image.parent;
        final outputDirPath = '${directory.path}/convertedImages';
        Directory outputDir = Directory(outputDirPath);
        if (!await outputDir.exists()) {
          await outputDir.create(recursive: true);
        }
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
            default:
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unsupported format: $format')),
              );
              continue;
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
      body: Scrollbar(
        child: Center(
          child: ElevatedButton(
            onPressed: _pickImages,
            child: Text('Select Images'),
          ),
        ),
      ),
    );
  }
}

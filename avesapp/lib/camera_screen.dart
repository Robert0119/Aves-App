import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  Position? _position;
  bool _isLoading = false;
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.location,
      Permission.photos,
    ].request();
  }

  Future<void> _takePicture() async {
    await _requestPermissions();
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          _imageFile = image;
        });
        
        // Obtener ubicación automáticamente
        await _getCurrentLocation();
        
        // Mostrar diálogo de confirmación inmediatamente
        _showUploadDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al tomar la foto: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    await _requestPermissions();
    
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      
      if (image != null) {
        setState(() {
          _imageFile = image;
        });
        
        // Obtener ubicación
        await _getCurrentLocation();
        
        // Mostrar diálogo de confirmación
        _showUploadDialog();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar la foto: $e')),
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    print('Iniciando obtención de ubicación...');
    
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Servicio de ubicación habilitado: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('Servicios de ubicación desactivados');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servicios de ubicación desactivados')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      print('Permiso actual: $permission');
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        print('Permiso después de solicitar: $permission');
        
        if (permission == LocationPermission.denied) {
          print('Permisos de ubicación denegados');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación denegados')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Permisos de ubicación denegados permanentemente');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permisos de ubicación denegados permanentemente. Ve a configuración para habilitarlos.'),
          ),
        );
        return;
      }

      print('Obteniendo posición actual...');
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      print('Ubicación obtenida: ${position.latitude}, ${position.longitude}');
      print('Position object: $position');
      print('Accuracy: ${position.accuracy}m');
      
      setState(() {
        _position = position;
      });
      
      // Verificar que se guardó correctamente
      print('Position guardado en estado: lat=${_position?.latitude}, lng=${_position?.longitude}');
      
    } catch (e) {
      print('Error detallado al obtener ubicación: $e');
      print('Tipo de error: ${e.runtimeType}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al obtener ubicación: $e')),
        );
      }
    }
  }

  Future<void> _uploadPost() async {
    if (_imageFile == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      print('Subiendo imagen...');
      
      // Crear referencia con nombre único
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child('posts/$fileName');

      // Configurar metadata explícitamente para evitar el error
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'max-age=3600',
      );

      // Subir archivo con metadata especificado
      final uploadTask = storageRef.putFile(File(_imageFile!.path), metadata);
      
      // Escuchar el progreso de subida (opcional)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Progreso de subida: ${(progress * 100).toStringAsFixed(2)}%');
      });

      final snapshot = await uploadTask;
      final imageUrl = await snapshot.ref.getDownloadURL();

      print('Imagen subida exitosamente. URL: $imageUrl');

      // Verificar datos antes de enviar a Firestore
      print('Datos a enviar a Firestore:');
      print('- Latitude: ${_position?.latitude}');
      print('- Longitude: ${_position?.longitude}');
      print('- HasLocation: ${_position != null}');

      // Crear documento en Firestore con validación adicional
      final postData = {
        'userId': user.uid,
        'userName': user.displayName ?? user.email ?? 'Usuario',
        'userEmail': user.email ?? '',
        'imageUrl': imageUrl,
        'description': _descriptionController.text.trim(),
        'latitude': _position?.latitude ?? 0.0,
        'longitude': _position?.longitude ?? 0.0,
        'hasLocation': _position != null,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'likesCount': 0,
        'createdAt': DateTime.now().toIso8601String(),
      };

      print('Post data completo: $postData');

      // Validar que los datos no estén vacíos
      if (postData['imageUrl'] == null || postData['imageUrl'] == '') {
        throw Exception('Error: URL de imagen vacía');
      }

      await FirebaseFirestore.instance.collection('posts').add(postData);

      print('Post creado exitosamente en Firestore');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto subida exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Limpiar datos después de subida exitosa
        setState(() {
          _imageFile = null;
          _position = null;
          _descriptionController.clear();
        });
        
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error detallado al subir: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir la foto: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showUploadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Subir foto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_imageFile != null)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: FileImage(File(_imageFile!.path)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    hintText: 'Describe el ave que fotografiaste...',
                    border: OutlineInputBorder(),
                    labelText: 'Descripción',
                  ),
                  maxLines: 3,
                  maxLength: 200,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      _position != null ? Icons.location_on : Icons.location_off,
                      color: _position != null ? Colors.green : Colors.grey,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _position != null 
                            ? 'Ubicación capturada'
                            : 'Sin ubicación',
                        style: TextStyle(
                          color: _position != null ? Colors.green[700] : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isLoading ? null : () {
                Navigator.of(context).pop();
                setState(() {
                  _imageFile = null;
                  _position = null;
                  _descriptionController.clear();
                });
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : () {
                Navigator.of(context).pop();
                _uploadPost();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: _isLoading 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Subir'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Compartir foto'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 16),
                  Text('Subiendo foto...'),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const Icon(
                      Icons.camera_alt,
                      size: 128,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Comparte una foto de ave',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Toma una foto o selecciona desde galería',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 48),
                    
                    // Botones de acción
                    Column(
                      children: [
                        SizedBox(
                          width: 200,
                          child: ElevatedButton.icon(
                            onPressed: _takePicture,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Tomar foto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        SizedBox(
                          width: 200,
                          child: OutlinedButton.icon(
                            onPressed: _pickFromGallery,
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Desde galería'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                              side: const BorderSide(color: Color(0xFF2E7D32)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Información adicional
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.location_on, color: Color(0xFF2E7D32), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Se capturará la ubicación automáticamente',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.psychology, color: Color(0xFF2E7D32), size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Podrás identificar la especie con IA después',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
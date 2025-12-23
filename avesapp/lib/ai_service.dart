import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class AIService {
  static Interpreter? _interpreter;
  static bool _isModelLoaded = false;
  
  static const List<String> _labels = [
    "Otras Aves", 
    "Chlorostilbon melanorhynchus"
  ];
  
  static const int _inputSize = 224;

  /// Inicializa el modelo de IA
  static Future<bool> loadModel() async {
    try {
      print('Cargando modelo de IA...');
      
      // Cargar el modelo desde assets
      _interpreter = await Interpreter.fromAsset('assets/modelo_colibri.tflite');
      
      print('Modelo de IA cargado exitosamente');
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      
      _isModelLoaded = true;
      return true;
    } catch (e) {
      print('Error cargando modelo de IA: $e');
      _isModelLoaded = false;
      return false;
    }
  }

  /// Analiza una imagen y predice si es un colibrí
  static Future<AIResult?> analyzeImage(String imagePath) async {
    if (!_isModelLoaded) {
      print('Modelo no cargado. Intentando cargar...');
      bool loaded = await loadModel();
      if (!loaded) {
        return AIResult(
          prediction: "Error", 
          confidence: 0.0, 
          isHummingbird: false,
          error: "No se pudo cargar el modelo de IA"
        );
      }
    }

    try {
      print('Analizando imagen: $imagePath');
      
      // Leer y procesar la imagen
      File imageFile = File(imagePath);
      img.Image? image = img.decodeImage(await imageFile.readAsBytes());
      if (image == null) {
        throw Exception('No se pudo decodificar la imagen');
      }
      
      // Redimensionar a 224x224
      img.Image resizedImage = img.copyResize(
        image, 
        width: _inputSize, 
        height: _inputSize,
      );
      
      // Preparar buffer de entrada [1, 224, 224, 3]
      var inputBuffer = Float32List(1 * _inputSize * _inputSize * 3);
      int pixelIndex = 0;
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          var pixel = resizedImage.getPixel(x, y);
          inputBuffer[pixelIndex++] = pixel.r / 255.0;
          inputBuffer[pixelIndex++] = pixel.g / 255.0;
          inputBuffer[pixelIndex++] = pixel.b / 255.0;
        }
      }
      
      // IMPORTANTE: Crear el buffer de salida con la forma correcta [1, 1]
      var outputBuffer = List.filled(1, List<double>.filled(1, 0.0));
      
      // Ejecutar la inferencia
      _interpreter!.run(inputBuffer.reshape([1, _inputSize, _inputSize, 3]), outputBuffer);
      
      // Interpretar el resultado
      double probability = outputBuffer[0][0];
      int prediction = probability > 0.5 ? 1 : 0;
      double confidence = prediction == 1 ? probability : 1 - probability;
      
      String speciesName = _labels[prediction];
      bool isHummingbird = prediction == 1;
      
      print('Predicción: $speciesName');
      print('Confianza: ${(confidence * 100).toStringAsFixed(1)}%');
      
      return AIResult(
        prediction: speciesName,
        confidence: confidence,
        isHummingbird: isHummingbird,
        rawProbability: probability
      );
      
    } catch (e) {
      print('Error analizando imagen: $e');
      return AIResult(
        prediction: "Error", 
        confidence: 0.0, 
        isHummingbird: false,
        error: "Error durante el análisis: $e"
      );
    }
  }

  /// Liberar recursos del modelo
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
    print('Modelo de IA liberado de memoria');
  }
}

/// Clase para los resultados del análisis
class AIResult {
  final String prediction;
  final double confidence;
  final bool isHummingbird;
  final double? rawProbability;
  final String? error;

  AIResult({
    required this.prediction,
    required this.confidence,
    required this.isHummingbird,
    this.rawProbability,
    this.error,
  });

  /// Obtiene un mensaje descriptivo del resultado
  String get description {
    if (error != null) return error!;
    
    if (isHummingbird) {
      return 'Esta es una imagen de un Colibrí Esmeralda Occidental (Chlorostilbon melanorhynchus) con ${(confidence * 100).toStringAsFixed(1)}% de confianza.';
    } else {
      return 'Esta imagen parece ser de otra especie de ave (no colibrí) con ${(confidence * 100).toStringAsFixed(1)}% de confianza.';
    }
  }

  /// Obtiene el color asociado al resultado
  String get confidenceLevel {
    if (confidence >= 0.9) return 'Muy alta';
    if (confidence >= 0.7) return 'Alta';
    if (confidence >= 0.5) return 'Media';
    return 'Baja';
  }
}
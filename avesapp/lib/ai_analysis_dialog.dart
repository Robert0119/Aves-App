import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'ai_service.dart';

class AIAnalysisDialog extends StatefulWidget {
  final String imageUrl;

  const AIAnalysisDialog({
    super.key,
    required this.imageUrl,
  });

  @override
  State<AIAnalysisDialog> createState() => _AIAnalysisDialogState();
}

class _AIAnalysisDialogState extends State<AIAnalysisDialog> {
  bool _isAnalyzing = true;
  AIResult? _result;
  String _status = 'Iniciando análisis...';

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    try {
      setState(() {
        _status = 'Descargando imagen...';
      });

      // Descargar imagen desde Firebase Storage
      String imagePath = await _downloadImage(widget.imageUrl);

      setState(() {
        _status = 'Analizando con IA...';
      });

      // Analizar con IA
      AIResult? result = await AIService.analyzeImage(imagePath);

      // Limpiar archivo temporal
      await File(imagePath).delete();

      setState(() {
        _result = result;
        _isAnalyzing = false;
      });

    } catch (e) {
      setState(() {
        _result = AIResult(
          prediction: "Error",
          confidence: 0.0,
          isHummingbird: false,
          error: "Error durante el análisis: $e"
        );
        _isAnalyzing = false;
      });
    }
  }

  Future<String> _downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Error descargando imagen: ${response.statusCode}');
      }

      final directory = await getTemporaryDirectory();
      final fileName = 'temp_analysis_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (e) {
      throw Exception('Error descargando imagen: $e');
    }
  }

  Widget _buildLoadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 60,
          height: 60,
          child: CircularProgressIndicator(
            color: Color(0xFF2E7D32),
            strokeWidth: 4,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _status,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Esto puede tomar unos segundos...',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildResultContent() {
    if (_result == null) return const SizedBox();

    final hasError = _result!.error != null;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono del resultado
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: hasError
                ? Colors.red[50]
                : _result!.isHummingbird
                    ? Colors.green[50]
                    : Colors.orange[50],
            shape: BoxShape.circle,
          ),
          child: Icon(
            hasError
                ? Icons.error_outline
                : _result!.isHummingbird
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
            size: 48,
            color: hasError
                ? Colors.red[600]
                : _result!.isHummingbird
                    ? Colors.green[600]
                    : Colors.orange[600],
          ),
        ),
        
        const SizedBox(height: 24),

        // Título del resultado
        Text(
          hasError ? 'Error en el análisis' : '¡Análisis completado!',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Predicción
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Predicción:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _result!.prediction,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        if (!hasError) ...[
          const SizedBox(height: 12),

          // Confianza
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nivel de confianza:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _result!.confidence,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _result!.confidence >= 0.7
                              ? Colors.green
                              : _result!.confidence >= 0.5
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(_result!.confidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Confianza: ${_result!.confidenceLevel}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Descripción
          Text(
            _result!.description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const SizedBox(height: 16),
          Text(
            _result!.error!,
            style: TextStyle(
              fontSize: 14,
              color: Colors.red[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        const SizedBox(height: 24),

        // Información adicional si es colibrí
        if (!hasError && _result!.isHummingbird) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.green[600], size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Sobre esta especie:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'El Colibrí Esmeralda Occidental es una especie endémica de los Andes. Se caracteriza por su plumaje verde brillante y es conocido por su vuelo ágil y rápido.',
                  style: TextStyle(fontSize: 13, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: Colors.purple[600],
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Análisis con IA',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (!_isAnalyzing)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Contenido
            _isAnalyzing ? _buildLoadingContent() : _buildResultContent(),
            
            // Acciones
            if (!_isAnalyzing) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Opcional: compartir resultado
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
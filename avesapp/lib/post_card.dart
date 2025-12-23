import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostCard extends StatefulWidget {
  final QueryDocumentSnapshot post;

  const PostCard({super.key, required this.post});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLiked = false;
  int likesCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeLikes();
  }

  void _initializeLikes() {
    final data = widget.post.data() as Map<String, dynamic>;
    likesCount = data['likesCount'] ?? 0;
    
    // Verificar si el usuario actual dio like
    final likes = List<String>.from(data['likes'] ?? []);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    isLiked = currentUserId != null && likes.contains(currentUserId);
  }

  Future<void> _toggleLike() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final postRef = FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.post.id);

      if (isLiked) {
        // Quitar like
        await postRef.update({
          'likes': FieldValue.arrayRemove([currentUserId]),
          'likesCount': FieldValue.increment(-1),
        });
        setState(() {
          isLiked = false;
          likesCount--;
        });
      } else {
        // Dar like
        await postRef.update({
          'likes': FieldValue.arrayUnion([currentUserId]),
          'likesCount': FieldValue.increment(1),
        });
        setState(() {
          isLiked = true;
          likesCount++;
        });
      }
    } catch (e) {
      print('Error al actualizar like: $e');
    }
  }

  void _showLocationDialog() {
    final data = widget.post.data() as Map<String, dynamic>;
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ubicación de la foto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFF2E7D32),
                size: 48,
              ),
              const SizedBox(height: 16),
              if (latitude != null && longitude != null)
                Text(
                  'Lat: ${latitude.toStringAsFixed(6)}\nLng: ${longitude.toStringAsFixed(6)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'monospace'),
                )
              else
                const Text('Ubicación no disponible'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  void _analyzeWithAI() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Análisis con IA'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.psychology,
                color: Color(0xFF2E7D32),
                size: 48,
              ),
              SizedBox(height: 16),
              Text(
                'Analizando imagen con IA...\n\nFuncionalidad en desarrollo',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.post.data() as Map<String, dynamic>;
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del post con información del usuario
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF2E7D32),
                  radius: 16,
                  child: Text(
                    (data['userName'] ?? 'U').substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['userName'] ?? 'Usuario',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (data['timestamp'] != null)
                        Text(
                          _formatTimestamp(data['timestamp']),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Imagen
          if (data['imageUrl'] != null)
            Image.network(
              data['imageUrl'],
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 300,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 64,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),

          // Botones de acción
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Botón de like
                IconButton(
                  onPressed: _toggleLike,
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.grey[600],
                  ),
                ),
                Text('$likesCount'),
                
                const SizedBox(width: 16),
                
                // Botón de ubicación
                IconButton(
                  onPressed: _showLocationDialog,
                  icon: Icon(
                    Icons.location_on,
                    color: Colors.blue[600],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Botón de IA
                IconButton(
                  onPressed: _analyzeWithAI,
                  icon: Icon(
                    Icons.psychology,
                    color: Colors.purple[600],
                  ),
                ),
              ],
            ),
          ),

          // Descripción si existe
          if (data['description'] != null && data['description'].isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
              child: Text(
                data['description'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Ahora';
    }
  }
}
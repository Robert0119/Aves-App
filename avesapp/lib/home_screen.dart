import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'camera_screen.dart';
import 'map_screen.dart';
import 'ai_analysis_dialog.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'AvesApp',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Header con información del usuario

          // Feed de posts reales desde Firestore
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('Error al cargar las publicaciones'),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF2E7D32),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_camera,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No hay publicaciones aún',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Sé el primero en compartir una foto de ave',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final post = snapshot.data!.docs[index];
                    final data = post.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header del post
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  radius: 16,
                                  child: Text(
                                    _getFirstChar(data['userName']),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

                          // Imagen del post
                          if (data['imageUrl'] != null)
                            Image.network(
                              data['imageUrl'],
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 300,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 300,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.broken_image,
                                            size: 64, color: Colors.grey),
                                        Text('Error al cargar imagen'),
                                      ],
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
                                  onPressed: () {
                                    _toggleLike(post.id, data);
                                  },
                                  icon: Icon(
                                    _isLiked(data)
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _isLiked(data)
                                        ? Colors.red
                                        : Colors.grey[600],
                                  ),
                                ),
                                Text('${data['likesCount'] ?? 0}'),

                                const SizedBox(width: 16),

                                // Botón de ubicación
                                IconButton(
                                  onPressed: () => _showLocation(context, data),
                                  icon: Icon(
                                    Icons.location_on,
                                    color: Colors.blue[600],
                                  ),
                                ),

                                const SizedBox(width: 16),

                                // Botón de IA
                                IconButton(
                                  onPressed: () => _showAIAnalysis(
                                      context, data['imageUrl']),
                                  icon: Icon(
                                    Icons.psychology,
                                    color: Colors.purple[600],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Descripción
                          if (data['description'] != null &&
                              data['description'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                  12.0, 0, 12.0, 12.0),
                              child: Text(
                                _truncateText(
                                    data['description'].toString(), 200),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Botón flotante para cámara
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CameraScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }

  String _getInitial(User? user) {
    if (user?.displayName != null && user!.displayName!.isNotEmpty) {
      return user.displayName![0].toUpperCase();
    } else if (user?.email != null && user!.email!.isNotEmpty) {
      return user.email![0].toUpperCase();
    } else {
      return 'U';
    }
  }

  String _getFirstChar(dynamic userName) {
    if (userName == null) return 'U';
    String name = userName.toString();
    if (name.isEmpty) return 'U';
    return name[0].toUpperCase();
  }

  String _truncateText(String text, int maxLength) {
    if (text.isEmpty) return '';
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is String) {
        date = DateTime.parse(timestamp);
      } else {
        return 'Ahora';
      }

      final now = DateTime.now();
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
    } catch (e) {
      return 'Ahora';
    }
  }

  bool _isLiked(Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return false;

    final likes = data['likes'];
    if (likes == null) return false;

    final likesList = List<String>.from(likes);
    return likesList.contains(currentUserId);
  }

  void _toggleLike(String postId, Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final isLiked = _isLiked(data);

    if (isLiked) {
      postRef.update({
        'likes': FieldValue.arrayRemove([currentUserId]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      postRef.update({
        'likes': FieldValue.arrayUnion([currentUserId]),
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  void _showLocation(BuildContext context, Map<String, dynamic> data) {
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final hasLocation = data['hasLocation'] ?? false;

    print(
        'Debug - Latitude: $latitude, Longitude: $longitude, HasLocation: $hasLocation');

    if (!hasLocation ||
        latitude == null ||
        longitude == null ||
        (latitude is num &&
            latitude == 0.0 &&
            longitude is num &&
            longitude == 0.0)) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Ubicación no disponible'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_off,
                  color: Colors.grey,
                  size: 48,
                ),
                SizedBox(height: 16),
                Text(
                  'Esta foto no tiene información de ubicación.',
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
      return;
    }

    // Navegar a la pantalla de mapa
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
          userName: data['userName'] ?? 'Usuario',
          imageUrl: data['imageUrl'],
          description: data['description'],
        ),
      ),
    );
  }

  void _showAIAnalysis(BuildContext context, String? imageUrl) {
    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay imagen para analizar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AIAnalysisDialog(imageUrl: imageUrl);
      },
    );
  }
}

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
    return Scaffold(
      backgroundColor: Colors.white, // Fondo limpio estilo red social
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.add_box_outlined,
              color: Color(0xFF2E7D32), size: 28),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CameraScreen()),
          ),
        ),
        title: const Text(
          'AvesApp',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline,
                color: Color(0xFF2E7D32), size: 28),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('Error al cargar las publicaciones'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final post = snapshot.data!.docs[index];
              final data = post.data() as Map<String, dynamic>;
              return _buildPostItem(context, post.id, data);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera_outlined, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No hay publicaciones aún',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          Text('Sé el primero en compartir una foto de ave',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPostItem(
      BuildContext context, String postId, Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera: Usuario y tiempo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFE8F5E9),
                  radius: 18,
                  child: Text(
                    _getFirstChar(data['userName']),
                    style: const TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['userName'] ?? 'Usuario',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (data['timestamp'] != null)
                        Text(_formatTimestamp(data['timestamp']),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.more_vert, size: 20, color: Colors.grey),
              ],
            ),
          ),

          // 2. Imagen con Hero y Zoom (GestureDetector)
          GestureDetector(
            onDoubleTap: () =>
                _toggleLike(postId, data), // Like con doble toque
            onTap: () {
              // Navegar a vista de pantalla completa
              if (data['imageUrl'] != null) {
                _showFullScreenImage(context, data['imageUrl']);
              }
            },
            child: Hero(
              tag: data['imageUrl'] ?? postId,
              child: AspectRatio(
                aspectRatio: 1, // Cuadrada estilo Instagram
                child: Container(
                  width: double.infinity,
                  color: Colors.grey[100],
                  child: data['imageUrl'] != null
                      ? Image.network(
                          data['imageUrl'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildErrorImage(),
                        )
                      : _buildErrorImage(),
                ),
              ),
            ),
          ),

          // 3. Barra de acciones (Resaltada)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked(data) ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked(data) ? Colors.red : Colors.black87,
                    size: 28,
                  ),
                  onPressed: () => _toggleLike(postId, data),
                ),
                IconButton(
                  icon: const Icon(Icons.location_on_outlined,
                      color: Colors.blue, size: 28),
                  onPressed: () => _showLocation(context, data),
                ),
                const Spacer(),
                // Botón de IA Estilizado
                GestureDetector(
                  onTap: () => _showAIAnalysis(context, data['imageUrl']),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.psychology,
                        color: Color(0xFF2E7D32), size: 26),
                  ),
                ),
              ],
            ),
          ),

          // 4. Likes y Descripción
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['likesCount'] ?? 0} Me gusta',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 5),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                    children: [
                      TextSpan(
                        text: '${data['userName'] ?? 'Usuario'} ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: data['description'] ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
        ],
      ),
    );
  }

  Widget _buildErrorImage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 50, color: Colors.grey),
          Text('Imagen no disponible',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  // --- MÉTODOS DE APOYO (Lógica) ---

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
              backgroundColor: Colors.black,
              iconTheme: const IconThemeData(color: Colors.white)),
          body: Center(
            child: InteractiveViewer(
              // Permite hacer zoom
              child: Hero(
                tag: imageUrl,
                child: Image.network(imageUrl),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getFirstChar(dynamic userName) {
    if (userName == null) return 'U';
    String name = userName.toString();
    return name.isEmpty ? 'U' : name[0].toUpperCase();
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      DateTime date;
      if (timestamp is Timestamp)
        date = timestamp.toDate();
      else if (timestamp is String)
        date = DateTime.parse(timestamp);
      else
        return 'Ahora';

      final diff = DateTime.now().difference(date);
      if (diff.inDays > 0) return 'Hace ${diff.inDays}d';
      if (diff.inHours > 0) return 'Hace ${diff.inHours}h';
      if (diff.inMinutes > 0) return 'Hace ${diff.inMinutes}m';
      return 'Ahora';
    } catch (e) {
      return 'Ahora';
    }
  }

  bool _isLiked(Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null || data['likes'] == null) return false;
    return List<String>.from(data['likes']).contains(currentUserId);
  }

  void _toggleLike(String postId, Map<String, dynamic> data) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    final isLiked = _isLiked(data);

    postRef.update({
      'likes': isLiked
          ? FieldValue.arrayRemove([currentUserId])
          : FieldValue.arrayUnion([currentUserId]),
      'likesCount': FieldValue.increment(isLiked ? -1 : 1),
    });
  }

  void _showLocation(BuildContext context, Map<String, dynamic> data) {
    final lat = data['latitude'];
    final lng = data['longitude'];

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación no disponible')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
          userName: data['userName'] ?? 'Usuario',
          imageUrl: data['imageUrl'],
          description: data['description'],
        ),
      ),
    );
  }

  void _showAIAnalysis(BuildContext context, String? imageUrl) {
    if (imageUrl == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AIAnalysisDialog(imageUrl: imageUrl),
    );
  }
}

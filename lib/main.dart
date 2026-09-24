import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galería Multimedia',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Mi Galería'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // --- ESTADOS LÓGICOS DE LA APP ---
  List _mediaList = [];
  List _albums = [];

  // Listas en memoria para Favoritos y Papelera
  final List _favorites = [];
  final List _trash = [];

  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set _selectedMedia = {};

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchMedia();
  }

  Future _fetchMedia() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();

    if (ps.isAuth || ps.hasAccess) {
      // 1. Obtener todos los álbumes
      List albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );

      if (albums.isNotEmpty) {
        // 2. Extraer las fotos del primer álbum ("Recientes")
        List media = await albums[0].getAssetListPaged(
          page: 0,
          size: 100,
        );
        setState(() {
          _albums = albums;
          _mediaList = media;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() => _isLoading = false);
      PhotoManager.openSetting();
    }
  }

  // --- FUNCIONES LÓGICAS ---
  void _toggleSelection(AssetEntity entity) {
    setState(() {
      if (_selectedMedia.contains(entity)) {
        _selectedMedia.remove(entity);
        if (_selectedMedia.isEmpty) _isSelectionMode = false;
      } else {
        _selectedMedia.add(entity);
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedMedia.clear();
    });
  }

  void _moveToTrash(AssetEntity entity) {
    setState(() {
      _mediaList.remove(entity);
      _favorites.remove(entity);
      if (!_trash.contains(entity)) {
        _trash.add(entity);
      }
    });
  }

  void _deleteMultipleSelected() {
    setState(() {
      for (var entity in _selectedMedia) {
        _mediaList.remove(entity);
        _favorites.remove(entity);
        if (!_trash.contains(entity)) _trash.add(entity);
      }
      _clearSelection();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Archivos movidos a la papelera')),
    );
  }

  void _toggleFavorite(AssetEntity entity) {
    setState(() {
      if (_favorites.contains(entity)) {
        _favorites.remove(entity);
      } else {
        _favorites.add(entity);
      }
    });
  }

  // --- NAVEGACIÓN ENTRE APARTADOS ---
  Widget _buildBodyView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentIndex) {
      case 0: // Fotos principales
        return _buildMediaGrid(_mediaList);
      case 1: // Álbumes
        return _buildAlbumsList();
      case 2: // Favoritos
        return _favorites.isEmpty
            ? const Center(child: Text("No hay favoritos"))
            : _buildMediaGrid(_favorites);
      case 3: // Papelera
        return _trash.isEmpty
            ? const Center(child: Text("La papelera está vacía"))
            : _buildMediaGrid(_trash);
      default:
        return _buildMediaGrid(_mediaList);
    }
  }

  // Vista de Cuadrícula reutilizable
  Widget _buildMediaGrid(List listToDisplay) {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: listToDisplay.length,
      itemBuilder: (context, index) {
        final entity = listToDisplay[index];
        final isSelected = _selectedMedia.contains(entity);

        return GestureDetector(
          onLongPress: () {
            setState(() {
              _isSelectionMode = true;
              _selectedMedia.add(entity);
            });
          },
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(entity);
            } else {
              // Abrir el visor pasando la lista completa para el Slide
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MediaViewerPage(
                    mediaList: listToDisplay,
                    initialIndex: index,
                    isFavorite: (e) => _favorites.contains(e),
                    onToggleFavorite: _toggleFavorite,
                    onDelete: _moveToTrash,
                  ),
                ),
              );
            }
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              AssetEntityImage(
                entity,
                isOriginal: false,
                thumbnailSize: const ThumbnailSize.square(200),
                fit: BoxFit.cover,
              ),
              if (entity.type == AssetType.video)
                const Positioned(
                  bottom: 4,
                  right: 4,
                  child: Icon(Icons.play_circle_fill,
                      color: Colors.white, size: 24),
                ),
              if (_isFavorite(entity) &&
                  _currentIndex != 2) // Muestra un mini corazón
                const Positioned(
                  top: 4,
                  left: 4,
                  child: Icon(Icons.favorite, color: Colors.red, size: 16),
                ),
              if (_isSelectionMode)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white,
                  ),
                ),
              if (isSelected)
                Container(color: Colors.black.withValues(alpha: 0.4)),
            ],
          ),
        );
      },
    );
  }

  bool _isFavorite(AssetEntity e) => _favorites.contains(e);

  // Vista de Álbumes
  Widget _buildAlbumsList() {
    return ListView.builder(
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return ListTile(
          leading: const Icon(Icons.folder, size: 40, color: Colors.deepPurple),
          title: Text(album.name),
          subtitle: FutureBuilder(
            future: album.assetCountAsync,
            builder: (context, snapshot) {
              return Text('${snapshot.data ?? 0} elementos');
            },
          ),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Abriendo álbum: ${album.name}... (Implementar navegación interior)')),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: _isSelectionMode
            ? Text('${_selectedMedia.length} seleccionados')
            : Text(widget.title),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        actions: _isSelectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deleteMultipleSelected,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.camera_alt),
                  onPressed: () {},
                )
              ],
      ),
      body: _buildBodyView(), // Llama a nuestro gestor de vistas
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
            _clearSelection(); // Limpia selecciones si cambias de pestaña
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.photo), label: 'Fotos'),
          NavigationDestination(
              icon: Icon(Icons.photo_album), label: 'Álbumes'),
          NavigationDestination(icon: Icon(Icons.favorite), label: 'Favoritos'),
          NavigationDestination(icon: Icon(Icons.delete), label: 'Papelera'),
        ],
      ),
    );
  }
}

// --- PANTALLA VISOR DE MEDIOS (CON SWIPE Y ACCIONES) ---
class MediaViewerPage extends StatefulWidget {
  final List mediaList;
  final int initialIndex;

  // Callbacks para comunicar con la pantalla principal
  final Function(AssetEntity) onToggleFavorite;
  final Function(AssetEntity) onDelete;
  final bool Function(AssetEntity) isFavorite;

  const MediaViewerPage({
    super.key,
    required this.mediaList,
    required this.initialIndex,
    required this.onToggleFavorite,
    required this.onDelete,
    required this.isFavorite,
  });

  @override
  State createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future _editImage(AssetEntity entity) async {
    if (entity.type != AssetType.image) return;

    final file = await entity.file;
    if (file == null) return;

    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: file.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Editar Imagen',
            toolbarColor: Colors.deepPurple,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
        ],
      );

      if (croppedFile != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Imagen editada. Para guardar nativamente, requiere permisos de escritura backend.')),
        );
      }
    } catch (e) {
      debugPrint("Error al recortar la imagen: $e");
    }
  }

  void _handleDelete() {
    final entityToDelete = widget.mediaList[_currentIndex];
    widget.onDelete(entityToDelete);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Movido a la papelera')),
    );
    Navigator.pop(context); // Cierra el visor tras borrar
  }

  @override
  Widget build(BuildContext context) {
    final currentEntity = widget.mediaList[_currentIndex];
    final bool isFav = widget.isFavorite(currentEntity);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        title: Text(
            '\({_currentIndex + 1} /\){widget.mediaList.length}'), // Contador de fotos
        actions: [
          IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border),
            color: isFav ? Colors.red : Colors.white,
            onPressed: () {
              setState(() {
                widget.onToggleFavorite(currentEntity);
              });
            },
          ),
        ],
      ),
      // Uso de PageView para hacer el Slide Horizontal
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.mediaList.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index; // Actualiza el estado al deslizar
          });
        },
        itemBuilder: (context, index) {
          final entity = widget.mediaList[index];

          if (entity.type == AssetType.image) {
            return AssetEntityImage(
              entity,
              isOriginal: true,
              fit: BoxFit.contain,
            );
          } else {
            return const Center(
              child: Text(
                'El reproductor de video se \ninstanciaría aquí',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            );
          }
        },
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.black87,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.share, color: Colors.white),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'Para compartir, instala el paquete "share_plus" en pubspec.yaml')),
                );
              },
            ),
            if (currentEntity.type == AssetType.image)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () => _editImage(currentEntity),
              ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: _handleDelete,
            ),
          ],
        ),
      ),
    );
  }
}

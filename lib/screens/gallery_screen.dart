import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'dart:typed_data';
import 'dart:math';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _DateSection {
  final String label;
  final List<AssetEntity> assets;
  _DateSection(this.label, this.assets);
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<AssetEntity> _mediaList = [];
  bool _isLoading = true;
  List<_DateSection> _sections = [];

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    final permission = await PhotoManager.requestPermissionExtend();

    if (!permission.isAuth) {
      await PhotoManager.openSetting();
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );

    if (albums.isNotEmpty) {
      final recentAlbum = albums.first;
      final media = await recentAlbum.getAssetListPaged(page: 0, size: 100);

      setState(() {
        _mediaList = media;
        _isLoading = false;
        _sections = _buildSections(media);
      });
    }
  }

  List<_DateSection> _buildSections(List<AssetEntity> assets) {
    Map<String, List<AssetEntity>> sectionMap = {};
    List<String> order = [];

    for (final asset in assets) {
      final dt = asset.createDateTime;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final assetDay = DateTime(dt.year, dt.month, dt.day);

      String label;
      final difference = today.difference(assetDay).inDays;
      if (difference == 0) {
        label = "Today";
      } else if (difference == 1) {
        label = "1 day ago";
      } else {
        label = "$difference days ago";
      }

      if (!sectionMap.containsKey(label)) {
        sectionMap[label] = [];
        order.add(label);
      }
      sectionMap[label]!.add(asset);
    }

    return order.map((label) => _DateSection(label, sectionMap[label]!)).toList();
  }

  Future<Widget> _buildThumbnail(AssetEntity asset) async {
    final Uint8List? thumbData = await asset.thumbnailDataWithSize(const ThumbnailSize(200, 200));
    if (thumbData == null) return const SizedBox();
    return Image.memory(thumbData, fit: BoxFit.cover);
  }

  // Delete photo by index in section (recomputes sections after)
  Future<void> _deletePhoto(_DateSection section, int sectionIndex, int indexWithinSection) async {
    final entity = section.assets[indexWithinSection];
    final result = await PhotoManager.editor.deleteWithIds([entity.id]);
    if (result.isNotEmpty) {
      setState(() {
        _mediaList.remove(entity);
        _sections = _buildSections(_mediaList);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Gallery',
          style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 22
          ),
        ),
        centerTitle: true,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sections.isEmpty
              ? const Center(child: Text("No photos found"))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                  itemCount: _sections.length,
                  itemBuilder: (context, sectionIndex) {
                    final section = _sections[sectionIndex];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          child: Text(
                            section.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 4,
                              mainAxisSpacing: 4,
                            ),
                            itemCount: section.assets.length,
                            itemBuilder: (context, idx) {
                              return FutureBuilder<Widget>(
                                future: _buildThumbnail(section.assets[idx]),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
                                    return GestureDetector(
                                      onTap: () async {
                                        // Find global index for deletion
                                        final deleted = await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FullScreenPhotoScreen(
                                              mediaList: _mediaList,
                                              initialIndex: _mediaList.indexOf(section.assets[idx]),
                                              onDelete: (deleteIndex) async {
                                                // Find which section this index is in now
                                                final asset = _mediaList[deleteIndex];
                                                for (final sec in _sections) {
                                                  final localIdx = sec.assets.indexOf(asset);
                                                  if (localIdx != -1) {
                                                    await _deletePhoto(sec, _sections.indexOf(sec), localIdx);
                                                    break;
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                        );
                                        if (deleted == true) {
                                          _loadGallery();
                                        }
                                      },
                                      child: snapshot.data!,
                                    );
                                  } else {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    );
                  },
                ),
    );
  }
}

class FullScreenPhotoScreen extends StatefulWidget {
  final List<AssetEntity> mediaList;
  final int initialIndex;
  final Future<void> Function(int) onDelete;

  const FullScreenPhotoScreen({
    super.key,
    required this.mediaList,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<FullScreenPhotoScreen> createState() => _FullScreenPhotoScreenState();
}

class _FullScreenPhotoScreenState extends State<FullScreenPhotoScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<AssetEntity> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List<AssetEntity>.from(widget.mediaList); // Defensive copy
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  Future<void> _deleteCurrentPhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Photo"),
        content: const Text("Are you sure you want to delete this photo?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await widget.onDelete(_currentIndex);
      setState(() {
        _photos.removeAt(_currentIndex);
        if (_currentIndex >= _photos.length) {
          _currentIndex = max(0, _photos.length - 1);
        }
        _pageController = PageController(initialPage: _currentIndex);
      });
      if (_photos.isEmpty) {
        // ignore: use_build_context_synchronously
        Navigator.of(context).pop(true); // Tell parent to reload gallery
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_photos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Photo')),
        body: const Center(child: Text('No photos left')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo ${_currentIndex + 1} of ${_photos.length}'),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteCurrentPhoto,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _pageController,
        itemCount: _photos.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final asset = _photos[index];
          return FutureBuilder<Uint8List?>(
            future: asset.originBytes,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data != null) {
                return Center(
                  child: InteractiveViewer(
                    child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                  ),
                );
              } else if (snapshot.hasError) {
                return const Center(child: Text('Failed to load image', style: TextStyle(color: Colors.white)));
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            },
          );
        },
      ),
    );
  }
}
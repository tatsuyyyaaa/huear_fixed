// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts

class GalleryScreen extends StatefulWidget {
  final List<String> capturedImages;
  final Function(int) onImageDeleted;

  const GalleryScreen({
    super.key,
    required this.capturedImages,
    required this.onImageDeleted,
  });

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          'Gallery',
          style: GoogleFonts.inter( // Use GoogleFonts for a modern look
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 2, // Add a subtle shadow
      ),
      body: widget.capturedImages.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 80,
                    color: Colors.grey[300], // Lighter grey for empty state icon
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No photos yet",
                    style: GoogleFonts.inter(fontSize: 18, color: Colors.grey[600]), // Consistent font and color
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Capture some moments with HueAR!",
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8, // Increased spacing for better visual separation
                mainAxisSpacing: 8, // Increased spacing
              ),
              itemCount: widget.capturedImages.length,
              itemBuilder: (context, index) {
                final imagePath = widget.capturedImages[index];
                return GestureDetector(
                  onTap: () => _showFullScreen(context, index, imagePath),
                  child: Card( // Wrap image in a Card for elevation and rounded corners
                    elevation: 2, // Subtle shadow for each image card
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners for image cards
                    ),
                    clipBehavior: Clip.antiAlias, // Ensures image respects card's border radius
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover, // Cover to fill the grid tile
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey)), // Error placeholder
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _showFullScreen(BuildContext context, int index, String imagePath) async {
    // Pass the entire list of image paths and the initial index
    final bool? deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenPhotoScreen(
          imagePaths: widget.capturedImages,
          initialIndex: index,
          onDelete: (deleteIndex) {
            // This callback is triggered from FullScreenPhotoScreen
            // It modifies the original list via the parent's callback
            widget.onImageDeleted(deleteIndex);
            // No need for setState here, as the Navigator.pop will trigger rebuild
          },
        ),
      ),
    );

    // If an image was deleted and we returned to this screen, rebuild the grid.
    if (deleted == true) {
      setState(() {});
    }
  }
}

class FullScreenPhotoScreen extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final Function(int) onDelete; // Callback to notify parent of deletion

  const FullScreenPhotoScreen({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<FullScreenPhotoScreen> createState() => _FullScreenPhotoScreenState();
}

class _FullScreenPhotoScreenState extends State<FullScreenPhotoScreen> {
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

  Future<void> _deleteCurrentPhoto() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Delete Photo",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        content: Text(
          "Are you sure you want to delete this photo?",
          style: GoogleFonts.inter(color: Colors.grey[700]),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners for dialog
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton( // Use ElevatedButton for the destructive action
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent, // Red for delete action
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Call the onDelete callback to update the parent's list
      widget.onDelete(_currentIndex);

      // Handle navigation after deletion
      if (widget.imagePaths.isEmpty) { // If no images left after deletion
        Navigator.of(context).pop(true); // Pop back to gallery screen
      } else {
        // If there are still images, adjust current index and page controller
        if (_currentIndex >= widget.imagePaths.length) {
          // If the last image was deleted, go to the new last image
          _currentIndex = widget.imagePaths.length - 1;
        }
        // Jump to the new page. Using jumpToPage is immediate.
        // If you want animation, use animateToPage with a short duration.
        _pageController.jumpToPage(_currentIndex);
        setState(() {}); // Update the UI (e.g., title "X of Y")
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Photo ${_currentIndex + 1} of ${widget.imagePaths.length}',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: widget.imagePaths.isEmpty ? null : _deleteCurrentPhoto, // Disable if no photos
          ),
        ],
      ),
      backgroundColor: Colors.black, // Black background for full-screen photos
      body: widget.imagePaths.isEmpty
          ? Center(
              child: Text(
                "No photos to display",
                style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
              ),
            )
          : PageView.builder(
              controller: _pageController,
              itemCount: widget.imagePaths.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final imagePath = widget.imagePaths[index];
                return Center(
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain, // Ensures the entire image is visible, no cropping
                  ),
                );
              },
            ),
    );
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb.
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MyApp());
}

/// Basic app shell.
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expanded Video Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        textTheme: GoogleFonts.robotoMonoTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const VideoEditorExpandedPage(),
    );
  }
}

/// Represents an asset that can be dragged.
class DraggableAsset {
  final String assetType; // 'image', 'voice', 'music'
  final String
      display; // For images: URL, file path, or data URI; for voice/music: text or file path

  DraggableAsset({
    required this.assetType,
    required this.display,
  });
}

/// A timeline segment added to a track.
class TimelineSegment {
  final String assetType; // 'image', 'voice', 'music'
  final String display;
  double duration; // in seconds

  TimelineSegment({
    required this.assetType,
    required this.display,
    this.duration = 3.0,
  });
}

/// The expanded video editor page.
class VideoEditorExpandedPage extends StatefulWidget {
  const VideoEditorExpandedPage({Key? key}) : super(key: key);

  @override
  _VideoEditorExpandedPageState createState() =>
      _VideoEditorExpandedPageState();
}

class _VideoEditorExpandedPageState extends State<VideoEditorExpandedPage> {
  // ===================== ASSET LIBRARY =====================

  // Pre-generated images (as URLs).
  final List<String> generatedImageUrls = [
    "https://via.placeholder.com/200x356.png?text=Image+1",
    "https://via.placeholder.com/200x356.png?text=Image+2",
    "https://via.placeholder.com/200x356.png?text=Image+3",
  ];

  // Combined image assets list (generated + uploaded).
  final List<DraggableAsset> imageAssets = [];

  // Now we allow multiple voice and multiple music assets.
  final List<DraggableAsset> voiceAssets = [];
  final List<DraggableAsset> musicAssets = [];

  // Controller for voiceover input.
  final TextEditingController _voiceoverController = TextEditingController();

  // ===================== TIMELINE TRACKS =====================

  // All timeline tracks are horizontal.
  List<TimelineSegment> imageTrack = [];
  List<TimelineSegment> voiceTrack = [];
  List<TimelineSegment> musicTrack = [];

  // ===================== PLAYBACK & SYNC =====================

  double _playbackPosition = 0.0; // in seconds
  bool _isPlaying = false;
  Timer? _playbackTimer;

  // Audio player for music playback.
  late AudioPlayer _audioPlayer;
  // Flutter TTS for voiceover playback.
  late FlutterTts _flutterTts;

  // TTS settings.
  double _ttsRate = 0.5;
  double _ttsPitch = 1.0;
  double _ttsVolume = 1.0;

  // State variables to track the current active segment indices.
  int _currentVoiceSegmentIndex = -1;
  int _currentMusicSegmentIndex = -1;

  // ===================== RESIZABLE PANEL VARIABLES =====================
  // Fraction (0.0 to 1.0) for left panel width (initially 0.3).
  double _leftPanelWidthFraction = 0.3;
  // Fraction (0.0 to 1.0) for preview height within right panel (initially 0.4).
  double _previewHeightFraction = 0.4;

  @override
  void initState() {
    super.initState();
    // Initialize the asset library with generated images.
    for (var url in generatedImageUrls) {
      imageAssets.add(DraggableAsset(assetType: 'image', display: url));
    }
    _audioPlayer = AudioPlayer();
    _flutterTts = FlutterTts();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _voiceoverController.dispose();
    _audioPlayer.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // ===================== IMAGE UPLOAD =====================

  Future<void> _uploadImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb, // on web, we get file bytes; on mobile, use file path
      );
      if (result != null && result.files.isNotEmpty) {
        String imageDisplay;
        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          final base64Str = base64Encode(bytes!);
          imageDisplay = "data:image/png;base64,$base64Str";
        } else {
          imageDisplay = result.files.single.path!;
        }
        setState(() {
          imageAssets
              .add(DraggableAsset(assetType: 'image', display: imageDisplay));
        });
      }
    } catch (e) {
      debugPrint("Error uploading image: $e");
    }
  }

  // ===================== MUSIC UPLOAD =====================

  Future<void> _importMusicAsset() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: kIsWeb, // on web, we get file bytes; on mobile, use file path
      );
      if (result != null && result.files.isNotEmpty) {
        String musicDisplay;
        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          final base64Str = base64Encode(bytes!);
          // Note: Some players may not support data URIs for audio.
          musicDisplay = "data:audio/mp3;base64,$base64Str";
        } else {
          musicDisplay = result.files.single.path!;
        }
        setState(() {
          musicAssets
              .add(DraggableAsset(assetType: 'music', display: musicDisplay));
        });
      }
    } catch (e) {
      debugPrint("Error importing music: $e");
    }
  }

  // ===================== VOICEOVER (TTS) =====================

  Future<void> _addVoiceoverAsset() async {
    final text = _voiceoverController.text.trim();
    if (text.isNotEmpty) {
      // Preview the voiceover using TTS.
      await _flutterTts.setSpeechRate(_ttsRate);
      await _flutterTts.setPitch(_ttsPitch);
      await _flutterTts.setVolume(_ttsVolume);
      await _flutterTts.speak(text);
      setState(() {
        voiceAssets.add(DraggableAsset(assetType: 'voice', display: text));
      });
    }
  }

  // ===================== HELPER: CURRENT SEGMENT INDEX =====================

  /// Given a track (list of TimelineSegments), returns the index of the segment
  /// active at _playbackPosition, or null if none.
  int? _getCurrentSegmentIndex(List<TimelineSegment> track) {
    double cumulative = 0.0;
    for (int i = 0; i < track.length; i++) {
      cumulative += track[i].duration;
      if (_playbackPosition < cumulative) {
        return i;
      }
    }
    return null;
  }

  // ===================== PLAYBACK CONTROLS =====================

  /// Computes the total video duration as the maximum of the cumulative durations on the tracks.
  double _calculateTotalDuration() {
    double totalImages = imageTrack.fold(0, (prev, seg) => prev + seg.duration);
    double totalVoice = voiceTrack.fold(0, (prev, seg) => prev + seg.duration);
    double totalMusic = musicTrack.fold(0, (prev, seg) => prev + seg.duration);
    return [totalImages, totalVoice, totalMusic]
        .reduce((a, b) => a > b ? a : b);
  }

  /// Returns the current image to display in the preview screen based on _playbackPosition.
  String? _getCurrentImageForPreview() {
    double pos = _playbackPosition;
    for (var seg in imageTrack) {
      if (pos < seg.duration) return seg.display;
      pos -= seg.duration;
    }
    return imageTrack.isNotEmpty ? imageTrack.last.display : null;
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      // Pause playback.
      _playbackTimer?.cancel();
      _isPlaying = false;
      await _audioPlayer.pause();
      await _flutterTts.stop();
    } else {
      // If at end, reset.
      double total = _calculateTotalDuration();
      if (_playbackPosition >= total) {
        _playbackPosition = 0.0;
        _currentVoiceSegmentIndex = -1;
        _currentMusicSegmentIndex = -1;
      }
      _isPlaying = true;
      _playbackTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        setState(() {
          _playbackPosition += 0.1;
        });
        // Check voice track.
        if (voiceTrack.isNotEmpty) {
          int? activeVoiceIndex = _getCurrentSegmentIndex(voiceTrack);
          if (activeVoiceIndex != null &&
              activeVoiceIndex != _currentVoiceSegmentIndex) {
            _currentVoiceSegmentIndex = activeVoiceIndex;
            await _flutterTts.stop();
            await _flutterTts.setSpeechRate(_ttsRate);
            await _flutterTts.setPitch(_ttsPitch);
            await _flutterTts.setVolume(_ttsVolume);
            await _flutterTts.speak(voiceTrack[activeVoiceIndex].display);
          }
        }
        // Check music track.
        if (musicTrack.isNotEmpty) {
          int? activeMusicIndex = _getCurrentSegmentIndex(musicTrack);
          if (activeMusicIndex != null &&
              activeMusicIndex != _currentMusicSegmentIndex) {
            _currentMusicSegmentIndex = activeMusicIndex;
            await _audioPlayer.stop();
            if (kIsWeb) {
              await _audioPlayer
                  .play(UrlSource(musicTrack[activeMusicIndex].display));
            } else {
              await _audioPlayer
                  .play(DeviceFileSource(musicTrack[activeMusicIndex].display));
            }
          }
        }
        if (_playbackPosition >= _calculateTotalDuration()) {
          _togglePlayback();
        }
      });
    }
    setState(() {});
  }

  // ===================== RESIZABLE PANEL WIDGETS =====================

  /// Vertical draggable divider between left and right panels.
  Widget _buildVerticalDivider(double availableHeight) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: (details) {
        setState(() {
          double deltaFraction =
              details.delta.dx / MediaQuery.of(context).size.width;
          _leftPanelWidthFraction += deltaFraction;
          if (_leftPanelWidthFraction < 0.1) _leftPanelWidthFraction = 0.1;
          if (_leftPanelWidthFraction > 0.9) _leftPanelWidthFraction = 0.9;
        });
      },
      child: Container(
        width: 8,
        color: Colors.transparent,
        child: Center(
          child: const Icon(Icons.drag_indicator, size: 16),
        ),
      ),
    );
  }

  /// Horizontal draggable divider between preview and timeline in the right panel.
  Widget _buildHorizontalDivider(double availableWidth) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        setState(() {
          double totalHeight = MediaQuery.of(context).size.height;
          double deltaFraction = details.delta.dy / totalHeight;
          _previewHeightFraction += deltaFraction;
          if (_previewHeightFraction < 0.2) _previewHeightFraction = 0.2;
          if (_previewHeightFraction > 0.8) _previewHeightFraction = 0.8;
        });
      },
      child: Container(
        height: 8,
        color: Colors.transparent,
        child: Center(
          child: const Icon(Icons.drag_handle, size: 16),
        ),
      ),
    );
  }

  // ===================== ASSET LIBRARY WIDGETS =====================

  /// Helper widget to show an asset in the library with a delete button.
  Widget _buildAssetLibraryItem({
    required DraggableAsset asset,
    required VoidCallback onDelete,
  }) {
    return Stack(
      children: [
        Draggable<DraggableAsset>(
          data: asset,
          feedback: Opacity(
            opacity: 0.7,
            child: _buildAssetThumbnail(asset.display, asset.assetType),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildAssetThumbnail(asset.display, asset.assetType),
          ),
          child: _buildAssetThumbnail(asset.display, asset.assetType),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.red, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        )
      ],
    );
  }

  /// Build a widget to represent an asset thumbnail.
  Widget _buildAssetThumbnail(String display, String assetType) {
    if (assetType == 'image') {
      ImageProvider imageProvider;
      if (display.startsWith("http") || display.startsWith("data:")) {
        imageProvider = NetworkImage(display);
      } else {
        imageProvider = FileImage(File(display));
      }
      return Container(
        height: 120,
        width: 120,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
        ),
      );
    } else if (assetType == 'voice') {
      return Container(
        padding: const EdgeInsets.all(12),
        width: 120,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue),
          borderRadius: BorderRadius.circular(8),
          color: Colors.blue[50],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.record_voice_over, color: Colors.blue),
            const SizedBox(width: 8),
            Flexible(child: Text("Voiceover", style: GoogleFonts.robotoMono())),
          ],
        ),
      );
    } else if (assetType == 'music') {
      return Container(
        padding: const EdgeInsets.all(12),
        width: 120,
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green),
          borderRadius: BorderRadius.circular(8),
          color: Colors.green[50],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, color: Colors.green),
            const SizedBox(width: 8),
            Flexible(child: Text("Music", style: GoogleFonts.robotoMono())),
          ],
        ),
      );
    } else {
      return const SizedBox();
    }
  }

  // ===================== TIMELINE & PREVIEW WIDGETS =====================

  /// Build a horizontal timeline segment with a draggable handle on the right edge.
  Widget _buildHorizontalTimelineSegment(
    TimelineSegment segment,
    int index, {
    required VoidCallback onDelete,
    required ValueChanged<double> onDurationChanged,
  }) {
    double width = segment.duration * 50;
    Widget content;
    if (segment.assetType == 'image') {
      ImageProvider imageProvider;
      if (segment.display.startsWith("http") ||
          segment.display.startsWith("data:")) {
        imageProvider = NetworkImage(segment.display);
      } else {
        imageProvider = FileImage(File(segment.display));
      }
      content = Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
          borderRadius: BorderRadius.circular(8),
        ),
      );
    } else if (segment.assetType == 'voice') {
      content = Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.record_voice_over, size: 40, color: Colors.blue),
        ),
      );
    } else if (segment.assetType == 'music') {
      content = Container(
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(Icons.music_note, size: 40, color: Colors.green),
        ),
      );
    } else {
      content = const SizedBox();
    }
    return Container(
      width: width,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: content),
          // Delete button.
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 16),
              onPressed: onDelete,
            ),
          ),
          // Draggable handle for resizing.
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: 20,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: (details) {
                double deltaSeconds = details.delta.dx / 50;
                double newDuration = segment.duration + deltaSeconds;
                if (newDuration < 1.0) newDuration = 1.0;
                if (newDuration > 10.0) newDuration = 10.0;
                onDurationChanged(newDuration);
              },
              child: Container(
                alignment: Alignment.center,
                color: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.drag_handle,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build a horizontal timeline track for a given asset type.
  Widget _buildHorizontalTimelineTrack({
    required String trackLabel,
    required String assetType,
    required List<TimelineSegment> trackSegments,
    required Function(TimelineSegment) onDeleteSegment,
    required Function(int, double) onUpdateDuration,
  }) {
    return DragTarget<DraggableAsset>(
      onWillAccept: (data) => data?.assetType == assetType,
      onAccept: (data) {
        setState(() {
          trackSegments.add(TimelineSegment(
            assetType: data.assetType,
            display: data.display,
          ));
        });
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          height: 140,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: trackSegments.isEmpty
              ? Center(
                  child: Text("Drag $assetType asset(s) here",
                      style: GoogleFonts.robotoMono(color: Colors.black45)),
                )
              : ReorderableListView(
                  scrollDirection: Axis.horizontal,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex--;
                      final item = trackSegments.removeAt(oldIndex);
                      trackSegments.insert(newIndex, item);
                    });
                  },
                  children: [
                    for (int i = 0; i < trackSegments.length; i++)
                      _buildHorizontalTimelineSegment(
                        trackSegments[i],
                        i,
                        onDelete: () {
                          setState(() {
                            trackSegments.removeAt(i);
                          });
                        },
                        onDurationChanged: (newDuration) {
                          setState(() {
                            trackSegments[i].duration = newDuration;
                          });
                        },
                      ).withKey(ValueKey(trackSegments[i])),
                  ],
                ),
        );
      },
    );
  }

  /// Build the preview screen (top–right). The current image is chosen from the image track.
  Widget _buildPreviewScreen() {
    String? previewImage = _getCurrentImageForPreview();
    ImageProvider? imageProvider;
    if (previewImage != null) {
      if (previewImage.startsWith("http") || previewImage.startsWith("data:")) {
        imageProvider = NetworkImage(previewImage);
      } else {
        imageProvider = FileImage(File(previewImage));
      }
    }
    return Container(
      height: 300,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
        color: Colors.black12,
        image: imageProvider != null
            ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
            : null,
      ),
      child: Stack(
        children: [
          if (previewImage == null)
            Center(
              child: Text("Preview Screen",
                  style: GoogleFonts.robotoMono(
                      fontSize: 20, color: Colors.black54)),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: voiceTrack.isNotEmpty
                ? const Icon(Icons.record_voice_over,
                    size: 40, color: Colors.blue)
                : const SizedBox(),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: musicTrack.isNotEmpty
                ? const Icon(Icons.music_note, size: 40, color: Colors.green)
                : const SizedBox(),
          ),
          Positioned(
            left: 8,
            top: 8,
            child: Text(
              "Time: ${_playbackPosition.toStringAsFixed(1)} sec",
              style: GoogleFonts.robotoMono(
                  fontSize: 14,
                  color: Colors.white,
                  backgroundColor: Colors.black45),
            ),
          ),
        ],
      ),
    );
  }

  // ===================== MAIN BUILD =====================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      double availableWidth = constraints.maxWidth;
      double leftPanelWidth = availableWidth * _leftPanelWidthFraction;
      double rightPanelWidth =
          availableWidth - leftPanelWidth - 8; // 8 for divider
      return Scaffold(
        appBar: AppBar(
          title: Text("Expanded Video Editor",
              style: GoogleFonts.robotoMono(color: Colors.black)),
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.black),
        ),
        body: Row(
          children: [
            // Left Panel: Asset Library.
            Container(
              width: leftPanelWidth,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Asset Library",
                        style: GoogleFonts.robotoMono(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    // Images.
                    Text("Images", style: GoogleFonts.robotoMono(fontSize: 16)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _uploadImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text("Upload Image"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: imageAssets.map((asset) {
                        return _buildAssetLibraryItem(
                          asset: asset,
                          onDelete: () {
                            setState(() {
                              imageAssets.remove(asset);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(),
                    // Voiceover.
                    Text("Voiceover",
                        style: GoogleFonts.robotoMono(fontSize: 16)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _voiceoverController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Enter voiceover text...",
                      ),
                      style: GoogleFonts.robotoMono(),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _addVoiceoverAsset,
                      child: const Text("Preview & Add Voiceover"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: voiceAssets.map((asset) {
                        return _buildAssetLibraryItem(
                          asset: asset,
                          onDelete: () {
                            setState(() {
                              voiceAssets.remove(asset);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(),
                    // Music.
                    Text("Music", style: GoogleFonts.robotoMono(fontSize: 16)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _importMusicAsset,
                      child: const Text("Import Music"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: musicAssets.map((asset) {
                        return _buildAssetLibraryItem(
                          asset: asset,
                          onDelete: () {
                            setState(() {
                              musicAssets.remove(asset);
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Vertical Divider.
            _buildVerticalDivider(constraints.maxHeight),
            // Right Panel: Preview, Playback Controls, and Timeline.
            Container(
              width: rightPanelWidth,
              padding: const EdgeInsets.only(left: 10),
              child: LayoutBuilder(builder: (context, rightConstraints) {
                double availableRightHeight = rightConstraints.maxHeight;
                // Reserve fixed height for playback controls.
                double playbackControlsHeight = 60;
                // The remaining height is divided between preview and timeline.
                double remainingHeight = availableRightHeight -
                    playbackControlsHeight -
                    8; // 8 for horizontal divider
                double previewHeight = remainingHeight * _previewHeightFraction;
                double timelineHeight = remainingHeight - previewHeight;
                return Column(
                  children: [
                    // Preview Screen.
                    Container(
                      height: previewHeight,
                      child: _buildPreviewScreen(),
                    ),
                    // Playback Controls.
                    Container(
                      height: playbackControlsHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              _isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_fill,
                              size: 40,
                              color: Colors.black,
                            ),
                            onPressed: _togglePlayback,
                          ),
                          Expanded(
                            child: Slider(
                              min: 0,
                              max: _calculateTotalDuration() > 0
                                  ? _calculateTotalDuration()
                                  : 1,
                              value: _playbackPosition.clamp(
                                  0, _calculateTotalDuration()),
                              onChanged: (value) {
                                setState(() {
                                  _playbackPosition = value;
                                });
                              },
                            ),
                          ),
                          Text(
                            "${_playbackPosition.toStringAsFixed(1)} / ${_calculateTotalDuration().toStringAsFixed(1)} sec",
                            style: GoogleFonts.robotoMono(),
                          ),
                        ],
                      ),
                    ),
                    // Horizontal divider for resizing preview vs timeline.
                    _buildHorizontalDivider(availableRightHeight),
                    // Timeline Editor.
                    Container(
                      height: timelineHeight,
                      padding: const EdgeInsets.only(top: 10),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildHorizontalTimelineTrack(
                              trackLabel: "Image Track",
                              assetType: "image",
                              trackSegments: imageTrack,
                              onDeleteSegment: (seg) {
                                setState(() {
                                  imageTrack.remove(seg);
                                });
                              },
                              onUpdateDuration: (index, newDuration) {
                                setState(() {
                                  imageTrack[index].duration = newDuration;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildHorizontalTimelineTrack(
                              trackLabel: "Voice Track",
                              assetType: "voice",
                              trackSegments: voiceTrack,
                              onDeleteSegment: (seg) {
                                setState(() {
                                  voiceTrack.remove(seg);
                                });
                              },
                              onUpdateDuration: (index, newDuration) {
                                setState(() {
                                  voiceTrack[index].duration = newDuration;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildHorizontalTimelineTrack(
                              trackLabel: "Music Track",
                              assetType: "music",
                              trackSegments: musicTrack,
                              onDeleteSegment: (seg) {
                                setState(() {
                                  musicTrack.remove(seg);
                                });
                              },
                              onUpdateDuration: (index, newDuration) {
                                setState(() {
                                  musicTrack[index].duration = newDuration;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ],
        ),
      );
    });
  }
}

/// Extension to attach a key to a widget (useful for ReorderableListView).
extension WithKey on Widget {
  Widget withKey(Key key) {
    return KeyedSubtree(key: key, child: this);
  }
}

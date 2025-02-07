import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb.
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p; // Import the path package.
import 'package:path_provider/path_provider.dart';

Future<void> main() async {
  // Ensure plugin services are initialized before any use.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

/// A simple Project class that holds the timeline tracks.
class Project {
  final String name;
  final List<TimelineSegment> imageTrack;
  final List<TimelineSegment> voiceTrack;
  final List<TimelineSegment> musicTrack;
  final DateTime createdAt;

  Project({
    required this.name,
    required this.imageTrack,
    required this.voiceTrack,
    required this.musicTrack,
    required this.createdAt,
  });
}

/// A global list that holds saved projects.
List<Project> savedProjects = [];

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
      // Register a route for the workspace page.
      routes: {
        '/workspace': (context) => const WorkspacePage(),
      },
      home: const VideoEditorExpandedPage(),
    );
  }
}

/// Represents an asset that can be dragged.
class DraggableAsset {
  final String assetType; // 'image', 'voice', 'music'
  final String
      display; // For images: URL, file path, or data URI; for voice/music: text or file path
  final String? fileName; // Optional fileName

  DraggableAsset({
    required this.assetType,
    required this.display,
    this.fileName,
  });
}

/// A timeline segment added to a track.
class TimelineSegment {
  final String assetType; // 'image', 'voice', 'music'
  final String display;
  double duration; // in seconds
  final String? fileName; // for music file name

  TimelineSegment({
    required this.assetType,
    required this.display,
    this.duration = 3.0,
    this.fileName,
  });
}

/// The expanded video editor page.
/// (Now it can optionally load a previously saved project.)
class VideoEditorExpandedPage extends StatefulWidget {
  final Project? project;
  const VideoEditorExpandedPage({Key? key, this.project}) : super(key: key);

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

    // If a project was passed from the workspace, load its tracks.
    if (widget.project != null) {
      imageTrack = List.from(widget.project!.imageTrack);
      voiceTrack = List.from(widget.project!.voiceTrack);
      musicTrack = List.from(widget.project!.musicTrack);
    }
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
        String? fileName; // Store the file name

        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          final base64Str = base64Encode(bytes!);
          // Note: Some players may not support data URIs for audio.
          musicDisplay = "data:audio/mp3;base64,$base64Str";
          fileName = result.files.single.name; // Get filename directly
        } else {
          musicDisplay = result.files.single.path!;
          fileName = p.basename(musicDisplay); // Extract filename from path
        }
        setState(() {
          musicAssets.add(DraggableAsset(
            assetType: 'music',
            display: musicDisplay,
            fileName: fileName, // Pass the fileName to the DraggableAsset
          ));
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

  /// Show a dialog to let the user update TTS settings.
  void _showVoiceoverSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        // Use StatefulBuilder to update dialog state.
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Voiceover Settings"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pitch slider.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Pitch"),
                      Text(_ttsPitch.toStringAsFixed(2)),
                    ],
                  ),
                  Slider(
                    value: _ttsPitch,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    onChanged: (value) {
                      setStateDialog(() {
                        _ttsPitch = value;
                      });
                      setState(() {});
                    },
                  ),
                  // Speech Rate slider.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Rate"),
                      Text(_ttsRate.toStringAsFixed(2)),
                    ],
                  ),
                  Slider(
                    value: _ttsRate,
                    min: 0.1,
                    max: 1.0,
                    divisions: 9,
                    onChanged: (value) {
                      setStateDialog(() {
                        _ttsRate = value;
                      });
                      setState(() {});
                    },
                  ),
                  // Volume slider.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Volume"),
                      Text(_ttsVolume.toStringAsFixed(2)),
                    ],
                  ),
                  Slider(
                    value: _ttsVolume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    onChanged: (value) {
                      setStateDialog(() {
                        _ttsVolume = value;
                      });
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Done"),
                )
              ],
            );
          },
        );
      },
    );
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
        child: Center(child: const Icon(Icons.drag_indicator, size: 16)),
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
        child: Center(child: const Icon(Icons.drag_handle, size: 16)),
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
            child: _buildAssetThumbnail(
                asset.display, asset.assetType, asset.fileName),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _buildAssetThumbnail(
                asset.display, asset.assetType, asset.fileName),
          ),
          child: _buildAssetThumbnail(
              asset.display, asset.assetType, asset.fileName),
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
  Widget _buildAssetThumbnail(
      String display, String assetType, String? fileName) {
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
            Flexible(
                child: Text(display,
                    style: GoogleFonts.robotoMono(),
                    overflow: TextOverflow.ellipsis)),
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
            Flexible(
              child: Text(
                fileName ?? "Music",
                style: GoogleFonts.robotoMono(),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
          // Add fileName to the TimelineSegment as well.
          trackSegments.add(TimelineSegment(
            assetType: data.assetType,
            display: data.display,
            fileName: data.fileName,
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

  /// Build the preview screen (top–right) using a 9:16 AspectRatio.
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
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
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
      ),
    );
  }

  // ===================== TOOLBOX (Floating Action Button) =====================

  /// Opens a toolbox with options such as Save, Download Video, and Workspace.
  void _showToolbox() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.save),
                title: const Text('Save Project'),
                onTap: () {
                  Navigator.of(context).pop();
                  _saveProject();
                },
              ),
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Download Video'),
                onTap: () {
                  Navigator.of(context).pop();
                  _downloadVideo();
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Workspace'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const WorkspacePage(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Prompts the user for a project name and saves the current timeline as a new project.
  void _saveProject() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController = TextEditingController();
        return AlertDialog(
          title: const Text("Save Project"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: "Enter project name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                String projectName = nameController.text.trim();
                if (projectName.isNotEmpty) {
                  savedProjects.add(Project(
                    name: projectName,
                    imageTrack: List.from(imageTrack),
                    voiceTrack: List.from(voiceTrack),
                    musicTrack: List.from(musicTrack),
                    createdAt: DateTime.now(),
                  ));
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Project '$projectName' saved!")),
                  );
                }
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ===================== VIDEO DOWNLOAD IMPLEMENTATION =====================

  /// Downloads the video by first generating an ffconcat file for images,
  /// then (optionally) generating a voice audio file by “synthesizing” each voice segment,
  /// concatenating them, and finally combining with a music track (if available).
  ///
  /// In a real application you would need to implement real TTS-to-file synthesis.
  Future<void> _downloadVideo() async {
    if (imageTrack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No images to create video")));
      return;
    }
    try {
      // Get temporary directory.
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String concatFilePath = p.join(tempPath, "images.txt");

      // Build ffconcat file content for images.
      StringBuffer concatContent = StringBuffer();
      for (var segment in imageTrack) {
        // Assumes segment.display is a local file path or URL.
        concatContent.writeln("file '${segment.display}'");
        concatContent.writeln("duration ${segment.duration}");
      }
      // Per ffconcat format, the last file is repeated without duration.
      if (imageTrack.isNotEmpty) {
        concatContent.writeln("file '${imageTrack.last.display}'");
      }

      // Write the concat file.
      File concatFile = File(concatFilePath);
      await concatFile.writeAsString(concatContent.toString());

      // --- Audio preparation ---
      // We will try to create a voice audio file if voice segments exist.
      String? voiceAudioPath;
      if (voiceTrack.isNotEmpty) {
        List<String> voiceSegmentFiles = [];
        for (int i = 0; i < voiceTrack.length; i++) {
          String synthesizedPath =
              await _synthesizeVoiceToFile(voiceTrack[i].display, i);
          voiceSegmentFiles.add(synthesizedPath);
        }
        // Concatenate the synthesized voice segments into one file.
        voiceAudioPath = p.join(tempPath, "voice_output.mp3");
        await _concatenateAudioFiles(voiceSegmentFiles, voiceAudioPath);
      }

      // Use the first music asset if available.
      String? musicAudioPath;
      if (musicTrack.isNotEmpty) {
        musicAudioPath = musicTrack.first.display;
      }

      // --- Build the FFmpeg command ---
      String outputPath = p.join(tempPath, "output.mp4");
      String ffmpegCmd;
      if (voiceAudioPath != null && musicAudioPath != null) {
        // Mix voice and music together using amix.
        ffmpegCmd =
            "-f concat -safe 0 -i '$concatFilePath' -i '$voiceAudioPath' -i '$musicAudioPath' "
            "-filter_complex \"[1:a][2:a]amix=inputs=2:duration=shortest[a]\" "
            "-map 0:v -map \"[a]\" -c:v libx264 -c:a aac -shortest -pix_fmt yuv420p '$outputPath'";
      } else if (voiceAudioPath != null) {
        // Only voice audio is available.
        ffmpegCmd =
            "-f concat -safe 0 -i '$concatFilePath' -i '$voiceAudioPath' "
            "-c:v libx264 -c:a aac -shortest -pix_fmt yuv420p '$outputPath'";
      } else if (musicAudioPath != null) {
        // Only music audio is available.
        ffmpegCmd =
            "-f concat -safe 0 -i '$concatFilePath' -i '$musicAudioPath' "
            "-c:v libx264 -c:a aac -shortest -pix_fmt yuv420p '$outputPath'";
      } else {
        // No audio – create video from images only.
        ffmpegCmd =
            "-f concat -safe 0 -i '$concatFilePath' -vsync vfr -pix_fmt yuv420p '$outputPath'";
      }

      // Execute FFmpeg command.
      final session = await FFmpegKit.execute(ffmpegCmd);
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Video downloaded successfully at: $outputPath")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to generate video")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  /// Simulates synthesizing voice (TTS) to a file.
  /// In a real implementation you would call an API or use a TTS engine that supports file output.
  Future<String> _synthesizeVoiceToFile(String text, int index) async {
    Directory tempDir = await getTemporaryDirectory();
    String filePath = p.join(tempDir.path, "voice_segment_$index.mp3");
    // For simulation, we simply write an empty file.
    // Replace this with your TTS-to-file implementation.
    File file = File(filePath);
    await file.writeAsBytes(utf8.encode(""));
    return filePath;
  }

  /// Concatenates multiple audio files into one using FFmpeg.
  Future<void> _concatenateAudioFiles(
      List<String> audioFiles, String outputPath) async {
    Directory tempDir = await getTemporaryDirectory();
    String concatFilePath = p.join(tempDir.path, "audio_concat.txt");
    StringBuffer concatContent = StringBuffer();
    for (var path in audioFiles) {
      concatContent.writeln("file '$path'");
    }
    File concatFile = File(concatFilePath);
    await concatFile.writeAsString(concatContent.toString());
    String ffmpegCmd =
        "-f concat -safe 0 -i '$concatFilePath' -c copy '$outputPath'";
    final session = await FFmpegKit.execute(ffmpegCmd);
    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      throw Exception("Failed to concatenate audio files");
    }
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
        floatingActionButton: FloatingActionButton(
          tooltip: "Toolbox",
          onPressed: _showToolbox,
          child: const Icon(Icons.build),
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
                    // Row with Generate Voiceover button and settings icon.
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _addVoiceoverAsset,
                          child: const Text("Generate Voiceover"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: _showVoiceoverSettingsDialog,
                        ),
                      ],
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
                double remainingHeight =
                    availableRightHeight - playbackControlsHeight - 8;
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

/// The Workspace page that shows a list of saved projects.
/// Tapping a project lets the user choose to load it.
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({Key? key}) : super(key: key);

  void _loadProject(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Load Project '${project.name}'?"),
          content: const Text(
              "This will replace the current session with the saved project."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // Replace current editor session with the loaded project.
                Navigator.pop(context); // Close dialog.
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        VideoEditorExpandedPage(project: project),
                  ),
                );
              },
              child: const Text("Load"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Workspace",
            style: GoogleFonts.robotoMono(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: ListView.builder(
        itemCount: savedProjects.length,
        itemBuilder: (context, index) {
          final project = savedProjects[index];
          return ListTile(
            title: Text(project.name, style: GoogleFonts.robotoMono()),
            subtitle: Text("Created: ${project.createdAt.toLocal()}"),
            onTap: () => _loadProject(context, project),
          );
        },
      ),
    );
  }
}

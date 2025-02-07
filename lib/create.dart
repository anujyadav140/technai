import 'dart:typed_data';
import 'dart:io' show File;
import 'package:audioplayers/audioplayers.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class CreateATemplate extends StatefulWidget {
  const CreateATemplate({Key? key}) : super(key: key);

  @override
  State<CreateATemplate> createState() => _CreateATemplateState();
}

class _CreateATemplateState extends State<CreateATemplate> {
  String artPrompt = "";
  double fontSize = 32.0;
  String selectedFont = "RobotoMono";
  Color selectedColor = Colors.black;

  File? musicFile;
  Uint8List? musicBytes;
  String? musicFileName;

  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  late FlutterTts _flutterTts;
  List<Map<String, String>>? _voices;
  Map<String, String>? _selectedVoice;
  double _rate = 0.5;
  double _pitch = 1.0;
  double _volume = 1.0;

  final List<String> artPromptSuggestions = [
    "Cyberpunk",
    "Surrealism",
    "Impressionism",
    "Abstract",
    "Realism",
    "Futuristic",
    "Minimalist",
    "Baroque",
    "Gothic",
  ];

  String? aiImageUrl;
  bool _isLoading = false;
  bool _imageGenerated =
      false; // Flag to indicate if the image has been "generated".

  final List<String> _googleFontsList = [
    'Bangers', // Comic book style
    'Fredericka the Great', // Hand-drawn, whimsical
    'Monoton', // Retro, 80s vibe
    'Press Start 2P', // Pixelated, video game style
    'Shrikhand', // Bold, impactful, Gujarati-inspired
    'Titan One', // Thick, rounded, playful
    'UnifrakturMaguntia', // Blackletter, gothic
    'Zilla Slab Highlight', // Bold slab with an inline highlight
    'Ewert', // Woodblock print style
    'Slackey', // Cartoonish with a slight 3D effect
    'Rampart One', // Chunky, blocky, almost Lego-like
    'Rubik Beastly', // Unique font
    'Black Ops One', // Military stencil
    'Knewave', // Graffiti

    // Script & Handwritten (Good for a personal touch)
    'Kalam', // Handwritten, informal
    'Dancing Script', // Lively, flowing script
    'Pacifico', // Retro, connected script
    'Shadows Into Light', // Neat handwriting
    'Indie Flower', // Bubbly handwriting
    'Permanent Marker', // Sharpie-like
    'Rock Salt', // Rough, textured handwriting
    'Gochi Hand', // Childlike handwriting
    'Reenie Beanie', //Thin handwriting
    'Sue Ellen Francisco', // More natural, flowing handwriting

    'Fascinate Inline', // Art Deco with inline details
    'Stalinist One', // Bold, constructivist style
    'Faster One', // Speed-inspired, slanted
    'Diplomata SC', // Ornate, almost calligraphic display
    'Henny Penny', // Cartoonish, bouncy
    'Butcherman', // Horror/dripping style
    'Creepster', // Another horror-themed font
    'Nosifer', // Dripping, horror
    'Shojumaru', // Brush-like, energetic
    'Big Shoulders Stencil Display', // Bold stencil with a unique cut
    'Wallpoet', // Graffiti-inspired stencil
    'Flavors', // Quirky, almost psychedelic
    'Geostar', // Geometric, angular, almost crystalline
    'Geostar Fill', // Filled version of Geostar
    'Michroma', // Squarish, sci-fi
    'Orbitron', // Geometric, futuristic, rounded
    'Ruslan Display', // Cyrillic-inspired, decorative
    'Vast Shadow', // Victorian with a strong drop shadow
    'Viaoda Libre', //Bold and free-spirited.
    'Yatra One', // Devanagari-inspired display
    'Eater', //Caps Only font
    'Fruktur', //Blackletter-inspired, but more angular
    'Griffy', //Heavy and "dripping"
    'Jacques Francois Shadow', //Clean sans-serif, but with a strong shadow
    'Metal Mania', //Heavy metal style
    'New Rocker', //Tattoo/rock style
    'Nothing You Could Do', //Handwritten, but very stylized
    'Pirata One', //Pirate-themed
    'Rye', //Western style
    'Snowburst One', //"Icy" looking

    // Unique Scripts
    'Birthstone Bounce', // Bouncy, connected script
    'Meie Script', // Casual, brush-like script
    'Redressed', //Elegant but unconventional script
    'Sedgwick Ave Display', //Handwritten, street-art inspired

    // Unusual Sans-Serifs
    'Electrolize', // Geometric with a techy feel
    'Lacquer', // Dripping Paint style
    'Oi', // Very bold, rounded, almost blob-like
    'Rowdies', // Bold, geometric, with three distinct weights
    'Share Tech Mono', // Monospace with a technical look
    'Sonsie One', // Bold and rounded sans-serif.
    'Telex', // Clean but slightly unusual proportions

    // Unusual Serifs
    'Big Shoulders Display', // Related to the stencil version, but solid
    'Big Shoulders Text', // A more readable (but still unique) text version
    'Chonburi', // Thai-inspired, with looped terminals
    'Content', // Rounded serif, almost cartoonish
    'Macondo', // Decorative with swirly details.
    'Macondo Swash Caps', // Even *more* swirly version of Macondo (caps only).
    'Meddon', //Handwritten-style serif
    'Uncial Antiqua', // Calligraphic, historical feel

    // Unique Sans-Serif (Modern, clean, but with personality)
    'Jost*', // Geometric, versatile (note the *)
    'Raleway', // Elegant, versatile
    'Rubik', // Rounded, friendly
    'Work Sans', // Clean, optimized for UI
    'Fira Sans', // Designed for legibility
    'Barlow', // Grotesque, slightly rounded
    'Chivo', // Grotesque with a strong presence
    'Manrope', // Modern, geometric
    'Poppins', // Geometric, clean, very popular
    'Inter', // Highly legible, optimized for screens

    // Unique Serif (Classic with a twist)
    'Playfair Display', // High contrast, elegant
    'Lora', // Well-balanced, contemporary
    'Cormorant Garamond', // Elegant, classic
    'Source Serif 4', // Versatile, readable
    'Libre Baskerville', // Classic, optimized for body text
    'PT Serif', // Versatile, with a matching sans-serif
    'EB Garamond', //Classic, elegant

    // Fun & Quirky
    'Bungee', // Vertically stacked
    'Bungee Shade', // Bungee with a drop shadow
    'Chewy', //Rounded and playful
    'Lobster', // Bold, retro script
    'Lobster Two', // A more subtle, less connected version of Lobster
    'Luckiest Guy', // Bold, comic-book style
    'Passion One', // Bold and condensed
    'Patua One', // Slab serif with a unique style
    'Righteous', // Art Deco inspired
    'Sigmar One', // Bold and impactful
    'Saira Stencil One',
    'Special Elite', //Typewriter-style font

    // Monospace
    'Azeret Mono',
    'Courier Prime', // Classic typewriter
    'Fira Code', // Programming font with ligatures
    'JetBrains Mono', // Another great programming font
    'Roboto Mono', // Monospace version of Roboto
    'Source Code Pro', // Designed for coding
    'Space Mono', // Retro-futuristic monospace

    //Rounded
    'Baloo 2',
    'Comic Neue',
    'Fredoka One',
    'Lexend', // Designed for readability (various weights)
    'Nunito', // Well-balanced, rounded
    'Quicksand', // Geometric, rounded
    'Varela Round', // Simple and round

    // Handwriting
    'Caveat',
    'Covered By Your Grace',
    'Homemade Apple',

    //Sans-Serif
    'Exo 2', // Geometric, futuristic
    'Oswald', // Reworked classic, condensed
    'Rajdhani', // Display font, techy feel
    'Urbanist', // geometric sans-serif font

    //Remaining fonts
    'Yanone Kaffeesatz',
    'Yatra One',
    'Yellowtail',
    'Yrsa',
    'Yusei Magic',
    'Redacted Script',
    'Zen Antique',
    'Zen Antique Soft',
    'Zen Dots',
    'Zen Kaku Gothic Antique',
    'Zen Kaku Gothic New',
    'Zen Kurenaido',
    'Zen Loop',
    'Zen Maru Gothic',
    'Zen Old Mincho',
    'Zeyada',
  ];

  String? _searchFontQuery;
  TextEditingController _fontSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onDurationChanged.listen((Duration d) {
      setState(() {
        _duration = d;
      });
    });
    _audioPlayer.onPositionChanged.listen((Duration p) {
      setState(() {
        _position = p;
      });
    });
    _audioPlayer.onPlayerComplete.listen((event) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });

    _flutterTts = FlutterTts();
    _flutterTts.setStartHandler(() {
      debugPrint("TTS started");
    });
    _flutterTts.setCompletionHandler(() {
      debugPrint("TTS complete");
    });
    _flutterTts.setErrorHandler((msg) {
      debugPrint("TTS error: $msg");
    });
    _loadVoices();

    OpenAI.apiKey =
        "";
  }

  Future<void> _loadVoices() async {
    var voices = await _flutterTts.getVoices;
    debugPrint(voices.toString());
    if (voices is List) {
      setState(() {
        _voices = voices.map<Map<String, String>>((voice) {
          return Map<String, String>.from(voice);
        }).toList();
        if (_voices!.isNotEmpty) {
          _selectedVoice = _voices!.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _flutterTts.stop();
    _fontSearchController.dispose();
    super.dispose();
  }

  TextStyle getPreviewTextStyle() {
    try {
      return GoogleFonts.getFont(selectedFont,
          fontSize: fontSize, color: selectedColor);
    } catch (e) {
      debugPrint("Error applying font: $e, using Roboto");
      return GoogleFonts.roboto(
          fontSize: fontSize, color: selectedColor); // Fallback font
    }
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick a color!'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (Color color) {
                setState(() => selectedColor = color);
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Got it'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickMusicFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        if (kIsWeb) {
          final fileBytes = result.files.single.bytes;
          final fileName = result.files.single.name;
          if (fileBytes != null) {
            setState(() {
              musicBytes = fileBytes;
              musicFileName = fileName;
            });
            await _audioPlayer.setSource(BytesSource(fileBytes));
          }
        } else {
          if (result.files.single.path != null) {
            File file = File(result.files.single.path!);
            setState(() {
              musicFile = file;
            });
            await _audioPlayer.setSource(DeviceFileSource(file.path));
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Widget _buildMusicPlayer() {
    final String nowPlaying = kIsWeb
        ? (musicFileName ?? "Unknown")
        : (musicFile != null ? musicFile!.path.split('/').last : "Unknown");

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Now Playing: $nowPlaying",
            style: GoogleFonts.robotoMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  color: Colors.black,
                  size: 40,
                ),
                onPressed: () async {
                  if (_isPlaying) {
                    await _audioPlayer.pause();
                    await _flutterTts.stop();
                    setState(() {
                      _isPlaying = false;
                    });
                  } else {
                    final String textToSpeak = artPrompt.isEmpty
                        ? "Your art prompt preview will appear here."
                        : artPrompt;

                    await _flutterTts.setSpeechRate(_rate);
                    await _flutterTts.setPitch(_pitch);
                    await _flutterTts.setVolume(_volume);
                    if (_selectedVoice != null) {
                      await _flutterTts.setVoice(_selectedVoice!);
                    }

                    _flutterTts.speak(textToSpeak);

                    if (kIsWeb) {
                      if (musicBytes != null) {
                        await _audioPlayer.play(BytesSource(musicBytes!));
                      }
                    } else {
                      if (musicFile != null) {
                        await _audioPlayer
                            .play(DeviceFileSource(musicFile!.path));
                      }
                    }
                    setState(() {
                      _isPlaying = true;
                    });
                  }
                },
              ),
              Expanded(
                child: Slider(
                  activeColor: Colors.black,
                  inactiveColor: Colors.black26,
                  min: 0,
                  max: _duration.inSeconds.toDouble() > 0
                      ? _duration.inSeconds.toDouble()
                      : 1.0,
                  value: _position.inSeconds
                      .toDouble()
                      .clamp(0, _duration.inSeconds.toDouble()),
                  onChanged: (value) async {
                    final position = Duration(seconds: value.toInt());
                    await _audioPlayer.seek(position);
                  },
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position),
                  style: GoogleFonts.robotoMono(
                      fontSize: 12, color: Colors.black)),
              Text(_formatDuration(_duration),
                  style: GoogleFonts.robotoMono(
                      fontSize: 12, color: Colors.black)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "System Art Prompt",
          style: GoogleFonts.robotoMono(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return artPromptSuggestions.where((String option) {
              return option
                  .toLowerCase()
                  .contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            setState(() {
              artPrompt = selection;
            });
          },
          fieldViewBuilder: (BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Enter your art prompt here...",
              ),
              onChanged: (value) {
                setState(() {
                  artPrompt = value;
                });
              },
            );
          },
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            setState(() {
              _isLoading = true;
            });
            // Simulate image generation
            // await Future.delayed(const Duration(seconds: 2));
            setState(() {
              _generateImage();
              _isLoading = false;
              _imageGenerated = true;
            });
          },
          child: const Text("Generate Image"),
        ),
        const SizedBox(height: 16),
        Text(
          "Font Size",
          style:
              GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Slider(
          min: 16,
          max: 64,
          divisions: 12,
          value: fontSize,
          label: fontSize.toStringAsFixed(0),
          onChanged: (newValue) {
            setState(() {
              fontSize = newValue;
            });
          },
        ),
        const SizedBox(height: 16),
        Text(
          "Font Style",
          style:
              GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return _googleFontsList;
            }
            final query = textEditingValue.text.toLowerCase();
            return _googleFontsList.where((String fontName) {
              return fontName.toLowerCase().contains(query);
            });
          },
          onSelected: (String selection) {
            setState(() {
              selectedFont = selection;
            });
          },
          fieldViewBuilder: (BuildContext context,
              TextEditingController textEditingController,
              FocusNode focusNode,
              VoidCallback onFieldSubmitted) {
            return TextField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search or select a font...',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.arrow_drop_down),
              ),
              onChanged: (value) {
                setState(() {
                  _searchFontQuery = value;
                });
              },
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          "Voice Options",
          style:
              GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_voices != null && _voices!.isNotEmpty)
          DropdownButton<Map<String, String>>(
            value: _selectedVoice,
            items: _voices!.map<DropdownMenuItem<Map<String, String>>>(
                (Map<String, String> voice) {
              final voiceLabel = "${voice['name']} (${voice['locale']})";
              return DropdownMenuItem<Map<String, String>>(
                value: voice,
                child: Text(voiceLabel),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedVoice = newValue;
              });
            },
          )
        else
          const Text("No voices available."),
        const SizedBox(height: 8),
        Row(
          children: [
            Text("Rate: ", style: GoogleFonts.robotoMono()),
            Expanded(
              child: Slider(
                value: _rate,
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  setState(() {
                    _rate = value;
                  });
                },
              ),
            ),
            Text(_rate.toStringAsFixed(2), style: GoogleFonts.robotoMono()),
          ],
        ),
        Row(
          children: [
            Text("Pitch: ", style: GoogleFonts.robotoMono()),
            Expanded(
              child: Slider(
                value: _pitch,
                min: 0.5,
                max: 2.0,
                onChanged: (value) {
                  setState(() {
                    _pitch = value;
                  });
                },
              ),
            ),
            Text(_pitch.toStringAsFixed(2), style: GoogleFonts.robotoMono()),
          ],
        ),
        Row(
          children: [
            Text("Volume: ", style: GoogleFonts.robotoMono()),
            Expanded(
              child: Slider(
                value: _volume,
                min: 0.0,
                max: 1.0,
                onChanged: (value) {
                  setState(() {
                    _volume = value;
                  });
                },
              ),
            ),
            Text(_volume.toStringAsFixed(2), style: GoogleFonts.robotoMono()),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          "Upload Default Music (Max 30 sec)",
          style:
              GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _pickMusicFile,
              icon: const Icon(Icons.upload_file),
              label: const Text("Upload Music"),
            ),
            const SizedBox(width: 16),
            if (kIsWeb && musicFileName != null)
              Flexible(
                child: Text(
                  musicFileName!,
                  style: GoogleFonts.robotoMono(),
                ),
              )
            else if (!kIsWeb && musicFile != null)
              Flexible(
                child: Text(
                  musicFile!.path.split('/').last,
                  style: GoogleFonts.robotoMono(),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Modified _buildLivePreview()
  Widget _buildLivePreview() {
    return Container(
      width: double.infinity,
      height: 600, // Fixed height for the container
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Live Preview",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              child: !_imageGenerated
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Center(
                          child: Text(
                            "Press Generate Image button to generate template",
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Display the art prompt even before image generation
                        Text(
                          artPrompt.isEmpty
                              ? "Your art prompt preview will appear here..."
                              : artPrompt,
                          style: getPreviewTextStyle(),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        // Center the AspectRatio widget
                        Center(
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: 337.5,
                              maxHeight: 600,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (aiImageUrl !=
                                        null) // Check if aiImageUrl is not null
                                      Image.network(
                                        aiImageUrl!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        loadingBuilder: (BuildContext context,
                                            Widget child,
                                            ImageChunkEvent? loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                        errorBuilder: (BuildContext context,
                                            Object error,
                                            StackTrace? stackTrace) {
                                          return Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Failed to load image: $error',
                                                  style: const TextStyle(
                                                      color: Colors.red),
                                                  textAlign: TextAlign.center,
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _imageGenerated = false;
                                                    });
                                                  },
                                                  child: const Text('Retry'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    // Text Overlay
                                    Positioned(
                                      bottom: 20,
                                      left: 16,
                                      right: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12.0,
                                          vertical: 8.0,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        child: Text(
                                          artPrompt.isEmpty
                                              ? "Your art prompt will appear here"
                                              : artPrompt,
                                          style: getPreviewTextStyle()
                                              .copyWith(color: Colors.white),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isPlaying ||
                            musicFile != null ||
                            musicBytes != null)
                          _buildMusicPlayer(),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // Function to generate the image using OpenAI
  Future<void> _generateImage() async {
    if (artPrompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an art prompt.")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    String defaultPrompt =
        " Please generate the image in a vertical 9:16 aspect ratio (ideal for TikTok videos and Instagram Reels).";
    try {
      final image = await OpenAI.instance.image.create(
        prompt: artPrompt + defaultPrompt,
        n: 1,
        size: OpenAIImageSize.size1024,
        responseFormat: OpenAIImageResponseFormat.url,
      );

      if (image.data.isNotEmpty) {
        setState(() {
          aiImageUrl = image.data.first.url;
          _imageGenerated = true; // Set the flag to true
        });
      } else {
        // Handle empty response
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Image generation failed. No image returned.")),
        );
      }
    } catch (e) {
      // Handle errors (e.g., network issues, API errors)
      debugPrint("Error generating image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image generation failed: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createTemplate() async {
    setState(() {
      _isLoading = true; // Show loading indicator.
    });

    try {
      String? musicDownloadUrl;
      if (kIsWeb && musicBytes != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'audio/${DateTime.now().millisecondsSinceEpoch}_$musicFileName');
        final uploadTask = storageRef.putData(musicBytes!);
        final snapshot = await uploadTask;
        musicDownloadUrl = await snapshot.ref.getDownloadURL();
      } else if (!kIsWeb && musicFile != null) {
        final storageRef = FirebaseStorage.instance.ref().child(
            'audio/${DateTime.now().millisecondsSinceEpoch}_${musicFile!.path.split('/').last}');
        final uploadTask = storageRef.putFile(musicFile!);
        final snapshot = await uploadTask;
        musicDownloadUrl = await snapshot.ref.getDownloadURL();
      }

      final templateData = {
        'artPrompt': artPrompt,
        'fontSize': fontSize,
        'font': selectedFont,
        'color': selectedColor.value,
        'voice': _selectedVoice,
        'rate': _rate,
        'pitch': _pitch,
        'volume': _volume,
        'musicFileName': musicFileName, //Original file name
        'musicUrl': musicDownloadUrl, // Store the download URL.
        'imageUrl': aiImageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('templates')
          .add(templateData);

      // 4. Update UI.
      setState(() {
        _isLoading = false; // Hide loading indicator.
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template created successfully!')),
      );
    } catch (e) {
      debugPrint("Error creating template: $e");
      setState(() {
        _isLoading = false; // Ensure loading indicator is hidden on error.
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating template: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create a Template",
            style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            // Wrap with SingleChildScrollView
            padding: const EdgeInsets.all(16.0),
            child: constraints.maxWidth > 600
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 1, child: _buildInputForm()),
                      const VerticalDivider(width: 32),
                      Expanded(flex: 1, child: _buildLivePreview()),
                    ],
                  )
                : Column(
                    children: [
                      _buildInputForm(),
                      const SizedBox(height: 32),
                      _buildLivePreview(),
                    ],
                  ),
          );
        },
      ),
      floatingActionButton: _isLoading
          ? const CircularProgressIndicator() // Show loading indicator.
          : FloatingActionButton(
              onPressed: _createTemplate,
              backgroundColor: Colors.black,
              child: const Icon(Icons.auto_fix_high, color: Colors.white),
            ),
    );
  }
}

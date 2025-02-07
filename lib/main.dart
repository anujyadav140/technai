import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:technai/create.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:technai/editor.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const Technai());
}

class Technai extends StatelessWidget {
  const Technai({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Short Form Video Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        textTheme: TextTheme(
          bodyLarge: GoogleFonts.robotoMono(color: Colors.black),
          bodyMedium: GoogleFonts.robotoMono(color: Colors.black),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _buildFeatureBox({
    required String title,
    required IconData icon,
    required String description,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: InkWell(
        // Makes the container clickable
        onTap: onPressed,
        borderRadius:
            BorderRadius.circular(12), // Match the Container's border radius
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.grey[100], // Light grey background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Fit content vertically
            children: [
              Icon(icon, size: 40, color: Colors.black),
              const SizedBox(height: 12),
              Text(
                title,
                style: GoogleFonts.robotoMono(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.robotoMono(fontSize: 14, color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AnimatedTextKit(
          animatedTexts: [
            TypewriterAnimatedText(
              'Technai',
              textStyle: GoogleFonts.robotoMono(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              speed: const Duration(milliseconds: 100),
            ),
          ],
          totalRepeatCount: 1,
          displayFullTextOnTap: true, // Important: prevent early stopping
          stopPauseOnTap: true,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.black,
            height: 1.0,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch the row
          children: [
            const SizedBox(
              height: 24,
            ),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly, // Consistent spacing
              children: [
                _buildFeatureBox(
                  title: "Create a Template",
                  icon: Icons.create,
                  description: "Design custom video templates from scratch.",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateATemplate(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16), // Add spacing between boxes
                _buildFeatureBox(
                  title: "Use Templates",
                  icon: Icons.view_module,
                  description: "Start creating videos with a template.",
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const VideoEditorExpandedPage()));
                  },
                ),
                const SizedBox(width: 16),
                _buildFeatureBox(
                  title: "Your Work",
                  icon: Icons.folder_open,
                  description: "Access and manage your saved video projects.",
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

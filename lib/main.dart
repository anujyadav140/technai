import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:technai/create.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
void main() async {
  WidgetsFlutterBinding
      .ensureInitialized(); // Ensures all plugins are initialized
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

  /// A helper method to build an icon button with a circular border and label.
  Widget _buildIconButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: IconButton(
            icon: Icon(icon, color: Colors.black),
            onPressed: onPressed,
            iconSize: 40,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.robotoMono(fontSize: 16, color: Colors.black),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Typewriter Effect
              AnimatedTextKit(
                isRepeatingAnimation: true,
                repeatForever: true,
                animatedTexts: [
                  TypewriterAnimatedText(
                    'Technai',
                    textStyle: GoogleFonts.robotoMono(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    speed: const Duration(milliseconds: 100),
                  ),
                  TypewriterAnimatedText(
                    'Your source to get inspired and create rapid prototyping for your ideas!',
                    textStyle: GoogleFonts.robotoMono(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                    speed: const Duration(milliseconds: 50),
                  ),
                ],
                totalRepeatCount: 1,
              ),
              const SizedBox(height: 32),

              // Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildIconButton(
                    label: "Create a Template",
                    icon: Icons.create,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CreateATemplate(),
                        ),
                      );
                    },
                  ),
                  _buildIconButton(
                    label: "Use Templates",
                    icon: Icons.view_module,
                    onPressed: () {},
                  ),
                  _buildIconButton(
                    label: "Your Work",
                    icon: Icons.folder_open,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


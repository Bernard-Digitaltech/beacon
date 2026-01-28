import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'pages/scanner_page.dart';
import 'utils/app_logger.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Set system UI mode (wrapped in try-catch)
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } catch (e) {
    print('Could not set system UI mode: $e');
  }

  // Run app - ALL initialization happens INSIDE the app after permission check
  // DO NOT initialize native services here!
  runApp(const BeaconsFlutterExampleApp());
}

class BeaconsFlutterExampleApp extends StatelessWidget {
  const BeaconsFlutterExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BeaconScannerPage(),
    );
  }
}

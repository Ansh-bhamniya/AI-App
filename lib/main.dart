import 'package:aiapp/home_page.dart';
import 'package:aiapp/pallete.dart';
import 'package:aiapp/services/conversation_controller.dart';
import 'package:aiapp/services/settings_controller.dart';
import 'package:aiapp/services/voice_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController();
  final voice = VoiceService();
  await Future.wait([settings.load(), voice.init()]);
  runApp(MyApp(settings: settings, voice: voice));
}

class MyApp extends StatelessWidget {
  final SettingsController settings;
  final VoiceService voice;

  const MyApp({super.key, required this.settings, required this.voice});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: voice),
        ChangeNotifierProvider(
          create: (_) => ConversationController(settingsController: settings, voice: voice),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'AI Assistant',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Pallete.mainFontColor,
          scaffoldBackgroundColor: Pallete.whiteColor,
          appBarTheme: const AppBarTheme(backgroundColor: Pallete.whiteColor),
        ),
        home: const HomePage(),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.init();
  runApp(const ChronicDietApp());
}

class ChronicDietApp extends StatelessWidget {
  const ChronicDietApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final brand = AppState.instance.brandColor;
        final title = AppState.instance.productTitle;
        return MaterialApp(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: brand,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: AppState.instance.isDiabetes
                ? const Color(0xFFFFF7ED)
                : AppState.instance.isHypertension
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF3F7F6),
            appBarTheme: AppBarTheme(
              backgroundColor: brand,
              foregroundColor: Colors.white,
            ),
          ),
          home: const HomePage(),
        );
      },
    );
  }
}

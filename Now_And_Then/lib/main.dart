import 'package:NOW_AND_THEN/screens/splash_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:NOW_AND_THEN/database/add_data.dart';
import 'package:NOW_AND_THEN/screens/home_screen.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Now And Then',
      theme: ThemeData(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Colors.blueAccent,
        ),
        scaffoldBackgroundColor: Colors.white,
        // bottomAppBarTheme: BottomAppBarTheme(
        //   color: Colors.blue[50], // BottomAppBar의 색상 설정
        // ),
        iconTheme: IconThemeData(
          color: Colors.blue, // 아이콘 색상을 파란색으로 설정
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/home': (context) => HomeScreen(),
        '/add': (context) => const AddData(),
      },
    );
  }
}

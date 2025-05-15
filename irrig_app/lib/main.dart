import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/signup_page.dart';
import 'screens/main_page.dart';
import 'screens/backoffice_page.dart';
import 'screens/server_down_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kDebugMode) {
    try {
      //FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
      await FirebaseAuth.instance.useAuthEmulator('172.20.10.5', 9099);

    } catch (e) {
      // ignore: avoid_print
      print(e);
    }
  }
  runApp(const IrrigApp());
}


class IrrigApp extends StatelessWidget {
  const IrrigApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IRRIGO',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginPage(),
        '/signup': (_) => const SignUpPage(),
        '/main': (_) => const MainPage(),
        '/admin': (_) => const BackOfficePage(),
        '/down': (_) => const ServerDownPage(),
      },
    );
  }
}
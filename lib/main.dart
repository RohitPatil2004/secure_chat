import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '../Firebase/Firebase options.dart';
import 'Firebase/Auth provider.dart';
import 'Service_Providers/chat provider.dart';
import 'Service_Providers/key provider.dart';
import 'Routes/App route.dart';
import 'App theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SecureChatApp());
}

class SecureChatApp extends StatelessWidget {
  const SecureChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => KeyProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => chat!..updateAuth(auth),
        ),
      ],
      child: Builder(
        builder: (context) {
          final router = AppRouter.createRouter(context);
          return MaterialApp.router(
            title: 'SecureChat',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}
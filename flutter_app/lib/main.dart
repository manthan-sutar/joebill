import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/change_password_screen.dart';
import 'utils/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ProviderScope(child: JoeBillApp()));
}

class JoeBillApp extends ConsumerStatefulWidget {
  const JoeBillApp({super.key});

  @override
  ConsumerState<JoeBillApp> createState() => _JoeBillAppState();
}

class _JoeBillAppState extends ConsumerState<JoeBillApp> {
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await ref.read(authProvider.notifier).tryAutoLogin();
    if (mounted) setState(() => _checkingAuth = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return MaterialApp(
      title: "Joe's Corner",
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: _checkingAuth
          ? const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            )
          : auth.isLoggedIn
              ? (auth.user!.mustChangePassword
                  ? const ChangePasswordScreen()
                  : const MainShell())
              : const LoginScreen(),
    );
  }
}

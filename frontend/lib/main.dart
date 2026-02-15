import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart'; // Import
import 'dart:io'; // Import
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/login_screen.dart';
import 'screens/chat_screen.dart';
import 'l10n/app_localizations.dart';

import 'services/api_service.dart';
import 'services/update_service.dart'; // Import
import 'utils/ignore_ssl.dart';

void main() async {
  ignoreSSLErrors();
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.init();
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Check for forced update on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _checkForceUpdate();
    });
  }

  void _checkForceUpdate() async {
     final updateService = UpdateService();
     final info = await updateService.checkUpdate();
     if (info != null && info.forceUpdate) {
         // Use a global key or navigator key if available, but for now we need a context.
         // Since we are in main, it's tricky. 
         // Better to handle this in a top-level widget wrapper or AuthWrapper.
     }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, ChatProvider>(
          create: (_) => ChatProvider(),
          update: (_, auth, chat) => chat!..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'LLM Chat',
            themeMode: settings.themeMode,
            theme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              primarySwatch: Colors.blue,
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
            locale: settings.locale,
            localizationsDelegates: const [
              AppLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('en'),
              Locale('zh'),
            ],
            home: AuthWrapper(),
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    ApiService.onTokenExpired = () {
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).logout();
      }
    };
    Provider.of<AuthProvider>(context, listen: false).checkAuth();
    
    // Check for forced update
    WidgetsBinding.instance.addPostFrameCallback((_) {
       _checkForceUpdate();
    });
  }

  void _checkForceUpdate() async {
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      await settingsProvider.checkForUpdate();
      
      if (settingsProvider.hasUpdate && settingsProvider.updateInfo!.forceUpdate) {
          if (!mounted) return;
          _showForceUpdateDialog(settingsProvider.updateInfo!);
      }
  }

  void _showForceUpdateDialog(UpdateInfo info) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing by tapping outside
      builder: (context) {
        // Prevent back button
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text(S.of(context).updateAvailable), // Use localized string
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('v${info.version}'),
                SizedBox(height: 8),
                Text(info.changelog),
                SizedBox(height: 16),
                Text(S.of(context).forceUpdateMessage, style: TextStyle(color: Colors.red)),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                   _startUpdate(context, info);
                },
                child: Text(S.of(context).updateNow),
              ),
            ],
          ),
        );
      },
    );
  }

  void _startUpdate(BuildContext context, UpdateInfo info) {
    // Show progress dialog (reuse logic from SettingsScreen or duplicate simpler version)
    // For simplicity, we can use the same dialog class if we make it public or duplicate it here.
    // Let's duplicate a simple version here to avoid complex imports dependencies 
    // or refactor _UpdateProgressDialog to be public.
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ForceUpdateProgressDialog(info: info),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    if (authProvider.isAuthenticated) {
      return ChatScreen();
    } else {
      return LoginScreen();
    }
  }
}

class ForceUpdateProgressDialog extends StatefulWidget {
  final UpdateInfo info;
  ForceUpdateProgressDialog({required this.info});
  @override
  _ForceUpdateProgressDialogState createState() => _ForceUpdateProgressDialogState();
}

class _ForceUpdateProgressDialogState extends State<ForceUpdateProgressDialog> {
  double _progress = 0.0;
  String _status = '';
  final UpdateService _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDownload();
    });
  }

  void _startDownload() async {
    setState(() {
      _status = S.of(context).downloading; 
    });
    
    String url = Platform.isAndroid ? widget.info.downloadUrlAndroid : widget.info.downloadUrlWindows;
    
    final file = await _updateService.downloadUpdate(url, (received, total) {
      setState(() {
        if (total != -1) {
            _progress = received / total;
        }
      });
    });

    if (file != null) {
      setState(() {
        _status = S.of(context).install;
      });
      // Do not close dialog, just install
      await _updateService.installUpdate(file);
      // On Android, installation opens a new intent. The user might come back.
      // If forced, we should probably keep this dialog open or exit app?
      // Usually, just stay here.
    } else {
       setState(() {
        _status = S.of(context).downloadFailed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(_status),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: _progress),
              SizedBox(height: 10),
              Text('${(_progress * 100).toStringAsFixed(0)}%'),
            ],
          ),
        )
    );
  }
}

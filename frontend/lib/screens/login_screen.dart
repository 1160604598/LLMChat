import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  void _showSettingsDialog() {
    final s = S.of(context);
    final _urlController = TextEditingController(text: ApiService.baseUrl);
    
    showDialog(
      context: context,
      builder: (context) => Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return AlertDialog(
            title: Text(s.settings),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.serverUrl, style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: 'http://127.0.0.1:8000',
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(s.theme, style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    isExpanded: true,
                    onChanged: (ThemeMode? newValue) {
                      if (newValue != null) {
                        settings.setThemeMode(newValue);
                      }
                    },
                    items: [
                      DropdownMenuItem(value: ThemeMode.system, child: Text(s.system)),
                      DropdownMenuItem(value: ThemeMode.light, child: Text(s.light)),
                      DropdownMenuItem(value: ThemeMode.dark, child: Text(s.dark)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(s.language, style: TextStyle(fontWeight: FontWeight.bold)),
                  DropdownButton<Locale>(
                    value: settings.locale,
                    isExpanded: true,
                    onChanged: (Locale? newValue) {
                      if (newValue != null) {
                        settings.setLocale(newValue);
                      }
                    },
                    items: [
                      DropdownMenuItem(value: Locale('en'), child: Text(s.english)),
                      DropdownMenuItem(value: Locale('zh'), child: Text(s.chinese)),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () async {
                  if (_urlController.text.isNotEmpty) {
                    await ApiService.setBaseUrl(_urlController.text);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(s.serverUrlUpdated)),
                    );
                  }
                },
                child: Text(s.save),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final s = S.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.login),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: s.settings,
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: s.username),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: s.password),
              obscureText: true,
            ),
            SizedBox(height: 20),
            authProvider.isLoading
                ? CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: () async {
                      try {
                        await authProvider.login(
                          _usernameController.text,
                          _passwordController.text,
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${s.loginFailed}: $e')),
                        );
                      }
                    },
                    child: Text(s.login),
                  ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => RegisterScreen()),
                );
              },
              child: Text(s.createAccount),
            ),
          ],
        ),
      ),
    );
  }
}

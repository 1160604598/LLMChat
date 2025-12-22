import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    if (user != null) {
      _baseUrlController.text = user.modelBaseUrl ?? '';
      _apiKeyController.text = user.modelApiKey ?? '';
      _modelNameController.text = user.modelName ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).settings)),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Language
            Text(S.of(context).language, style: Theme.of(context).textTheme.titleMedium),
            DropdownButton<Locale>(
              value: settingsProvider.locale,
              isExpanded: true,
              onChanged: (Locale? newValue) {
                if (newValue != null) {
                  settingsProvider.setLocale(newValue);
                }
              },
              items: [
                DropdownMenuItem(value: Locale('en'), child: Text(S.of(context).english)),
                DropdownMenuItem(value: Locale('zh'), child: Text(S.of(context).chinese)),
              ],
            ),
            SizedBox(height: 16),
            
            // Theme
            Text(S.of(context).theme, style: Theme.of(context).textTheme.titleMedium),
             DropdownButton<ThemeMode>(
              value: settingsProvider.themeMode,
              isExpanded: true,
              onChanged: (ThemeMode? newValue) {
                if (newValue != null) {
                  settingsProvider.setThemeMode(newValue);
                }
              },
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(S.of(context).system)),
                DropdownMenuItem(value: ThemeMode.light, child: Text(S.of(context).light)),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(S.of(context).dark)),
              ],
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 10),

            Text(S.of(context).modelConfig, style: Theme.of(context).textTheme.titleMedium),
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(labelText: S.of(context).baseUrl, hintText: 'https://api.openai.com/v1'),
            ),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(labelText: S.of(context).apiKey),
              obscureText: true,
            ),
            TextField(
              controller: _modelNameController,
              decoration: InputDecoration(labelText: S.of(context).modelName, hintText: 'gpt-3.5-turbo'),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await authProvider.updateConfig(
                      _baseUrlController.text,
                      _apiKeyController.text,
                      _modelNameController.text,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.of(context).configUpdated)),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to save settings: $e')),
                    );
                  }
                },
                child: Text(S.of(context).save),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  authProvider.logout();
                  Navigator.pop(context); // Close settings
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: Text(S.of(context).logout),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

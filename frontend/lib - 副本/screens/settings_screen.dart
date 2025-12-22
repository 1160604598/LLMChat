import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

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

    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _baseUrlController,
              decoration: InputDecoration(labelText: 'Model Base URL', hintText: 'https://api.openai.com/v1'),
            ),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(labelText: 'API Key'),
              obscureText: true,
            ),
            TextField(
              controller: _modelNameController,
              decoration: InputDecoration(labelText: 'Model Name', hintText: 'gpt-3.5-turbo'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                try {
                  await authProvider.updateConfig(
                    _baseUrlController.text,
                    _apiKeyController.text,
                    _modelNameController.text,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Settings saved')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save settings: $e')),
                  );
                }
              },
              child: Text('Save'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                authProvider.logout();
                Navigator.pop(context); // Close settings
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}

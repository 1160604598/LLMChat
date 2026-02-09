import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/user.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh user data to ensure model configs are up to date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final user = authProvider.user;

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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(S.of(context).modelConfig, style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: Icon(Icons.add_circle),
                  onPressed: () => _showAddModelDialog(context),
                  tooltip: S.of(context).addModel,
                ),
              ],
            ),
            
            if (user != null && user.modelConfigs.isNotEmpty)
                ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: user.modelConfigs.length,
                    onReorder: (oldIndex, newIndex) async {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final List<ModelConfig> items = List.from(user.modelConfigs);
                      final ModelConfig item = items.removeAt(oldIndex);
                      items.insert(newIndex, item);
                      
                      await authProvider.reorderModelConfigs(items);
                    },
                    itemBuilder: (context, index) {
                        final config = user.modelConfigs[index];
                        return Card(
                            key: ValueKey(config.id),
                            margin: EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                                title: Text(config.name),
                                subtitle: Text('${config.provider} - ${config.modelName}'),
                                onTap: () => _showEditModelDialog(context, config),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                        icon: Icon(Icons.delete, color: Colors.red),
                                        onPressed: () => _confirmDelete(context, config.id!),
                                    ),
                                    Icon(Icons.drag_handle),
                                  ],
                                ),
                            ),
                        );
                    },
                ),
            if (user == null || user.modelConfigs.isEmpty)
                Text(S.of(context).noModelConfig, style: TextStyle(color: Colors.grey)),

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

  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(S.of(context).delete),
        content: Text(S.of(context).areYouSure),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Provider.of<AuthProvider>(context, listen: false).deleteModelConfig(id);
            },
            child: Text(S.of(context).delete, style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddModelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ModelConfigDialog(),
    );
  }

  void _showEditModelDialog(BuildContext context, ModelConfig config) {
    showDialog(
      context: context,
      builder: (context) => ModelConfigDialog(config: config),
    );
  }
}

class ModelConfigDialog extends StatefulWidget {
  final ModelConfig? config;

  ModelConfigDialog({this.config});

  @override
  _ModelConfigDialogState createState() => _ModelConfigDialogState();
}

class _ModelConfigDialogState extends State<ModelConfigDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelNameController = TextEditingController();
  String _selectedProvider = 'OpenAI';

  @override
  void initState() {
    super.initState();
    if (widget.config != null) {
      _nameController.text = widget.config!.name;
      _baseUrlController.text = widget.config!.baseUrl;
      _apiKeyController.text = widget.config!.apiKey ?? '';
      _modelNameController.text = widget.config!.modelName;
      _selectedProvider = widget.config!.provider;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.config != null;
    return AlertDialog(
      title: Text(isEditing ? S.of(context).editModel : S.of(context).addModel),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: S.of(context).configName),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              DropdownButtonFormField<String>(
                value: _selectedProvider,
                decoration: InputDecoration(labelText: S.of(context).modelProvider),
                items: [
                  DropdownMenuItem(value: 'OpenAI', child: Text('OpenAI')),
                  DropdownMenuItem(value: 'Ollama', child: Text('Ollama')),
                  DropdownMenuItem(value: 'DeepSeek', child: Text('DeepSeek')),
                  DropdownMenuItem(value: 'Zhipu', child: Text('Zhipu AI')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedProvider = value!;
                    // Auto-fill defaults only if not editing or empty
                    if (!isEditing || _baseUrlController.text.isEmpty) {
                       if (_selectedProvider == 'Ollama') {
                        _baseUrlController.text = 'http://localhost:11434/v1';
                      } else if (_selectedProvider == 'OpenAI') {
                        _baseUrlController.text = 'https://api.openai.com/v1';
                      } else if (_selectedProvider == 'DeepSeek') {
                        _baseUrlController.text = 'https://api.deepseek.com';
                      }
                    }
                  });
                },
              ),
              TextFormField(
                controller: _baseUrlController,
                decoration: InputDecoration(labelText: S.of(context).baseUrl),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _apiKeyController,
                decoration: InputDecoration(labelText: S.of(context).apiKey),
                obscureText: true,
              ),
              TextFormField(
                controller: _modelNameController,
                decoration: InputDecoration(labelText: S.of(context).modelName),
                validator: (value) => value!.isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(S.of(context).cancel),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              try {
                final config = ModelConfig(
                  id: widget.config?.id,
                  name: _nameController.text,
                  baseUrl: _baseUrlController.text,
                  apiKey: _apiKeyController.text,
                  modelName: _modelNameController.text,
                  provider: _selectedProvider,
                );
                
                if (isEditing) {
                  await Provider.of<AuthProvider>(context, listen: false).updateModelConfig(config);
                } else {
                  await Provider.of<AuthProvider>(context, listen: false).addModelConfig(config);
                }
                
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
              }
            }
          },
          child: Text(S.of(context).save),
        ),
      ],
    );
  }
}

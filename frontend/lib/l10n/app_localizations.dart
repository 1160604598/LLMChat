import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class S {
  final Locale locale;

  S(this.locale);

  static S of(BuildContext context) {
    // Simple localization lookup
    // In a real app, use Localizations.of<S>(context, S)
    // Here we will just look up the provider or pass the locale
    return S(Localizations.localeOf(context));
  }

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'appTitle': 'LLM Chat',
      'login': 'Login',
      'username': 'Username',
      'password': 'Password',
      'loginFailed': 'Login Failed',
      'createAccount': 'Create an account',
      'serverSettings': 'Server Settings',
      'serverUrl': 'Server URL',
      'cancel': 'Cancel',
      'save': 'Save',
      'serverUrlUpdated': 'Server URL updated',
      'register': 'Register',
      'registrationSuccessful': 'Registration successful, please login',
      'registrationFailed': 'Registration Failed',
      'newChat': 'New Chat',
      'typeMessage': 'Type a message...',
      'conversations': 'Conversations',
      'settings': 'Settings',
      'theme': 'Theme',
      'language': 'Language',
      'light': 'Light',
      'dark': 'Dark',
      'system': 'System',
      'chinese': 'Chinese',
      'english': 'English',
      'modelConfig': 'Model Config',
      'baseUrl': 'Base URL',
      'apiKey': 'API Key',
      'modelName': 'Model Name',
      'configUpdated': 'Configuration updated',
      'copied': 'Copied to clipboard!',
      'logout': 'Logout',
    },
    'zh': {
      'appTitle': 'LLM 对话',
      'login': '登录',
      'username': '用户名',
      'password': '密码',
      'loginFailed': '登录失败',
      'createAccount': '创建账号',
      'serverSettings': '服务器设置',
      'serverUrl': '服务器地址',
      'cancel': '取消',
      'save': '保存',
      'serverUrlUpdated': '服务器地址已更新',
      'register': '注册',
      'registrationSuccessful': '注册成功，请登录',
      'registrationFailed': '注册失败',
      'newChat': '新对话',
      'typeMessage': '输入消息...',
      'conversations': '历史会话',
      'settings': '设置',
      'theme': '主题',
      'language': '语言',
      'light': '浅色',
      'dark': '深色',
      'system': '跟随系统',
      'chinese': '中文',
      'english': '英文',
      'modelConfig': '模型配置',
      'baseUrl': 'API 地址 (Base URL)',
      'apiKey': 'API 密钥 (Key)',
      'modelName': '模型名称',
      'configUpdated': '配置已更新',
      'copied': '已复制到剪贴板!',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  // Getters for easy access
  String get appTitle => get('appTitle');
  String get login => get('login');
  String get username => get('username');
  String get password => get('password');
  String get loginFailed => get('loginFailed');
  String get createAccount => get('createAccount');
  String get serverSettings => get('serverSettings');
  String get serverUrl => get('serverUrl');
  String get cancel => get('cancel');
  String get save => get('save');
  String get serverUrlUpdated => get('serverUrlUpdated');
  String get register => get('register');
  String get registrationSuccessful => get('registrationSuccessful');
  String get registrationFailed => get('registrationFailed');
  String get newChat => get('newChat');
  String get typeMessage => get('typeMessage');
  String get conversations => get('conversations');
  String get settings => get('settings');
  String get theme => get('theme');
  String get language => get('language');
  String get light => get('light');
  String get dark => get('dark');
  String get system => get('system');
  String get chinese => get('chinese');
  String get english => get('english');
  String get modelConfig => get('modelConfig');
  String get baseUrl => get('baseUrl');
  String get apiKey => get('apiKey');
  String get modelName => get('modelName');
  String get configUpdated => get('configUpdated');
  String get copied => get('copied');
  String get delete => get('delete');
  String get confirmDelete => get('confirmDelete');
  String get areYouSure => get('areYouSure');
  String get logout => get('logout');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<S> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) {
    return SynchronousFuture<S>(S(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

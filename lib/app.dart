import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/user/article_list_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'services/auth_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'База Знаний',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: Consumer<AuthService>(
        builder: (context, authService, child) {
          if (!authService.isAuthenticated) {
            return const LoginScreen();
          }
          
          // Админ -> на админ панель
          if (authService.username == 'admin') {
            return const AdminDashboardScreen();
          }
          
          // Все остальные -> на список статей
          return const ArticleListScreen();
        },
      ),
    );
  }
}
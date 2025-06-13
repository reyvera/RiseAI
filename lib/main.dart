import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/task.dart';
import 'screens/chat_assistant_screen.dart';
import 'screens/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'widgets/sidebar.dart';
import 'widgets/topbar.dart';
import 'theme/app_theme.dart';
import 'screens/create_task_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://yyndpmmgegvfpqkxovnb.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl5bmRwbW1nZWd2ZnBxa3hvdm5iIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDgzNzA0MzUsImV4cCI6MjA2Mzk0NjQzNX0.VVSxMEmd6yxc1CxIS2hPPjfNMAKobrq3Un9e0-TpZFU',
  );

  runApp(FocusTimeApp());
}

class FocusTimeApp extends StatelessWidget {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }
        
        return MaterialApp(
          title: 'FocusTime',
          theme: appTheme,
          routes: {
            '/login': (_) => const LoginScreen(),
            '/chat': (_) => ChatAssistantScreen(),
            '/calendar': (_) => CalendarScreen(),
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/create') {
              final task = settings.arguments as Task?;
              return MaterialPageRoute(
                builder: (_) => CreateTaskScreen(task: task),
              );
            }
            return null;
          },
          home: session != null ? MainLayout() : const LoginScreen(),
        );
      },
    );
  }
}

class MainLayout extends StatefulWidget {
  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  String _currentView = 'calendar'; // default

  void _handleNavigation(String view) {
    setState(() {
      _currentView = view; // 'calendar', 'chat', etc.
    });
  }

  Widget _getView() {
    switch (_currentView) {
      case 'calendar':
        return CalendarScreen();
      case 'chat':
        return ChatAssistantScreen();
      default:
        return Center(child: Text('Unknown view: $_currentView'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Sidebar(
            currentRoute: _currentView,
            onNavigate: _handleNavigation,
          ),
          Expanded(
            child: Column(
              children: [
                TopBar(
                  onLogout: () async {
                    await Supabase.instance.client.auth.signOut();
                    Navigator.pushReplacementNamed(context, '/login');
                  },
                ),
                Expanded(child: _getView()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child: _currentView != 'chat'
            ? FloatingActionButton.extended(
                key: ValueKey('fab'),
                icon: Icon(Icons.add),
                label: Text("New Task"),
                backgroundColor: Color(0xFF5562EA),
                onPressed: () {
                  Navigator.pushNamed(context, '/create');
                },
              )
            : SizedBox.shrink(key: ValueKey('none')),
      ),
    );
  }
}

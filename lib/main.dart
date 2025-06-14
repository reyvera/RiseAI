import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 👈 add this
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/task.dart';
import 'screens/chat_assistant_screen.dart';
import 'screens/login_screen.dart';
import 'screens/calendar_screen.dart';
import 'widgets/sidebar.dart';
import 'widgets/topbar.dart';
import 'theme/app_theme.dart';
import 'screens/create_task_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 Load .env
  await dotenv.load(fileName: ".env");

  // 👇 Get values from .env
  final supabaseUrl = dotenv.env['SUPABASE_URL']!;
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY']!;

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(RiseAIApp());
}

class RiseAIApp extends StatelessWidget {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    return MaterialApp(
      title: 'RiseAI',
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

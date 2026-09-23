import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../datos/local_data_service.dart';
import '../../../datos/supabase_database_service.dart';

class InicioSesion extends StatefulWidget {
  final UserRole? role;

  const InicioSesion({super.key, required this.role});

  @override
  State<InicioSesion> createState() => _InicioSesionState();
}

class _InicioSesionState extends State<InicioSesion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;

  final _userInput = TextEditingController();
  final _password = TextEditingController();
  final _supabase = SupabaseDatabaseService.instance;

  AppUser? _selectedUser;
  List<AppUser> _users = const [];
  bool _showPassword = false;
  bool _loadingUsers = true;
  bool _loggingIn = false;
  bool _usingSupabase = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final role = widget.role;
    if (role == null) return;

    var users = <AppUser>[];
    var usingSupabase = false;
    var error = '';

    if (_supabase.isReady) {
      usingSupabase = true;
      try {
        users = await _supabase.getUsersByRole(role);
      } catch (_) {
        error = 'Escribe tu correo y contraseña de Supabase para ingresar.';
      }
    }

    if (users.isEmpty && !usingSupabase) {
      users = LocalDataService.instance.getUsersByRole(role);
    }

    if (!mounted) return;
    setState(() {
      _users = users;
      _usingSupabase = usingSupabase;
      _loadingUsers = false;
      _error = error;
      if (_users.isNotEmpty) {
        _selectedUser = _users.first;
        _userInput.text = _usingSupabase
            ? _users.first.email
            : _users.first.name;
        _password.text = _usingSupabase ? '' : _users.first.password;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _userInput.dispose();
    _password.dispose();
    super.dispose();
  }

  void _syncTypedUser(String value) {
    final query = value.trim().toLowerCase();
    AppUser? found;
    for (final user in _users) {
      if (user.name.toLowerCase() == query ||
          user.email.toLowerCase() == query ||
          user.id.toLowerCase() == query) {
        found = user;
        break;
      }
    }

    setState(() {
      _selectedUser = found;
      if (found != null && !_usingSupabase) {
        _password.text = found.password;
      }
      _error = '';
    });
  }

  Future<void> _login() async {
    final role = widget.role;
    final user = _selectedUser;
    if (role == null) return;

    if (_userInput.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa tu usuario o correo.');
      return;
    }
    if (_password.text.trim().isEmpty) {
      setState(() => _error = 'Ingresa la contraseña.');
      return;
    }

    setState(() {
      _loggingIn = true;
      _error = '';
    });

    try {
      if (_usingSupabase) {
        final email = user?.email ?? _userInput.text.trim();
        final profile = await _supabase.signIn(
          email: email,
          password: _password.text.trim(),
          expectedRole: role,
        );
        if (!mounted) return;
        SessionController.instance.login(profile);
      } else {
        if (user == null) {
          setState(() => _error = 'Selecciona o escribe un usuario valido.');
          return;
        }
        if (_password.text.trim() != user.password) {
          setState(() => _error = 'Contraseña incorrecta.');
          return;
        }
        SessionController.instance.login(user);
      }
      if (mounted) context.go('/app');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo iniciar sesión. Revisa correo y contraseña.';
      });
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    final color = role?.color ?? const Color(0xFF6D28D9);
    final compact = MediaQuery.sizeOf(context).width < 380;

    if (role == null) {
      return Scaffold(
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/menu'),
            child: const Text('Volver al menú'),
          ),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      _LoginHeader(
                        compact: compact,
                        color: color,
                        role: role,
                        onBack: () => context.go('/menu'),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 26, 18, 0),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _loadingUsers
                              ? const Padding(
                                  padding: EdgeInsets.only(top: 30),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                              : _LoginForm(
                                  role: role,
                                  color: color,
                                  users: _users,
                                  selectedUser: _selectedUser,
                                  userInput: _userInput,
                                  password: _password,
                                  usingSupabase: _usingSupabase,
                                  showPassword: _showPassword,
                                  loggingIn: _loggingIn,
                                  error: _error,
                                  onUserTyped: _syncTypedUser,
                                  onUserSelected: (user) {
                                    setState(() {
                                      _selectedUser = user;
                                      _userInput.text = _usingSupabase
                                          ? user?.email ?? ''
                                          : user?.name ?? '';
                                      _password.text = _usingSupabase
                                          ? ''
                                          : user?.password ?? '';
                                      _error = '';
                                    });
                                  },
                                  onTogglePassword: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                  onLogin: _login,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginHeader extends StatelessWidget {
  final bool compact;
  final Color color;
  final UserRole role;
  final VoidCallback onBack;

  const _LoginHeader({
    required this.compact,
    required this.color,
    required this.role,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        12,
        compact ? 20 : 32,
        12,
        compact ? 26 : 40,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .82), color],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(34)),
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: onBack,
            ),
          ),
          Icon(role.icon, color: Colors.white, size: 54),
          const SizedBox(height: 12),
          const Text(
            'PracticApp',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Inicio de sesión - ${role.label}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final UserRole role;
  final Color color;
  final List<AppUser> users;
  final AppUser? selectedUser;
  final TextEditingController userInput;
  final TextEditingController password;
  final bool usingSupabase;
  final bool showPassword;
  final bool loggingIn;
  final String error;
  final ValueChanged<String> onUserTyped;
  final ValueChanged<AppUser?> onUserSelected;
  final VoidCallback onTogglePassword;
  final VoidCallback onLogin;

  const _LoginForm({
    required this.role,
    required this.color,
    required this.users,
    required this.selectedUser,
    required this.userInput,
    required this.password,
    required this.usingSupabase,
    required this.showPassword,
    required this.loggingIn,
    required this.error,
    required this.onUserTyped,
    required this.onUserSelected,
    required this.onTogglePassword,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona o escribe tu usuario',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          usingSupabase
              ? 'Inicio real conectado a Supabase.'
              : 'Modo demo local mientras cargas usuarios reales.',
          style: const TextStyle(color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: userInput,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          onChanged: onUserTyped,
          decoration: const InputDecoration(
            labelText: 'Usuario o correo',
            hintText: 'Ej. usuario@correo.com',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<AppUser>(
          value: selectedUser,
          items: users
              .map(
                (user) => DropdownMenuItem(
                  value: user,
                  child: Text(user.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onUserSelected,
          decoration: InputDecoration(
            labelText: role.label,
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: password,
          obscureText: !showPassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onLogin(),
          decoration: InputDecoration(
            labelText: 'Contraseña',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: onTogglePassword,
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: error.isEmpty
              ? const SizedBox(height: 18)
              : Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      error,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: loggingIn ? null : onLogin,
            icon: loggingIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.login),
            label: Text(
              loggingIn ? 'Ingresando...' : 'Iniciar sesión',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (!usingSupabase) _DemoCredentials(users: users),
      ],
    );
  }
}

class _DemoCredentials extends StatelessWidget {
  final List<AppUser> users;

  const _DemoCredentials({required this.users});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Credenciales demo',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          ...users.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: user.role.color.withValues(alpha: .12),
                    foregroundColor: user.role.color,
                    child: Text(
                      user.avatar,
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    user.password,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

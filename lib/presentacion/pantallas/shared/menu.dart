import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../datos/local_data_service.dart';

class Menu extends StatelessWidget {
  const Menu({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final roles = UserRole.values
        .where((role) => role != UserRole.empresa)
        .map((role) => _RoleCard(role: role))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(20, compact ? 26 : 38, 20, 30),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4338CA), Color(0xFF7C3AED)],
                      ),
                    ),
                    child: const Column(
                      children: [
                        _LogoMark(size: 74),
                        SizedBox(height: 14),
                        Text(
                          'PracticApp',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Sistema de Control de Prácticas',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'IESTP Contralmirante Manuel Villar Olivera',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4FF),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '¿Quién eres?',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Selecciona tu rol para continuar',
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: compact ? 1 : 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: compact ? 2.8 : 1.05,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: roles,
                        ),
                        const SizedBox(height: 18),
                        const Center(
                          child: Text(
                            'PracticApp v1.0 demo local',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final UserRole role;

  const _RoleCard({required this.role});

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  double _scale = 1;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;

    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = .96),
      onTapCancel: () => setState(() => _scale = 1),
      onTapUp: (_) {
        setState(() => _scale = 1);
        context.go('/login/${role.routeName}');
      },
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [role.color.withValues(alpha: .85), role.color],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: role.color.withValues(alpha: .25),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(role.icon, color: Colors.white, size: 42),
              const SizedBox(height: 12),
              Text(
                role.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _description(role),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _description(UserRole role) {
    switch (role) {
      case UserRole.supervisor:
        return 'Gestión completa';
      case UserRole.encargado:
        return 'Asistencia y seguimiento';
      case UserRole.estudiante:
        return 'Registro y progreso';
      case UserRole.empresa:
        return 'Vacantes';
    }
  }
}

class _LogoMark extends StatelessWidget {
  final double size;

  const _LogoMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * .28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Icon(
        Icons.menu_book_rounded,
        color: const Color(0xFF6D28D9),
        size: size * .55,
      ),
    );
  }
}

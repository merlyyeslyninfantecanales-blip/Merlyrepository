import 'package:flutter/material.dart';

class Dashboard extends StatelessWidget {
  final String rol;

  const Dashboard({super.key, required this.rol});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard $rol')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Bienvenido $rol', style: const TextStyle(fontSize: 22)),

            const SizedBox(height: 20),

            if (rol == 'Supervisor') ...[
              const Text('✔ Ver reportes'),
              const Text('✔ Gestionar estudiantes'),
            ],

            if (rol == 'Encargado') ...[const Text('✔ Control asistencia')],

            if (rol == 'Estudiante') ...[const Text('✔ Registrar prácticas')],

            if (rol == 'Empresa') ...[const Text('✔ Publicar vacantes')],
          ],
        ),
      ),
    );
  }
}

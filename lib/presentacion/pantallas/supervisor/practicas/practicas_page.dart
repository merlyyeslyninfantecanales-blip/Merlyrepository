import 'package:flutter/material.dart';

class PracticasPage extends StatelessWidget {
  const PracticasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prácticas')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: const [
            _PracticaCard(
              estudiante: 'Ana Torres',
              empresa: 'TecnoSoluciones',
              estado: 'En práctica',
            ),
            _PracticaCard(
              estudiante: 'Luis Ramirez',
              empresa: 'Innova Peru',
              estado: 'Pendiente',
            ),
            _PracticaCard(
              estudiante: 'Maria Quispe',
              empresa: 'Data Andes',
              estado: 'Completada',
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticaCard extends StatelessWidget {
  final String estudiante;
  final String empresa;
  final String estado;

  const _PracticaCard({
    required this.estudiante,
    required this.empresa,
    required this.estado,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.school),
        title: Text(estudiante, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(empresa, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(estado),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class EvaluacionPage extends StatelessWidget {
  const EvaluacionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluación')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: const [
            _EvaluacionCard(
              titulo: 'Informe semanal',
              detalle: 'Revisar avance de actividades',
              progreso: '80%',
            ),
            _EvaluacionCard(
              titulo: 'Desempeño en empresa',
              detalle: 'Validar calificación del encargado',
              progreso: '65%',
            ),
            _EvaluacionCard(
              titulo: 'Evaluación final',
              detalle: 'Pendiente hasta completar la práctica',
              progreso: '20%',
            ),
          ],
        ),
      ),
    );
  }
}

class _EvaluacionCard extends StatelessWidget {
  final String titulo;
  final String detalle;
  final String progreso;

  const _EvaluacionCard({
    required this.titulo,
    required this.detalle,
    required this.progreso,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.assignment_turned_in),
        title: Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(detalle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Text(progreso),
      ),
    );
  }
}

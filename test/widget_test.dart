import 'package:flutter_test/flutter_test.dart';

import 'package:sistema_practicas/main.dart';

void main() {
  testWidgets('PracticApp abre en el menu de roles', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('PracticApp'), findsOneWidget);
    expect(find.text('Supervisor'), findsOneWidget);
    expect(find.text('Encargado'), findsOneWidget);
    expect(find.text('Estudiante'), findsOneWidget);
    expect(find.text('Empresa'), findsOneWidget);
  });
}

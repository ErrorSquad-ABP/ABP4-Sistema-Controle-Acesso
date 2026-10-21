import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/features/auth/login_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valida os limites do contrato e normaliza somente o e-mail', () {
    expect(LoginValidation.email('invalido'), isNotNull);
    expect(LoginValidation.email('a..b@exemplo.com'), isNotNull);
    expect(LoginValidation.email('Maria@exemplo.com'), isNull);
    expect(LoginValidation.password(''), isNotNull);
    expect(LoginValidation.password('a'), isNull);
    expect(LoginValidation.password('a' * 72), isNull);
    expect(LoginValidation.password('a' * 73), isNotNull);
    expect(
      LoginRequest(email: 'Maria@exemplo.com', password: ' senha ').toJson(),
      {'email': 'maria@exemplo.com', 'password': ' senha '},
    );
  });

  testWidgets('mostra erros por campo e permite revelar a senha', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Mostrar senha'));
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
  });

  testWidgets('entrada válida carrega e apresenta o stub sem criar sessão', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: App()));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextFormField).first,
      'maria.souza@exemplo.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'senha-forte-123');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Entrando…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('O login ainda não está disponível'),
      findsOneWidget,
    );
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });
}

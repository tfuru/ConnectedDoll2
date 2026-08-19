import 'package:flutter_test/flutter_test.dart';
import 'package:controller_app/main.dart';

void main() {
  testWidgets('App launch smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify main menu elements exist
    expect(find.text('推し活スピーカー'), findsWidgets);
    expect(find.text('音声プリセット一覧'), findsOneWidget);
    expect(find.text('デバイス設定・転送'), findsOneWidget);
    expect(find.byTooltip('ファームウェア更新・設定'), findsOneWidget);
  });
}

import 'package:cura/core/theme/app_colors.dart';
import 'package:cura/core/theme/app_theme.dart';
import 'package:cura/features/conversation/providers/conversation_provider.dart';
import 'package:cura/features/home/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConversationNotifier extends StateNotifier<ConversationState> {
  _FakeConversationNotifier() : super(const ConversationState());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Home screen visual coverage', () {
    testWidgets('matches the redesigned light layout',
        (WidgetTester tester) async {
      await _pumpHomeScreen(
        tester,
        surfaceSize: const Size(390, 844),
        themeMode: ThemeMode.light,
      );

      final greeting = _expectedGreeting();
      final legacyDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

      expect(tester.takeException(), isNull);
      expect(find.text(greeting), findsOneWidget);
      expect(find.text('Tap to talk to Cura'), findsOneWidget);
      expect(find.text('Explain a letter'), findsOneWidget);
      expect(find.text('Take a photo of any official letter'), findsOneWidget);
      expect(find.text('Schedule my check-ins'), findsOneWidget);
      expect(find.text('Set times for Cura to call you'), findsOneWidget);
      expect(find.text('SOS'), findsOneWidget);
      expect(find.text('Mabel'), findsNothing);
      expect(find.text(legacyDate), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.background);

      final greetingText = tester.widget<Text>(find.text(greeting));
      expect(greetingText.style?.fontSize, 27);
      expect(greetingText.style?.fontWeight, FontWeight.w400);
      expect(greetingText.style?.color, AppColors.textPrimary);

      final orbLabel = tester.widget<Text>(find.text('Tap to talk to Cura'));
      expect(orbLabel.style?.fontSize, 24);
      expect(orbLabel.style?.color, AppColors.textPrimary);

      final orbShell = find.byKey(const ValueKey('voice-orb-shell'));
      expect(tester.getSize(orbShell), const Size(190, 190));
      expect(
        tester.getCenter(orbShell).dx,
        moreOrLessEquals(195, epsilon: 0.5),
      );

      expect(
        tester.getSize(find.byKey(const ValueKey('home-carer-button'))),
        const Size(58, 58),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('home-sos-button'))),
        const Size(58, 58),
      );

      final letterCard = find.byKey(const ValueKey('home-letter-card'));
      final scheduleCard = find.byKey(const ValueKey('home-schedule-card'));
      expect(tester.getSize(letterCard).width, 350);
      expect(tester.getSize(scheduleCard).width, 350);
      expect(
        tester.getTopLeft(letterCard).dy,
        greaterThan(tester.getBottomLeft(orbShell).dy),
      );

      final letterTitle = tester.widget<Text>(find.text('Explain a letter'));
      expect(letterTitle.style?.fontSize, 20);
      expect(letterTitle.style?.fontWeight, FontWeight.w600);
      expect(letterTitle.style?.color, AppColors.textPrimary);

      final letterSubtitle =
          tester.widget<Text>(find.text('Take a photo of any official letter'));
      expect(letterSubtitle.style?.fontSize, 15);
      expect(letterSubtitle.style?.color, AppColors.textSecondary);

      final sosText = tester.widget<Text>(find.text('SOS'));
      expect(sosText.style?.fontSize, 19);
      expect(sosText.style?.fontWeight, FontWeight.w700);
      expect(sosText.style?.color, AppColors.emergency);

      final letterDecoration = _panelDecoration(tester, 'home-letter-card');
      expect(letterDecoration.gradient, isNotNull);
      expect(letterDecoration.border, isA<Border>());
      expect(
        (letterDecoration.border! as Border).top.color,
        AppColors.glassBorder(_elementContext(tester, letterCard)),
      );

      final carerDecoration = _panelDecoration(tester, 'home-carer-button');
      expect(carerDecoration.gradient, isNotNull);
      expect(
        (carerDecoration.border! as Border).top.color,
        AppColors.glassBorder(
          _elementContext(tester, find.byKey(const ValueKey('home-carer-button'))),
        ),
      );
    });

    testWidgets('maps the redesign to the dark palette',
        (WidgetTester tester) async {
      await _pumpHomeScreen(
        tester,
        surfaceSize: const Size(390, 844),
        themeMode: ThemeMode.dark,
      );

      final greeting = _expectedGreeting();
      final legacyDate = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

      expect(tester.takeException(), isNull);
      expect(find.text(greeting), findsOneWidget);
      expect(find.text(legacyDate), findsNothing);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, AppColors.backgroundDark);

      final greetingText = tester.widget<Text>(find.text(greeting));
      expect(greetingText.style?.color, AppColors.textPrimaryDark);

      final orbLabel = tester.widget<Text>(find.text('Tap to talk to Cura'));
      expect(orbLabel.style?.fontSize, 24);
      expect(orbLabel.style?.color, AppColors.textPrimaryDark);

      final letterTitle = tester.widget<Text>(find.text('Explain a letter'));
      expect(letterTitle.style?.color, AppColors.textPrimaryDark);

      final letterSubtitle =
          tester.widget<Text>(find.text('Take a photo of any official letter'));
      expect(letterSubtitle.style?.color, AppColors.textSecondaryDark);

      final scheduleSubtitle =
          tester.widget<Text>(find.text('Set times for Cura to call you'));
      expect(scheduleSubtitle.style?.color, AppColors.textSecondaryDark);

      final sosText = tester.widget<Text>(find.text('SOS'));
      expect(sosText.style?.color, AppColors.emergencyDark);

      final sosDecoration = _panelDecoration(tester, 'home-sos-button');
      expect(sosDecoration.gradient, isNotNull);
      expect(
        (sosDecoration.border! as Border).top.color,
        AppColors.glassBorder(
          _elementContext(
            tester,
            find.byKey(const ValueKey('home-sos-button')),
          ),
        ),
      );

      final cardDecoration = _panelDecoration(tester, 'home-letter-card');
      expect(
        (cardDecoration.border! as Border).top.color,
        AppColors.glassBorder(_elementContext(
          tester,
          find.byKey(const ValueKey('home-letter-card')),
        )),
      );
    });

    testWidgets('stays proportionate on a compact viewport',
        (WidgetTester tester) async {
      await _pumpHomeScreen(
        tester,
        surfaceSize: const Size(320, 568),
        themeMode: ThemeMode.light,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(_expectedGreeting()), findsOneWidget);
      expect(find.text('Tap to talk to Cura'), findsOneWidget);

      final orbLabel = tester.widget<Text>(find.text('Tap to talk to Cura'));
      expect(orbLabel.style?.fontSize, 20);

      expect(
        tester.getSize(find.byKey(const ValueKey('home-letter-card'))).width,
        280,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('home-schedule-card'))).width,
        280,
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('home-carer-button'))),
        const Size(58, 58),
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('home-letter-card'))).dy,
        greaterThan(
          tester.getBottomLeft(find.byKey(const ValueKey('voice-orb-shell'))).dy,
        ),
      );
    });
  });
}

Future<void> _pumpHomeScreen(
  WidgetTester tester, {
  required Size surfaceSize,
  required ThemeMode themeMode,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationProvider.overrideWith(
          (ref, context) => _FakeConversationNotifier(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        home: const HomeScreen(),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

String _expectedGreeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning,';
  if (hour < 18) return 'Good afternoon,';
  return 'Good evening,';
}

BuildContext _elementContext(WidgetTester tester, Finder finder) {
  return tester.element(finder);
}

BoxDecoration _panelDecoration(WidgetTester tester, String key) {
  final panel = tester.widget<Ink>(find.byKey(ValueKey(key)));
  return panel.decoration! as BoxDecoration;
}

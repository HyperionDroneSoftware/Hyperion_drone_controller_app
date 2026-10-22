import 'package:flutter/material.dart';

void main() => runApp(const HyperionApp());

class HyperionApp extends StatelessWidget {
  const HyperionApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Hyperion Drone Controller',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3B82F6),
            brightness: Brightness.dark,
            surface: const Color(0xFF111C2B),
          ),
          scaffoldBackgroundColor: const Color(0xFF08111E),
          useMaterial3: true,
        ),
        home: const ControllerScreen(),
      );
}

class ControllerScreen extends StatelessWidget {
  const ControllerScreen({super.key});

  static const _muted = Color(0xFF9BAAC0);

  void _demo(BuildContext context, String command) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('«$command»: управление появится в следующей версии.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0x293B82F6),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(Icons.flight, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('HYPERION', style: TextStyle(fontSize: 12, letterSpacing: 2.4, color: _muted, fontWeight: FontWeight.w700)),
                            SizedBox(height: 3),
                            Text('Пульт управления', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Text('v0.1', style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _Panel(
                    child: Row(
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Color(0xFFFFB454), size: 23),
                        SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Дрон не подключён', style: TextStyle(fontWeight: FontWeight.w700)),
                              SizedBox(height: 4),
                              Text('Подключение появится в следующем этапе', style: TextStyle(color: _muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Icon(Icons.circle, color: Color(0xFFFFB454), size: 9),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _Panel(
                    color: Color(0xFF102642),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Color(0xFF74AAFF), size: 19),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Это первая версия экрана. Кнопки показывают отклик, но пока не отправляют команды дрону.',
                            style: TextStyle(color: Color(0xFFD3E3FA), fontSize: 12, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _SectionLabel('НАПРАВЛЕНИЕ'),
                  const SizedBox(height: 13),
                  _Panel(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      children: [
                        _DirectionButton(icon: Icons.keyboard_arrow_up, label: 'Вперёд', onPressed: (s) => _demo(context, s)),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _DirectionButton(icon: Icons.keyboard_arrow_left, label: 'Влево', onPressed: (s) => _demo(context, s)),
                            const SizedBox(width: 68, height: 60),
                            _DirectionButton(icon: Icons.keyboard_arrow_right, label: 'Вправо', onPressed: (s) => _demo(context, s)),
                          ],
                        ),
                        _DirectionButton(icon: Icons.keyboard_arrow_down, label: 'Назад', onPressed: (s) => _demo(context, s)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _SectionLabel('ПОЛЁТ'),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(child: _ActionButton(icon: Icons.flight_takeoff, label: 'Взлёт', onPressed: () => _demo(context, 'Взлёт'))),
                      const SizedBox(width: 12),
                      Expanded(child: _ActionButton(icon: Icons.flight_land, label: 'Посадка', onPressed: () => _demo(context, 'Посадка'))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _demo(context, 'Стоп'),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Аварийная остановка'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF7B83),
                        side: const BorderSide(color: Color(0x66FF7B83)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text('ПРОТОТИП ИНТЕРФЕЙСА · ПОДКЛЮЧЕНИЯ НЕТ', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, letterSpacing: 1.1, color: _muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color = const Color(0xFF111C2B), this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF1E2C3F)),
        ),
        child: child,
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 11, letterSpacing: 1.8, color: ControllerScreen._muted, fontWeight: FontWeight.w700),
      );
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 60,
        height: 60,
        child: IconButton.filledTonal(
          tooltip: label,
          onPressed: () => onPressed(label),
          icon: Icon(icon, size: 32),
          style: IconButton.styleFrom(
            foregroundColor: const Color(0xFFDCE9FB),
            backgroundColor: const Color(0xFF1A2B41),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: FilledButton.tonalIcon(
          onPressed: onPressed,
          icon: Icon(icon, size: 19),
          label: Text(label),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF172942),
            foregroundColor: const Color(0xFFDCE9FB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'drone_link_service.dart';

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

class ControllerScreen extends StatefulWidget {
  const ControllerScreen({super.key});

  @override
  State<ControllerScreen> createState() => _ControllerScreenState();
}

class _ControllerScreenState extends State<ControllerScreen>
    with WidgetsBindingObserver {
  static const _muted = Color(0xFF9BAAC0);
  final _droneLink = DroneLinkService();

  String? _wifiName;
  String? _gateway;
  bool _checkingWifi = false;
  bool _waitingForSettings = false;
  String? _wifiMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _droneLink.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings) {
      _waitingForSettings = false;
      _readWifiInfo();
    }
  }

  Future<bool> _requestWifiPermission() async {
    final permission = await Permission.locationWhenInUse.request();
    if (permission.isGranted) return true;

    if (mounted) {
      setState(() {
        _wifiMessage =
            'Разрешите доступ к местоположению, чтобы Android показал имя Wi-Fi сети.';
      });
    }
    return false;
  }

  Future<void> _readWifiInfo() async {
    if (!await _requestWifiPermission()) return;
    if (!mounted) return;

    setState(() {
      _checkingWifi = true;
      _wifiMessage = null;
    });

    try {
      final info = NetworkInfo();
      final name = await info.getWifiName();
      final gateway = await info.getWifiGatewayIP();
      if (!mounted) return;

      final cleanedName = name?.replaceAll('"', '').trim();
      setState(() {
        _wifiName = (cleanedName == null ||
                cleanedName.isEmpty ||
                cleanedName == '<unknown ssid>')
            ? null
            : cleanedName;
        _gateway = gateway;
        _checkingWifi = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checkingWifi = false;
        _wifiMessage =
            'Не удалось прочитать сеть. Проверьте разрешение и включите службы геолокации Android.';
      });
    }
  }

  Future<void> _openWifiSettings() async {
    if (!await _requestWifiPermission()) return;
    if (!mounted) return;

    await _droneLink.disconnect();
    setState(() {
      _waitingForSettings = true;
      _wifiMessage = null;
    });

    try {
      const intent = AndroidIntent(action: 'android.settings.WIFI_SETTINGS');
      await intent.launch();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _waitingForSettings = false;
        _wifiMessage = 'Не получилось открыть настройки Wi-Fi на этом устройстве.';
      });
    }
  }

  Future<void> _checkDrone() async {
    if (_wifiName == null) {
      await _openWifiSettings();
      return;
    }
    final gateway = _gateway;
    if (gateway == null || gateway.isEmpty || gateway == '0.0.0.0') {
      setState(() => _wifiMessage = 'Android не сообщил адрес шлюза Wi-Fi.');
      return;
    }
    await _droneLink.check(gateway, ssid: _wifiName);
  }

  void _showDemoMessage(String command) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('«$command»: команды управления появятся в следующих версиях.'),
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
                        decoration: const BoxDecoration(
                          color: Color(0x293B82F6),
                          borderRadius: BorderRadius.all(Radius.circular(15)),
                        ),
                        child: const Icon(Icons.flight, color: Color(0xFF3B82F6)),
                      ),
                      const SizedBox(width: 13),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('HYPERION',
                                style: TextStyle(
                                    fontSize: 12,
                                    letterSpacing: 2.4,
                                    color: _muted,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 3),
                            Text('Пульт управления',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      const Text('v0.4', style: TextStyle(color: _muted, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  AnimatedBuilder(
                    animation: _droneLink,
                    builder: (context, _) => _WifiCard(
                      name: _wifiName,
                      gateway: _gateway,
                      checking: _checkingWifi,
                      message: _wifiMessage,
                      linkState: _droneLink.state,
                      linkMessage: _droneLink.message,
                      responseTime: _droneLink.responseTime,
                      lastResponseAt: _droneLink.lastResponseAt,
                      onConnect: _checkDrone,
                      onSettings: _openWifiSettings,
                      onRefresh: _readWifiInfo,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _Panel(
                    color: Color(0xFF102642),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline,
                            color: Color(0xFF74AAFF), size: 19),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Версия 0.4 показывает задержку ответа и следит, не пропала ли подтверждённая связь. Команды полёта и запуска моторов пока не отправляются.',
                            style: TextStyle(
                                color: Color(0xFFD3E3FA),
                                fontSize: 12,
                                height: 1.45),
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
                        _DirectionButton(
                            icon: Icons.keyboard_arrow_up,
                            label: 'Вперёд',
                            onPressed: _showDemoMessage),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _DirectionButton(
                                icon: Icons.keyboard_arrow_left,
                                label: 'Влево',
                                onPressed: _showDemoMessage),
                            const SizedBox(width: 68, height: 60),
                            _DirectionButton(
                                icon: Icons.keyboard_arrow_right,
                                label: 'Вправо',
                                onPressed: _showDemoMessage),
                          ],
                        ),
                        _DirectionButton(
                            icon: Icons.keyboard_arrow_down,
                            label: 'Назад',
                            onPressed: _showDemoMessage),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const _SectionLabel('ПОЛЁТ'),
                  const SizedBox(height: 13),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                            icon: Icons.flight_takeoff,
                            label: 'Взлёт',
                            onPressed: () => _showDemoMessage('Взлёт')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                            icon: Icons.flight_land,
                            label: 'Посадка',
                            onPressed: () => _showDemoMessage('Посадка')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _showDemoMessage('Стоп'),
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('Аварийная остановка'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFF7B83),
                        side: const BorderSide(color: Color(0x66FF7B83)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Center(
                    child: Text(
                      'МОТОРЫ НЕ ЗАПУСКАЮТСЯ В ЭТОЙ ВЕРСИИ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 1.1, color: _muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _WifiCard extends StatelessWidget {
  const _WifiCard({
    required this.name,
    required this.gateway,
    required this.checking,
    required this.message,
    required this.linkState,
    required this.linkMessage,
    required this.responseTime,
    required this.lastResponseAt,
    required this.onConnect,
    required this.onSettings,
    required this.onRefresh,
  });

  final String? name;
  final String? gateway;
  final bool checking;
  final String? message;
  final DroneLinkState linkState;
  final String linkMessage;
  final Duration? responseTime;
  final DateTime? lastResponseAt;
  final VoidCallback onConnect;
  final VoidCallback onSettings;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final connected = name != null;
    final linkColor = switch (linkState) {
      DroneLinkState.answered => const Color(0xFF62D69A),
      DroneLinkState.connecting => const Color(0xFF74AAFF),
      DroneLinkState.silent => const Color(0xFFFFB454),
      DroneLinkState.idle => const Color(0xFF9BAAC0),
    };
    final linkLabel = switch (linkState) {
      DroneLinkState.answered => 'Связь подтверждена',
      DroneLinkState.connecting => 'Проверка связи…',
      DroneLinkState.silent => 'Дрон не ответил',
      DroneLinkState.idle => 'Связь не проверена',
    };
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                color: connected
                    ? const Color(0xFF62D69A)
                    : const Color(0xFFFFB454),
                size: 23,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  connected ? 'Телефон подключён к Wi-Fi' : 'Нет Wi-Fi сети',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (checking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            connected ? name! : 'Выберите Wi-Fi сеть квадрокоптера',
            style: const TextStyle(color: Color(0xFFB7C7DC), fontSize: 13),
          ),
          if (gateway != null) ...[
            const SizedBox(height: 4),
            Text('Шлюз: $gateway',
                style: const TextStyle(color: Color(0xFF9BAAC0), fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                linkState == DroneLinkState.answered
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                color: linkColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(linkLabel,
                    style: TextStyle(
                        color: linkColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(linkMessage,
              style: const TextStyle(
                  color: Color(0xFF9BAAC0), fontSize: 11, height: 1.4)),
          if (lastResponseAt != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                if (responseTime != null)
                  _LinkDetail(
                    icon: Icons.timer_outlined,
                    text: 'Задержка ${responseTime!.inMilliseconds} мс',
                  ),
                _LinkDetail(
                  icon: Icons.access_time_rounded,
                  text: 'Ответ ${_formatResponseTime(lastResponseAt!)}',
                ),
              ],
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!,
                style: const TextStyle(
                    color: Color(0xFFFFB454), fontSize: 12, height: 1.4)),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: checking || linkState == DroneLinkState.connecting
                      ? null
                      : onConnect,
                  icon: const Icon(Icons.cable_rounded, size: 18),
                  label: Text(connected ? 'Проверить связь' : 'Выбрать Wi-Fi'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.outlined(
                tooltip: 'Проверить сеть',
                onPressed: checking ? null : onRefresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: checking ? null : onSettings,
              icon: const Icon(Icons.settings_rounded, size: 16),
              label: const Text('Открыть настройки Wi-Fi'),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatResponseTime(DateTime value) {
  final time = value.toLocal();
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

class _LinkDetail extends StatelessWidget {
  const _LinkDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF9BAAC0), size: 13),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(color: Color(0xFF9BAAC0), fontSize: 10)),
        ],
      );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.child,
    this.color = const Color(0xFF111C2B),
    this.padding = const EdgeInsets.all(18),
  });

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
        style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.8,
            color: _ControllerScreenState._muted,
            fontWeight: FontWeight.w700),
      );
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
}

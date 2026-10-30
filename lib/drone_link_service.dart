import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DroneLinkState { idle, connecting, answered, silent }

/// Checks the E88 family's Wi-Fi control endpoint without sending flight input.
class DroneLinkService extends ChangeNotifier {
  static const _channel = MethodChannel('kg.edu.alatoo.alatoo_drone/network');
  static final _heartbeat = Uint8List.fromList([0x01, 0x01]);
  static final _enterWifiMode = Uint8List.fromList([0x42, 0x76]);
  static final _exitWifiMode = Uint8List.fromList([0x42, 0x77]);
  static final _wifi8kKeepAlive = Uint8List.fromList(
      [0xAA, 0x80, 0x80, 0x00, 0x80, 0x00, 0x80, 0x55]);

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;
  InternetAddress? _address;
  Timer? _keepAlive;
  Timer? _watchdog;
  DroneLinkState _state = DroneLinkState.idle;
  String _message = 'Связь с дроном не проверена';
  DateTime? _lastProbeAt;
  DateTime? _lastResponseAt;
  Duration? _responseTime;
  bool _boundToWifi = false;
  bool _wifi8k = false;
  bool _monitoring = false;
  int _generation = 0;

  DroneLinkState get state => _state;
  String get message => _message;
  DateTime? get lastResponseAt => _lastResponseAt;
  Duration? get responseTime => _responseTime;
  bool get isSessionActive =>
      _state == DroneLinkState.connecting || _socket != null || _boundToWifi;

  Future<void> check(String host, {String? ssid}) async {
    await disconnect();
    final generation = ++_generation;
    _setState(DroneLinkState.connecting, 'Закрепляю приложение за Wi-Fi…');

    final address = InternetAddress.tryParse(host);
    if (address == null) {
      _setState(DroneLinkState.idle, 'Не удалось определить адрес шлюза Wi-Fi.');
      return;
    }

    try {
      _boundToWifi = await _channel.invokeMethod<bool>('bindToWifi') ?? false;
    } on PlatformException {
      _boundToWifi = false;
    } on MissingPluginException {
      _boundToWifi = false;
    }

    if (generation != _generation) {
      await disconnect();
      return;
    }

    if (!_boundToWifi) {
      _setState(
        DroneLinkState.idle,
        'Android не смог закрепить соединение за Wi-Fi. Проверьте разрешения сети.',
      );
      return;
    }

    try {
      _address = address;
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final reply = Completer<Uint8List>();
      _subscription = _socket!.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = _socket?.receive();
        if (datagram == null || datagram.address.address != address.address) {
          return;
        }
        _recordResponse();
        if (!reply.isCompleted) {
          reply.complete(datagram.data);
        } else if (_monitoring && _state == DroneLinkState.silent) {
          _setState(
            DroneLinkState.answered,
            'Ответ от дрона восстановился; мониторинг связи продолжается.',
          );
        }
      });

      for (var attempt = 0; attempt < 12 && !reply.isCompleted; attempt++) {
        _sendProbe();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (generation != _generation) return;
      }

      if (generation != _generation) return;

      if (reply.isCompleted) {
        final response = await reply.future;
        final deviceId = response.isEmpty ? null : response.first;
        _monitoring = true;
        _startHeartbeat(1000, _heartbeat, 7099, expectReply: true);
        _watchdog?.cancel();
        _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
          final lastResponse = _lastResponseAt;
          if (_monitoring &&
              lastResponse != null &&
              DateTime.now().difference(lastResponse) >
                  const Duration(seconds: 4) &&
              _state == DroneLinkState.answered) {
            _setState(
              DroneLinkState.silent,
              'Нет ответа больше 4 секунд. Проверьте Wi-Fi и повторите проверку.',
            );
          }
        });
        _setState(
          DroneLinkState.answered,
          deviceId == null
              ? 'Дрон ответил на UDP 7099.'
              : 'Дрон ответил на UDP 7099 (код устройства $deviceId).',
        );
        return;
      }

      final normalizedSsid = ssid?.toLowerCase() ?? '';
      const e88Hints = [
        'wifi-ufo',
        'ufo',
        'e88',
        'e58',
        'lsrc',
        'hfun',
        'jy',
        'wifi-8k',
        'wifi_8k',
        'gd',
      ];
      if (!e88Hints.any((hint) => normalizedSsid.contains(hint))) {
        await disconnect();
        _setState(
          DroneLinkState.silent,
          'Ответа на UDP 7099 нет. Имя сети не распознано как E88; переключение режима не отправлялось.',
        );
        return;
      }

      // Some E88 boards are silent on UDP 7099. The reference app switches
      // those boards to Wi-Fi control, but cannot confirm the link by reply.
      _wifi8k = true;
      for (var attempt = 0; attempt < 6; attempt++) {
        _send(_enterWifiMode, 8080);
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (generation != _generation) return;
      }
      _startHeartbeat(790, _wifi8kKeepAlive, 8090);
      _setState(
        DroneLinkState.silent,
        'Ответа нет. Для E88 отправлен запрос переключения в Wi-Fi режим; связь пока не подтверждена.',
      );
    } on SocketException catch (error) {
      if (generation != _generation) return;
      await disconnect();
      _setState(DroneLinkState.idle, 'Ошибка UDP соединения: ${error.message}');
    }
  }

  void _send(Uint8List bytes, int port) {
    final socket = _socket;
    final address = _address;
    if (socket == null || address == null) return;
    socket.send(bytes, address, port);
  }

  void _sendProbe() {
    _lastProbeAt = DateTime.now();
    _send(_heartbeat, 7099);
  }

  void _recordResponse() {
    final probeAt = _lastProbeAt;
    if (probeAt != null) {
      _responseTime = DateTime.now().difference(probeAt);
    }
    _lastResponseAt = DateTime.now();
    notifyListeners();
  }

  void _startHeartbeat(int milliseconds, Uint8List packet, int port,
      {bool expectReply = false}) {
    _keepAlive?.cancel();
    _keepAlive = Timer.periodic(
      Duration(milliseconds: milliseconds),
      (_) {
        if (expectReply) {
          _sendProbe();
        } else {
          _send(packet, port);
        }
      },
    );
  }

  Future<void> disconnect({String? message}) async {
    _generation++;
    _keepAlive?.cancel();
    _keepAlive = null;
    _watchdog?.cancel();
    _watchdog = null;
    _monitoring = false;
    if (_wifi8k) _send(_exitWifiMode, 8080);
    _wifi8k = false;
    await _subscription?.cancel();
    _subscription = null;
    _socket?.close();
    _socket = null;
    _address = null;
    if (_boundToWifi) {
      try {
        await _channel.invokeMethod<bool>('unbind');
      } on PlatformException {
        // The Android process is already leaving the Wi-Fi network.
      } on MissingPluginException {
        // No native network binding was registered.
      }
    }
    _boundToWifi = false;
    _state = DroneLinkState.idle;
    _message = message ?? 'Связь с дроном не проверена';
    _lastProbeAt = null;
    _lastResponseAt = null;
    _responseTime = null;
    notifyListeners();
  }

  void _setState(DroneLinkState state, String message) {
    _state = state;
    _message = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _keepAlive?.cancel();
    _watchdog?.cancel();
    if (_wifi8k) _send(_exitWifiMode, 8080);
    _subscription?.cancel();
    _socket?.close();
    super.dispose();
  }
}

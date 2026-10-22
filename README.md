# Hyperion Drone Controller

Первая учебная версия приложения для управления дроном на Flutter.

## Версия 0.1

- Приложение открывает экран контроллера.
- На экране есть кнопки направлений, взлёта, посадки и остановки.
- Кнопки пока показывают демонстрационное сообщение. Подключения по Wi-Fi и отправки команд дрону в этой версии нет.

## Запуск

Установите Flutter SDK, затем в корне проекта выполните:

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

Команда `flutter create` добавит платформенные папки Flutter в этот минимальный проект. Для сборки iOS нужен macOS с Xcode.

## План развития

1. Базовый экран и кнопки — текущая версия.
2. Поиск и подключение к дрону по Wi-Fi.
3. Управление одним мотором для проверки связи.
4. Управление всеми моторами.
5. Камера и видеопоток.
6. Подготовка и проверка поддержки iOS.
*** Add File: pubspec.yaml
name: hyperion_drone_controller
description: Учебное приложение для поэтапного управления дроном Hyperion.
publish_to: 'none'
version: 0.1.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true
*** Add File: .gitignore
# Dart / Flutter
.dart_tool/
.packages
.pub-cache/
.pub/
build/
.flutter-plugins
.flutter-plugins-dependencies
.metadata

# IDE
.idea/
*.iml
.vscode/

# Android build files
android/.gradle/
android/local.properties
android/key.properties
android/app/debug
android/app/profile
android/app/release

# iOS build files
ios/Flutter/.last_build_id
ios/Pods/
ios/.symlinks/
ios/Flutter/ephemeral/
ios/Runner.xcworkspace/xcuserdata/

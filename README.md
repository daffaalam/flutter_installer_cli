# Flutter Installer

Installer for Flutter SDK, including Android SDK and Java SDK if not installed (automatic detection). Currently only for Windows. MacOS and Linux are under development.

### How to run

Download **[here](https://github.com/daffaalam/flutter_installer_cli/releases/latest)** and run right away.

### Screenshots

![screenshot](screenshots/screenshot.png)

### Features

- [x] Detects whether Android Studio is already installed.
- [x] Detects whether Android SDK, Java SDK and Flutter SDK are installed.
- [x] Check the latest versions of Android SDK, Java SDK, and Flutter SDK.
- [x] Installing Android SDK, Java SDK, and Flutter SDK.

### Contributing

When contributing to this repository, please first discuss the change you wish to make via issue, email, or any other method with the owners of this repository before making a change.

### How to build

1. Clone or download this [repo](https://github.com/daffaalam/flutter_installer_cli).
2. Install `Dart` from https://dart.dev/get-dart or https://gekorm.com/dart-windows/.
3. Run on project `dart2native bin/flutter_installer_cli.dart`.

### How to test

1. Create new fresh virtual machine (Windows 7, 8, 10) with Virtual Box or everything.
2. Run from CommandPrompt or PowerShell, don't run from double click, so you can see crash message before program is exit.

### TODO

- [ ] low - Language improvement (I'm very bad at English).
- [ ] high - Implementation to Linux and MacOS.
- [ ] low - Pretty and simple code.
- [ ] high - Send error logs automatically for analysis.
- [ ] high - Check whether Visual Studio Code is already installed.
- [ ] high - Check whether flutter plugin is already installed.
- [ ] high - Implementation to the GUI (flutter) version.
- [ ] high - Can choose a custom installation path.
- [ ] high - Can choose the previous flutter version.
- [ ] low - Add a license to this project.

### Other

Batch file (.bat) version [here](https://github.com/daffaalam/flutter-installer).

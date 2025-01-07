# Widget Memories

Widget Memories is a Flutter app designed to choose a random picture from a Google Drive folder based on the current day in previous years, which is then displayed on a home widget. The app ensures a deterministic picture selection based on the current date, enabling multiple users to have synchronized daily pictures without requiring a third-party server.

## Table of Contents

- [Supported Platforms](#platforms)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Maintainers](#maintainers)
- [License](#license)

<a id="platforms"></a>
## Supported Platforms

- Android
- iOS
- Windows
- MacOS support may be added in the future.

## Requirements

- [Flutter SDK](https://docs.flutter.dev/get-started/install), latest release, and its platform-specific requirements:
    - Android: [Android Studio](https://developer.android.com/studio/install)
    - iOS: [Xcode](https://developer.apple.com/xcode/), [CocoaPods](https://cocoapods.org/), Apple Developer Account
    - Windows: [Git for Windows](https://gitforwindows.org/), [Visual Studio 2022](https://visualstudio.microsoft.com/)

## Installation

- Obtain a Google Drive API Key.
- Set the API key in the appropriate variable in `lib/drive.dart`.
- Refer to Flutter's documentation to build the app for your desired platform:
    - [Building for Android](https://docs.flutter.dev/deployment/android)
    - [Building for iOS](https://docs.flutter.dev/deployment/ios)
    - [Building for Windows](https://docs.flutter.dev/deployment/windows)

## Usage

1. Launch the app and paste a Google Drive link for a folder your API key has access to. The folder can contain subfolders: the app recursively traverses them to find all images.
1. Press `Update widget` to configure the home widget.
1. Platform-specific functionality:
    - Android: Press `Set background task` to enable daily automatic updates at midnight.
    - iOS: Update the widget manually in the app each day through `Update widget`.
    - Windows: Press the `View` icon to fill the window with the picture. The latter is updated every time the app launches. The app is not present on the taskbar by design, as it is intended to stay in the background. It can still be focused through the system tray.
- Note: If no pictures were taken on the current day, the app looks back through previous days until it finds one. It thus maintains a blacklist to avoid repeated pictures on consecutive days. Ensure daily updates for guaranteed synchronization across users.

## Maintainers

- Pierugo Pace
    - [GitHub](https://github.com/Pace222)
    - [Email](mailto:pierugo.pace@gmail.com)

## License

[MIT](LICENSE.txt) © Pierugo Pace

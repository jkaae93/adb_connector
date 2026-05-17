# ADB Connector

Android 기기를 무선으로 연결하고 관리하는 macOS 데스크톱 앱입니다. ADB 명령어를 GUI로 쉽게 다룰 수 있게 도와줍니다.

## 주요 기능

- **무선 ADB 연결**: `adb connect`를 GUI에서 버튼 하나로 실행
- **기기 자동 저장**: `adb devices`로 감지된 기기를 자동으로 저장하고 다음에 재사용
- **연결 재시도 로직**: 연결 실패 시 `adb -s {시리얼} tcpip {포트}`를 실행한 뒤 재연결 자동 시도
- **연결 상태 실시간 표시**: 5초마다 자동 갱신, 연결/미연결 뱃지 표시
- **기기 CRUD**: 별명, IP, 포트, 시리얼을 자유롭게 편집/삭제
- **빠른 연결**: 저장 없이 IP를 입력해 일회성 연결
- **ADB 자동 설치**: ADB가 설치되어 있지 않으면 Google 공식 platform-tools를 자동으로 내려받아 설치

## 동작 환경

- macOS (Apple Silicon / Intel)
- Flutter 3.41.0 / Dart 3.11.0 이상
- Android 기기에서 USB 디버깅 활성화 및 무선 디버깅 활성화 필요

## 설치 및 실행

```bash
# 의존성 설치
flutter pub get

# 디버그 실행
flutter run -d macos

# 릴리즈 빌드
flutter build macos
# 빌드 결과: build/macos/Build/Products/Release/ADB Connector.app
```

빌드된 `.app` 번들은 `/Applications` 에 드래그해서 사용할 수 있습니다.

## 사용 방법

### 1. 최초 실행 시 ADB 설치
ADB가 설치되지 않은 환경에서는 상단에 설치 배너가 표시됩니다. **설치** 버튼을 누르면 Google에서 `platform-tools-latest-darwin.zip`을 내려받아 `~/Library/Application Support/adb_connector/platform-tools/`에 자동 설치합니다.

이미 ADB가 설치된 환경 (Android Studio, Homebrew 등)에서는 자동으로 해당 경로를 찾아 사용합니다.

### 2. USB로 기기 최초 연결
1. 안드로이드 기기를 USB로 연결
2. 기기에서 USB 디버깅 허용
3. 앱이 자동으로 기기 정보(IP, 시리얼, 모델명)를 감지하고 저장합니다.

### 3. 무선 연결
저장된 기기의 **연결** 버튼을 누르면:
1. `adb connect {ip}:{port}` 실행
2. 실패 시 `adb -s {시리얼} tcpip {포트}` 후 재시도
3. 그래도 실패하면 "연결 실패 - 기기가 같은 WiFi에 있는지 확인해주세요" 토스트 표시

### 4. 기기 관리
- **수정**: 연필 아이콘으로 별명, IP, 포트, 시리얼, 모델명 수정
- **삭제**: 휴지통 아이콘으로 저장된 기기 제거
- **기기 추가**: 상단의 `+` 버튼으로 수동 추가

### 5. 빠른 연결
하단 "빠른 연결" 섹션에서 IP 주소와 포트를 입력하고 **연결** 버튼을 누르면 저장 없이 한 번만 연결합니다.

## 기술 스택

- **UI**: Flutter Material 3
- **상태 관리**: `StatefulWidget` + `setState`
- **비동기 처리**: `dart:io` `Process.run`으로 ADB 호출
- **저장소**: JSON 파일 (`~/Library/Application Support/adb_connector/saved_devices.json`)
- **외부 의존성 없음**: Dart 표준 라이브러리만 사용

## 프로젝트 구조

```
lib/
  main.dart                    # 앱 진입점, MaterialApp
  models/
    saved_device.dart          # SavedDevice, ConnectedDevice 모델
  services/
    adb_service.dart           # ADB 명령어 실행, 설치, 재시도 로직
    device_storage.dart        # JSON 파일 기반 기기 저장소 (CRUD)
  widgets/
    device_list_tile.dart      # 기기 리스트 타일
    add_device_dialog.dart     # 기기 추가/수정 다이얼로그
  pages/
    home_page.dart             # 메인 화면
```

## 저장 데이터 위치

- **저장된 기기 목록**: `~/Library/Application Support/adb_connector/saved_devices.json`
- **자동 설치된 ADB**: `~/Library/Application Support/adb_connector/platform-tools/`

## 권한 설정

이 앱은 ADB 실행(subprocess 생성)을 위해 macOS 샌드박스를 비활성화했습니다:

- `macos/Runner/DebugProfile.entitlements`: `com.apple.security.app-sandbox = false`
- `macos/Runner/Release.entitlements`: `com.apple.security.app-sandbox = false`

## 문제 해결

**연결이 실패할 때**
- 기기와 Mac이 같은 WiFi 네트워크에 있는지 확인
- 기기의 개발자 옵션에서 "무선 디버깅"이 켜져 있는지 확인
- USB로 다시 연결한 후 앱이 자동으로 IP를 다시 감지하게 하기

**ADB가 감지되지 않을 때**
- 상단 배너의 "설치" 버튼을 눌러 자동 설치
- 또는 `brew install --cask android-platform-tools` 로 직접 설치

## 라이선스

Personal utility. Free to use and modify.

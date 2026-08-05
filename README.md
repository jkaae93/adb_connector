# ADB Connector

Android / iOS 기기를 무선으로 연결하고 관리하는 macOS 데스크톱 앱입니다. `adb connect`, logcat, 파일 전송 같은 명령어를 터미널 없이 GUI 버튼으로 다룰 수 있습니다.

## 다운로드

[ADB Connector v1.0.1 macOS 다운로드](https://github.com/jkaae93/adb_connector/releases/download/v1.0.1/ADB-Connector-v1.0.1-macos.zip)

## 주요 기능

- **무선 ADB 연결**: 저장된 기기를 버튼 하나로 무선 연결 (`adb connect`)
- **USB → 무선 전환**: USB로 연결된 기기를 클릭 한 번으로 무선 디버깅 모드로 전환 (`adb tcpip`)
- **기기 자동 감지·저장**: USB로 꽂기만 하면 IP·시리얼·모델명을 자동 감지해 저장, 다음부터는 무선으로 바로 연결
- **연결 상태 실시간 표시**: 5초마다 자동 갱신, USB/WiFi 연결 상태 뱃지 표시
- **Logcat 뷰어**: 앱 내 실시간 로그 뷰어 제공. 원하면 Terminal, iTerm2, Warp 등 외부 터미널에서도 실행 가능 (전체 / Flutter 전용 / 커스텀 필터 프리셋)
- **파일 브라우저**: 기기 파일 시스템 탐색, 드래그&드롭 업로드, 파일 다운로드 (`adb push`/`pull`)
- **iPhone/iPad 지원**: libimobiledevice 설치 시 iOS 기기 감지 및 syslog 확인
- **빠른 연결**: 저장 없이 IP만 입력해 일회성 연결
- **ADB 자동 설치**: ADB가 없으면 Google 공식 platform-tools를 자동 다운로드·설치

## 시스템 요구사항

- macOS (Apple Silicon / Intel)
- Android 기기: 개발자 옵션에서 **USB 디버깅** 활성화 (무선 연결 시 기기와 Mac이 같은 WiFi에 있어야 함)
- (선택) iOS 기기 지원: `brew install libimobiledevice`

## 설치 방법 (배포된 앱 사용)

1. 배포된 `ADB Connector.app`(또는 zip)을 받아 `/Applications` 폴더로 드래그합니다.
2. 이 앱은 개발자 서명이 없어 처음 실행 시 macOS가 차단할 수 있습니다. 아래 중 한 가지 방법으로 실행하세요.
   - **방법 A**: 앱 아이콘을 **우클릭(Control+클릭) → 열기 → 열기** 버튼 클릭 (최초 1회만)
   - **방법 B**: 터미널에서 격리 속성 제거
     ```bash
     xattr -cr "/Applications/ADB Connector.app"
     ```
   - macOS Sequoia 이상에서 우클릭 열기가 안 되면: **시스템 설정 → 개인정보 보호 및 보안** 하단의 "그래도 열기" 버튼을 사용하세요.
3. 실행 후 상단에 ADB 설치 배너가 보이면 **설치** 버튼을 누르세요. Google 공식 platform-tools를 자동으로 내려받아 설치합니다. (Android Studio나 Homebrew로 이미 ADB가 설치된 경우 자동으로 해당 경로를 사용합니다.)

## 사용 방법

### 1. 기기 최초 등록 (USB)

1. Android 기기를 USB로 Mac에 연결
2. 기기 화면에서 **USB 디버깅 허용** 팝업 승인
3. 앱이 자동으로 기기 정보(IP, 시리얼, 모델명)를 감지하고 목록에 저장합니다.

### 2. USB → 무선 전환

USB로 연결된 기기 항목의 **무선 전환** 버튼을 누르면 `adb tcpip` 실행 후 무선으로 재연결됩니다. 이후 USB 케이블을 뽑아도 연결이 유지됩니다.

### 3. 무선 연결 / 해제

- 저장된 기기의 **연결** 버튼: `adb connect {ip}:{port}` 실행. 실패하면 시리얼 기반으로 `adb tcpip` 재초기화 후 자동 재시도합니다.
- **연결 해제** 버튼: `adb disconnect` 실행

### 4. Logcat 보기

기기 항목의 로그 버튼으로 실행합니다.

- **앱 내 뷰어**: 실시간 로그 스트리밍, 버퍼 클리어 지원
- **터미널에서 열기**: Terminal, iTerm2, Warp, Alacritty, kitty, Ghostty, Hyper 중 설치된 앱 선택
  - **전체**: 필터 없이 전체 로그
  - **Flutter**: `flutter` 태그만 필터링
  - **커스텀**: 출력 포맷, 태그, 버퍼, 정규식 필터, 최대 줄 수 지정
- iOS 기기는 logcat 대신 **syslog**(idevicesyslog)를 표시합니다.

### 5. 파일 브라우저

연결된 기기의 파일 버튼으로 실행합니다.

- 폴더를 클릭해 기기 파일 시스템 탐색
- **업로드**: Mac의 파일을 창으로 드래그&드롭
- **다운로드**: 파일 옆 다운로드 버튼 → 저장할 폴더 선택

### 6. 기기 관리

- **수정**: 연필 아이콘으로 별명, IP, 포트, 시리얼 편집
- **삭제**: 휴지통 아이콘으로 저장 목록에서 제거
- **수동 추가**: 상단 `+` 버튼으로 IP를 직접 입력해 추가

### 7. 빠른 연결

하단 "빠른 연결" 섹션에 IP와 포트(기본 5555)를 입력하고 **연결**을 누르면 저장 없이 일회성으로 연결합니다.

### 8. iPhone/iPad (선택)

```bash
brew install libimobiledevice
```

설치 후 앱을 재실행하면 USB/WiFi로 연결된 iOS 기기가 자동 감지되며, 기기 이름·모델 표시와 syslog 확인을 지원합니다.

## 소스에서 직접 빌드

Flutter 3.41 / Dart 3.11 이상이 필요합니다.

```bash
# 의존성 설치
flutter pub get

# 디버그 실행
flutter run -d macos

# 릴리즈 빌드
flutter build macos --release
# 결과물: build/macos/Build/Products/Release/ADB Connector.app
```

빌드된 `.app`을 zip으로 압축하면 그대로 배포할 수 있습니다.

```bash
cd build/macos/Build/Products/Release
ditto -c -k --keepParent "ADB Connector.app" "ADB-Connector.zip"
```

## 데이터 저장 위치

| 항목 | 경로 |
|---|---|
| 저장된 기기 목록 | `~/Library/Application Support/adb_connector/saved_devices.json` |
| 자동 설치된 ADB | `~/Library/Application Support/adb_connector/platform-tools/` |
| 터미널 앱 선택 설정 | `~/Library/Application Support/adb_connector/terminal_prefs.json` |

## 문제 해결

**앱이 "손상되었기 때문에 열 수 없습니다"라고 나올 때**
- 서명되지 않은 앱이라 발생하는 정상적인 경고입니다. 위 [설치 방법](#설치-방법-배포된-앱-사용)의 `xattr -cr` 명령을 실행하세요.

**무선 연결이 실패할 때**
- 기기와 Mac이 같은 WiFi 네트워크에 있는지 확인
- 기기의 개발자 옵션에서 **무선 디버깅**이 켜져 있는지 확인
- USB로 다시 연결하면 앱이 IP를 재감지합니다

**ADB가 감지되지 않을 때**
- 상단 배너의 **설치** 버튼으로 자동 설치
- 또는 `brew install --cask android-platform-tools`로 직접 설치

**iOS 기기가 보이지 않을 때**
- `brew install libimobiledevice` 설치 여부 확인
- 기기에서 "이 컴퓨터를 신뢰하시겠습니까?" 팝업 승인

## 기술 정보

- Flutter Material 3 기반 macOS 데스크톱 앱
- ADB/libimobiledevice 호출: `dart:io` `Process`
- 파일 드래그&드롭: `desktop_drop`, 저장 위치 선택: `file_picker`
- ADB 실행(subprocess)을 위해 macOS 앱 샌드박스 비활성화 (`macos/Runner/*.entitlements`)

## 라이선스

Personal utility. Free to use and modify.

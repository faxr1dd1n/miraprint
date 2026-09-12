#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Kompyuter yoqilganda/login qilinganda ilova avtomatik ishga tushishi
// uchun, HKEY_CURRENT_USER ostidagi Run kalitiga o'z .exe yo'lini yozib
// qo'yadi (admin huquqi kerak emas; macOS'dagi SMAppService'ga mos keladi).
void RegisterAppForStartup() {
  wchar_t exePath[MAX_PATH];
  if (GetModuleFileNameW(nullptr, exePath, MAX_PATH) == 0) {
    return;
  }

  std::wstring quotedPath = L"\"" + std::wstring(exePath) + L"\"";

  HKEY key;
  LONG result = RegOpenKeyExW(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Run",
      0, KEY_SET_VALUE, &key);
  if (result != ERROR_SUCCESS) {
    return;
  }

  RegSetValueExW(
      key, L"miraprint", 0, REG_SZ,
      reinterpret_cast<const BYTE*>(quotedPath.c_str()),
      static_cast<DWORD>((quotedPath.size() + 1) * sizeof(wchar_t)));

  RegCloseKey(key);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);

  // pos_app'dagi kabi: oyna ekranning ish maydoni (taskbar'siz) o'lchamida,
  // Dart/window_manager ishga tushishidan oldin, to'g'ridan-to'g'ri shu yerda
  // yaratiladi — shu sababli "avval kichik, keyin katta" degan ko'rinish
  // bo'lmaydi.
  RECT workArea;
  SystemParametersInfo(SPI_GETWORKAREA, 0, &workArea, 0);
  int screenWidth = workArea.right - workArea.left;
  int screenHeight = workArea.bottom - workArea.top;

  Win32Window::Point origin(workArea.left, workArea.top);
  Win32Window::Size size(screenWidth, screenHeight);
  if (!window.Create(L"miraprint", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  RegisterAppForStartup();

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
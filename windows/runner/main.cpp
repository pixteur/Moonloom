#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

namespace {

// One copy of Moonloom per device. Two windows would share one SQLite
// database and one audio cache, so the second could silently overwrite the
// first's stories. "Global\" makes the mutex machine-wide, so a second
// launch is blocked even from another Windows account or a fast-user-switched
// session — one story at a time on the family PC.
constexpr const wchar_t kSingleInstanceMutex[] =
    L"Global\\Moonloom.SingleInstance";
constexpr const wchar_t kWindowClassName[] = L"FLUTTER_RUNNER_WIN32_WINDOW";
constexpr const wchar_t kWindowTitle[] = L"Moonloom";

// Hand focus to the copy that's already open, so launching again feels like
// "bring it back" rather than a silent no-op. Returns false when the running
// copy belongs to another Windows account: its window lives in a different
// session, so it can't be found or focused from here.
bool FocusRunningInstance() {
  HWND existing = ::FindWindowW(kWindowClassName, kWindowTitle);
  if (existing == nullptr) {
    return false;
  }
  if (::IsIconic(existing)) {
    ::ShowWindow(existing, SW_RESTORE);
  }
  ::SetForegroundWindow(existing);
  return true;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE single_instance = ::CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
  const DWORD mutex_error = ::GetLastError();
  // Already open in this session, or held by another account (whose mutex we
  // are not allowed to open). Anything else — including failing to create the
  // mutex at all — falls through and starts normally, so a permissions quirk
  // can never lock the family out of the app.
  const bool already_running =
      (single_instance != nullptr && mutex_error == ERROR_ALREADY_EXISTS) ||
      (single_instance == nullptr && mutex_error == ERROR_ACCESS_DENIED);
  if (already_running) {
    if (!FocusRunningInstance()) {
      ::MessageBoxW(nullptr,
                    L"Moonloom is already open in another account on this "
                    L"computer. Close it there first.",
                    L"Moonloom", MB_OK | MB_ICONINFORMATION);
    }
    if (single_instance != nullptr) {
      ::CloseHandle(single_instance);
    }
    return EXIT_SUCCESS;
  }

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
  // Opens at exactly an iPhone's logical canvas — 393 x 852, an iPhone 15 /
  // 16 Pro — so the desktop build is a true preview of the phone layout rather
  // than an approximation of it. Win32Window::Create treats this as the
  // Flutter view's size and adds the title bar and borders on top. The Flutter
  // app still renders a phone frame if the window is dragged larger. See
  // lib/app.dart (PhoneFrame).
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(393, 852);
  if (!window.Create(kWindowTitle, origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance != nullptr) {
    ::ReleaseMutex(single_instance);
    ::CloseHandle(single_instance);
  }
  return EXIT_SUCCESS;
}

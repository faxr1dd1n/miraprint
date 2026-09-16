#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // `receipt_gdi_printer.dart`dan chek chop etish so'rovlarini qabul qiladi
  // (`gdi_receipt_printer.cpp`, GDI+ orqali PDF'siz to'g'ridan-to'g'ri
  // printer drayveriga chizadi — chek matnining xira chiqishining sababi
  // aynan PDF/PDFium bosqichi edi).
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      gdi_print_channel_;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_

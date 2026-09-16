#include "flutter_window.h"

#include <optional>
#include <vector>

#include "flutter/generated_plugin_registrant.h"
#include "gdi_receipt_printer.h"

namespace {

using flutter::EncodableList;
using flutter::EncodableMap;
using flutter::EncodableValue;

std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return L"";
  int len = MultiByteToWideChar(CP_UTF8, 0, str.c_str(),
                                static_cast<int>(str.length()), nullptr, 0);
  std::wstring result(len, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), static_cast<int>(str.length()),
                      &result[0], len);
  return result;
}

void HandlePrintReceipt(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const auto* args = std::get_if<EncodableMap>(call.arguments());
  if (!args) {
    result->Error("BAD_ARGS", "Chek chop etish uchun argumentlar noto'g'ri");
    return;
  }

  auto findStr = [&](const char* key) -> std::string {
    auto it = args->find(EncodableValue(std::string(key)));
    if (it == args->end()) return "";
    if (auto* s = std::get_if<std::string>(&it->second)) return *s;
    return "";
  };
  auto findDouble = [&](const char* key) -> double {
    auto it = args->find(EncodableValue(std::string(key)));
    if (it == args->end()) return 0.0;
    if (auto* d = std::get_if<double>(&it->second)) return *d;
    if (auto* i = std::get_if<int32_t>(&it->second))
      return static_cast<double>(*i);
    if (auto* i = std::get_if<int64_t>(&it->second))
      return static_cast<double>(*i);
    return 0.0;
  };

  std::wstring printerName = Utf8ToWide(findStr("printerName"));
  std::wstring documentName = Utf8ToWide(findStr("documentName"));
  double contentWidthPt = findDouble("contentWidthPt");

  EncodableList blocks;
  auto blocksIt = args->find(EncodableValue(std::string("blocks")));
  if (blocksIt != args->end()) {
    if (auto* list = std::get_if<EncodableList>(&blocksIt->second)) {
      blocks = *list;
    }
  }

  if (printerName.empty()) {
    result->Error("BAD_ARGS", "printerName bo'sh");
    return;
  }

  std::string error;
  bool ok = PrintReceiptBlocks(printerName, documentName, contentWidthPt,
                               blocks, error);
  if (ok) {
    result->Success();
  } else {
    result->Error("PRINT_FAILED", error);
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  gdi_print_channel_ =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          flutter_controller_->engine()->messenger(), "miraprint/gdi_print",
          &flutter::StandardMethodCodec::GetInstance());
  gdi_print_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<EncodableValue>& call,
        std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
        if (call.method_name() == "printReceipt") {
          HandlePrintReceipt(call, std::move(result));
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

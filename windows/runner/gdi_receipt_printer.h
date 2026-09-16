#ifndef RUNNER_GDI_RECEIPT_PRINTER_H_
#define RUNNER_GDI_RECEIPT_PRINTER_H_

#include <flutter/encodable_value.h>

#include <string>

// Windows uchun: chekni C#dagi (`MainForm.cs`) `PrintDocument`/GDI+ yo'liga
// aynan mos ravishda, printer DC'ga to'g'ridan-to'g'ri GDI+ chizish
// buyruqlari (`DrawString`/`DrawLine`/`FillRectangle`/`DrawImage`) orqali
// chop etadi — PDF/PDFium (avvalgi yo'l) butunlay chetlab o'tiladi, chunki
// aynan PDFium'ning oldindan anti-aliased matn rasterlashi (keyin drayver
// tomonidan qayta dithering qilinishi) xiralikning sababi edi.
//
// Joylashuv/uslub qoidalarining o'zi (shrift o'lchamlari, bo'shliqlar,
// compact rejim va h.k.) bu yerda emas, Dart tomonida
// (`receipt_gdi_blocks.dart`) qoladi — bu funksiya faqat tayyor "blok"
// ro'yxatini (matn/chiziq/rasm/barcode) yuqoridan pastga chizadi.
bool PrintReceiptBlocks(const std::wstring& printer_name,
                        const std::wstring& document_name,
                        double content_width_pt,
                        const flutter::EncodableList& blocks,
                        std::string& error_out);

#endif  // RUNNER_GDI_RECEIPT_PRINTER_H_

# Abla Printers

Typed receipt jobs for ESC/POS and Epson ePOS-Print XML, written in Abla.
The package uses plain profiles and explicit results. No printer is discovered
or contacted by an encoder, and no failed print job is retried automatically.

```abla
import github("AndreBaltazar8/abla-printers")
import "abla/io"

fun sendPreparedReceipt(job: PrinterJob, address: string): PrinterSendResult {
    val transport = TcpPrinterTransport(TcpPrinterConfig(address))
    printerSendEscPos(job, transport, printer58mm(), 5000)
}

fun main: int {
    val job = printerJob()
        .text("Loja exemplo", align="center", bold=true)
        .text("Total: 12,30 €")
        .text("ATCUD: TEST-1")
        .qr("SYNTHETIC TEST PAYLOAD")
        .feed(3)
        .cut()
    val encoded = encodeEscPos(job, printer58mm())
    if (!encoded.succeeded) {
        eprintln(encoded.error.message)
        return 1
    }
    // This example encodes only; it does not contact a printer.
    println("Encoded ${encoded.bytes.size} bytes")
    0
}
```

The example is synthetic. Supply the application's already validated fiscal QR
payload when printing an AT QR code; the library does not build fiscal fields.
ATCUD text and the QR payload are separate inputs.

## Jobs and profiles

Jobs are persistent immutable lists: adding an operation returns a new job,
without changing an older one or exposing a mutable operation array.

- `text(value, align="left", bold=false, doubleWidth=false, doubleHeight=false)`
- `feed(lines=1)`
- `qr(value, moduleSize=4, level="M", align="center")`
- `cut()` — feed to the cutter and perform a partial cut
- `drawer(pin=2, onMilliseconds=100, offMilliseconds=0)` — only when requested

`printer58mm()` selects 32 font-A columns; `printer80mm()` selects 48. These are
starting profiles, not model detection. Set `EscPosProfile(width=..., codepage=...,
supportsCut=..., supportsDrawer=..., maximumBytes=...)` for the actual device.
Text wraps by encoded character cells and double-width text halves the columns.
The library does not change a printer's physical paper-width setting.

Text encoding is explicit: `pc858` selects Epson page 19, with Portuguese
characters and the Euro sign; `ascii` accepts printable ASCII. Invalid UTF-8,
unrepresentable glyphs, ESC, NUL, tab, CR and other control characters are rejected.
LF is accepted. There are no raw-command operations hidden inside text.

QR uses Model 2, correction L/M/Q/H, and `GS ( k` setup/store/print commands.
Payloads are bounded to 1,273 UTF-8 bytes. Choose a module size and payload that
fit the device's printable area; byte-level tests do not establish scan quality.

Jobs have at most 1,024 operations. A text operation is at most 65,536 UTF-8 bytes;
the encoded result is bounded to at most 1 MiB by the profile. Invalid jobs return
no partial output. Widths, capabilities, feed counts and pulse timing are checked
before any transport call.

## Results and transport semantics

`PrinterEncodeResult` contains `succeeded`, `bytes` and a `PrinterError(code,message)`.
`PrinterSendResult` adds `outcome` and `bytesWritten`:

| Outcome | Meaning |
| --- | --- |
| `notSent` | No bytes were submitted by this call. |
| `submitted` | All bytes were accepted by the local transport. Paper output is unconfirmed. |
| `unknown` | Some bytes were submitted before an error or timeout. Repeating the job may duplicate effects. |

Implement `PrinterTransport.send(contents, timeoutMilliseconds)` to add a
transport. `printerSendEscPos` fully validates the job before calling it once.
It preserves the transport's outcome and does not retry. One job should have
exclusive access to a printer; applications coordinate their own durable queue.

The built-in `TcpPrinterTransport` uses numeric IPv4 and port 9100 by default,
with bounded nonblocking connect/write and one monotonic deadline. It performs
no DNS, printer discovery or automatic replay. Raw TCP is unencrypted; configure
an appropriate printer network. TCP payloads default to at most 1 MiB and can be
configured up to 8 MiB. This transport currently targets hosted Linux.

USB and serial use the explicitly imported `native` submodule:

```abla
import github("AndreBaltazar8/abla-printers/native")
import "abla/serial"

val usb = usbPrinter("/dev/usb/lp0")
val serial = SerialPrinterTransport(
    "/dev/ttyUSB0", SerialSettings(baud=19200)
)
```

The core entry remains compatible with 0.2.45. The native submodule requires
the released `abla/device` and `abla/serial` standard-library APIs in0.2.47.
The separate native workflow runs on Linux and macOS with that release;
earlier Linux-only verification used the upstream frozen API snapshot.
It is not part of the 0.2.45 core CI result.

Linux USB printers use the kernel usblp character node. Serial settings are host
settings and must match the printer. Raw mode and eight data bits are required;
invalid settings fail before opening the device. The native writer waits for
final readiness before closing: a timeout can report every byte written while
the outcome is still `unknown`. Neither that readiness nor `/dev/null` fixture
acceptance establishes paper output. No subprocess transport is used.

The native timeout bounds the write/readiness phase, not the entire `send()`
call. Its deadline is computed before opening/configuring the device, but native
open, configuration and driver close time are not deadline-bounded. In
particular, tty close can wait on the driver after the write has finished. The
library does not flush accepted bytes or change administrative port settings to
hide that delay; applications should schedule native I/O accordingly.

## Epson ePOS-Print XML

`eposPrintXml(job, profile)` returns the print document. `eposSoapEnvelope(job,
profile)` wraps it for the SOAP/HTTP interface. Transport remains explicit; the
library does not send XML to a raw ESC/POS socket. A caller posts the SOAP body
to the printer's configured ePOS endpoint with `text/xml; charset=utf-8`.

XML text and attributes are escaped. QR backslashes are additionally escaped for
ePOS's symbol escape processing, so a literal `\x1b` does not inject a control
byte. The same strict text/codepage and wrapping policy applies to both encoders.
ePOS QR widths are 3..8 in this API; ESC/POS additionally permits 1..2. ePOS drawer
pulses use its 100/200/300/400/500 ms presets and require the default off-time
(`offMilliseconds=0`), because the XML protocol has no off-time field. ESC/POS can
specify an explicit even off-time. Unsupported settings fail explicitly.

## Verification

CI is pinned to released ablac 0.2.45. Run `make test COMPILER=ablac` in the
compiler's toolchain environment. Tests use independent ESC/POS and XML goldens,
Portuguese/codepage vectors, wrapping, input rejection, immutable jobs and an
actual loopback fake printer on TCP 9100, checking code page, cut and drawer
commands and rejecting an omitted expected command. A large stalled submission checks that
a partial write times out with its byte count and an unknown outcome. A busy
9100 test port fails rather than connecting to another service. A SOAP/HTTP ePOS
stand-in accepts an independent golden document and rejects malformed XML or
wrong headers; generated XML also goes through an independent XML parser.
The stand-in is a bounded test fixture, not a firmware or fiscal validator.

No hardware was bought or used. Character-device and PTY fixtures cover native
submission without a printer. Cutter, drawer, model compatibility, QR scan
quality and paper-output acceptance are deferred until a later hardware purchase.

## References

- [Epson ESC/POS QR store](https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/gs_lparen_lk_fn180.html) and [print](https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/gs_lparen_lk_fn181.html).
- [Epson drawer pulse command](https://download4.epson.biz/sec_pubs/pos/reference_en/escpos/esc_lp.html).
- [Epson character-page support by model](https://download4.epson.biz/sec_pubs/pos/reference_en/charcode/supported_codepage.html).
- [Epson ePOS-Print XML manual](https://files.support.epson.com/pdf/pos/bulk/epos-print_xml_um_en_rev_af.pdf), text/symbol/feed/cut/pulse and SOAP sections.
- [DENSO WAVE QR versions and capacity](https://www.qrcode.com/en/about/version.html).

MIT license. ESC/POS and Epson are trademarks of Seiko Epson Corporation.

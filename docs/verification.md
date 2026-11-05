# Verification and supported scope

The initial library was tested without purchasing or using POS hardware
(owner decision 24, 2026-11-05). These are simulator and software-interface
results; they do not establish paper output or physical actuator operation.

| Surface | Verified |
| --- | --- |
| ESC/POS, released ablac 0.2.45 | 45 independent golden/control checks, including Portuguese/Euro encoding, wrapping, QR setup/store/print, cut and drawer pulses |
| Submission outcomes, 0.2.45 | Six cases, including a final-readiness timeout after all bytes were written remaining unknown |
| Raw TCP 9100, 0.2.45 | Real loopback byte sink; independently checks code page/cut/drawer, rejects an omitted expected drawer command, checks partial timeout and connection/configuration refusals |
| ePOS SOAP/HTTP, 0.2.45 | Local endpoint accepts an independent complete XML golden and refuses malformed XML or wrong headers; examples also parsed independently with xmllint |
| Native character-device adapter | Accepted bytes at `/dev/null`; missing/invalid paths and non-tty serial use refuse before sending |
| Serial adapter | POSIX PTY reads back the exact receipt bytes at 19200/raw eight-bit settings, including LF without CR conversion, CP858, QR, cut and drawer |

The native checks used the compiler team's frozen Linux API-507 sysroot,
not a released 0.2.45 standard library. Its `abla/device` source hash was
`4116f9dac858219114a02de5da045d490d0f0a2ac6a1420d4805be52d92fdeb1`;
`abla/serial` was
`1bb71740d5711d249ea192742d466900a9493b5b47c053835e564867df0263ae`.
Inputs were checked before and after the run. These APIs are targeted for
0.2.47. The explicit `native` package subpath keeps them outside the 0.2.45
core import graph. Native release CI is prepared as a separate manual workflow;
it has not run against an available 0.2.47 release yet. Mac adapter verification
and released-native CI remain pending.

The core simulator run used source `d9afcb2`; the final native run used
`f77e8a1`, whose native change is the PTY fixture's defining-module import.
Documentation and workflow updates after those tests do not change library code.
Raw logs and source/toolchain hashes are retained locally under
`build/validation/`. Public CI and package-import results are recorded separately
when available.

The local HTTP stand-in implements one bounded golden fixture, not Epson
firmware, complete XML-schema validation, printer status, or fiscal validation.
Real cutter/drawer behavior, model compatibility, QR scan quality, and paper
output wait for a later hardware purchase. No device discovery or hardware
configuration was performed.

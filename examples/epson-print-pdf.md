# Print a receipt PDF on the Epson TM-T20IV

Build the Linux sender from the repository root with Abla 0.2.67 or newer.

```sh
ablac build examples/epson_raster_print.ab -o build/epson-raster-print --fast
```

The PDF wrapper needs Ghostscript and ImageMagick 7. Run a dry run to see the
raster dimensions and length in millimetres. The reported length covers the
raster. The printer adds the feed to the cutter.

```sh
examples/epson-print-pdf.sh --dry-run /path/to/receipt.pdf
examples/epson-print-pdf.sh --device /dev/usb/lp0 /path/to/receipt.pdf
```

The wrapper renders page 1 at 203 dpi and thresholds it to 1-bit with no
dithering. It crops the side margins of a nominal 80 mm page to the 576-dot
printhead width without scaling. It refuses the page if the crop would discard
any black pixels. The sender submits one job with up to 256 rows per band
and one feed-and-partial-cut command. USB completion reports submission.
Check the paper to confirm printing.

The standalone sender also accepts a 576-dot-wide binary PBM (P4), with either
`--device /dev/usb/lp0` or `--tcp IPv4` on port 9100.

The simulator test additionally needs `qrencode` and `zbarimg`. It binds its own
TCP listener on loopback port 9100.

```sh
tests/epson-print-pdf-test.sh
```

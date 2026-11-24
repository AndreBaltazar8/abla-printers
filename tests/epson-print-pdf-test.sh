#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
temp_dir=$(mktemp -d)
sim_pid=
trap 'if [[ -n $sim_pid ]]; then kill "$sim_pid" 2>/dev/null || true; fi; rm -rf -- "$temp_dir"' EXIT

compiler=${COMPILER:-ablac}
"$compiler" build examples/epson_raster_print.ab -o "$temp_dir/epson-raster-print" --fast --no-cache
"$compiler" build tests/epson_raster_test.ab -o "$temp_dir/simulator" --fast --no-cache
export EPSON_RASTER_PRINT="$temp_dir/epson-raster-print"

start_sim() {
    local mode=$1
    : > "$temp_dir/simulator.log"
    timeout 15 "$temp_dir/simulator" "$mode" "$temp_dir/received.pbm" > "$temp_dir/simulator.log" &
    sim_pid=$!
    for ((attempt = 0; attempt < 100; attempt++)); do
        if grep -qx READY "$temp_dir/simulator.log"; then return; fi
        kill -0 "$sim_pid" 2>/dev/null || break
        sleep 0.02
    done
    printf 'Loopback simulator did not bind TCP 9100\n' >&2
    exit 1
}

finish_sim() {
    wait "$sim_pid"
    sim_pid=
    sed '/^READY$/d' "$temp_dir/simulator.log"
}

# Include whitespace at the start of the raster, arbitrary zero / FF bytes,
# and ESC p bytes inside a raster band. The wire must match the fixed golden.
{
    printf 'P4\n576 257\n'
    for ((row = 0; row < 256; row++)); do
        printf ' \033p\0X\377%066d' 0
    done
    printf '\n'
    for ((i = 0; i < 71; i++)); do printf '\377'; done
} > "$temp_dir/golden.pbm"
start_sim golden
"$EPSON_RASTER_PRINT" --tcp 127.0.0.1 "$temp_dir/golden.pbm"
finish_sim
cmp "$temp_dir/golden.pbm" "$temp_dir/received.pbm"
printf 'PASS reconstructing the golden PBM byte for byte\n'

payload='A:000000001*B:000000002*C:PT*D:FS*E:N*F:20000101*G:FS TESTE/1*H:TESTE000-1*I1:PT*I7:10.00*I8:2.30*N:2.30*O:12.30*Q:TEST*R:0'
qrencode -t EPS -l M -v 9 -m 4 -s 1 -o "$temp_dir/qr.eps" "$payload"
{
    cat <<'POSTSCRIPT'
%!PS
<< /PageSize [226.771654 396.850394] >> setpagedevice
/Helvetica findfont 8 scalefont setfont
26 370 moveto (TESTE - SEM VALOR FISCAL) show
26 353 moveto (1 Artigo - IVA 23%         Total EUR 12,30) show
11.338583 335 204.094488 0.6 rectfill
26 315 moveto (ATCUD:TESTE000-1) show
gsave
64.6 209 translate
1.6 1.6 scale
POSTSCRIPT
    cat "$temp_dir/qr.eps"
    cat <<'POSTSCRIPT'
grestore
showpage
% The wrapper must never send this second page. Its left edge would fail.
0 200 5 5 rectfill
showpage
POSTSCRIPT
} > "$temp_dir/synthetic.ps"
gs -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pdfwrite \
    -sOutputFile="$temp_dir/synthetic.pdf" -f "$temp_dir/synthetic.ps"

dry_run=$(EPSON_RASTER_PRINT=/nonexistent examples/epson-print-pdf.sh --dry-run "$temp_dir/synthetic.pdf")
[[ $dry_run == "576 x 1119 dots at 203 dpi, 140.01 mm long" ]]
printf 'PASS page 1 dry run: %s\n' "$dry_run"
start_sim capture
examples/epson-print-pdf.sh --tcp 127.0.0.1 "$temp_dir/synthetic.pdf"
finish_sim
[[ $(magick identify -format '%w %h' "$temp_dir/received.pbm") == "576 1119" ]]
magick "$temp_dir/received.pbm" "$temp_dir/received.png"
[[ $(zbarimg --quiet --raw "$temp_dir/received.png") == "$payload" ]]
printf 'PASS decoded the exact synthetic fiscal QR from the TCP capture\n'

for case in narrow clipped; do
    page_size=226.771654
    if [[ $case == narrow ]]; then page_size=200; fi
    printf '%%!PS\n<< /PageSize [%s 100] >> setpagedevice\n0 20 5 5 rectfill\nshowpage\n' "$page_size" > "$temp_dir/$case.ps"
    gs -q -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pdfwrite \
        -sOutputFile="$temp_dir/$case.pdf" -f "$temp_dir/$case.ps"
    if examples/epson-print-pdf.sh --dry-run "$temp_dir/$case.pdf" > "$temp_dir/$case.out" 2> "$temp_dir/$case.err"; then
        printf 'Unexpectedly accepted %s fixture\n' "$case" >&2
        exit 1
    fi
    [[ ! -s "$temp_dir/$case.out" ]]
done
grep -q 'Unexpected PDF width' "$temp_dir/narrow.err"
grep -q 'artwork extends beyond' "$temp_dir/clipped.err"
printf 'PASS refused unexpected page width and clipped artwork\n'

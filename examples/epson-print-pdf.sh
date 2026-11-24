#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

die() { printf '%s\n' "$*" >&2; exit 2; }
usage() { die "Usage: $0 (--dry-run | --device /dev/usb/lp0 | --tcp IPv4) page.pdf"; }

mode=${1-}
case "$mode" in
    --dry-run) [[ $# -eq 2 ]] || usage ;;
    --device|--tcp) [[ $# -eq 3 ]] || usage; target=$2 ;;
    *) usage ;;
esac
pdf=${!#}
[[ -f $pdf ]] || die "PDF does not exist: $pdf"
[[ $pdf = /* ]] || pdf=$PWD/$pdf

temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
width_dots=576
dpi=203

gs -q -dSAFER -dBATCH -dNOPAUSE -dPDFSTOPONERROR -dFirstPage=1 -dLastPage=1 \
    -dAutoRotatePages=/None -dTextAlphaBits=4 -dGraphicsAlphaBits=4 -dInterpolateControl=0 \
    -sDEVICE=pnggray -r"$dpi" -sOutputFile="$temp_dir/page.png" -f "$pdf" >&2

# Threshold a grayscale render at the original pixel grid, with no dithering.
magick "$temp_dir/page.png" +dither -threshold 50% "$temp_dir/mono.png"
read -r source_width height < <(magick identify -format '%w %h\n' "$temp_dir/mono.png")

margin_is_white() {
    local edge=$1
    [[ $(magick "$temp_dir/mono.png" -crop "$edge" +repage -format '%[fx:minima]' info:) == 1 ]]
}

crop_fits() {
    local left=$1 right=$(( $1 + width_dots ))
    margin_is_white "${left}x${height}+0+0" &&
        margin_is_white "$((source_width - right))x${height}+${right}+0"
}

case "$source_width" in
    576) mono="$temp_dir/mono.png" ;;
    639|640)
        # An 80 mm PDF is wider than the 72 mm printhead. Crop only white
        # margins, with no resampling, and refuse if a printed dot would be lost.
        excess=$(( source_width - width_dots ))
        left=$(( (excess + 1) / 2 ))
        if ! crop_fits "$left"; then
            # Odd widths have two equally centered crops at pixel precision.
            left=$(( excess / 2 ))
            if (( excess % 2 == 0 )) || ! crop_fits "$left"; then
                die "Page artwork extends beyond the 576-dot printable width."
            fi
        fi
        mono="$temp_dir/printable.png"
        magick "$temp_dir/mono.png" -crop "${width_dots}x${height}+${left}+0" +repage "$mono"
        ;;
    *) die "Unexpected PDF width at ${dpi} dpi: ${source_width} dots (expected 576 or nominal 80 mm)." ;;
esac

pbm="$temp_dir/page.pbm"
magick "$mono" "PBM:$pbm"
read -r width actual_height < <(magick identify -format '%w %h\n' "$pbm")
[[ $width == "$width_dots" && $actual_height == "$height" ]] ||
    die "Raster must be 576 dots wide and retain its original height."

awk -v w="$width" -v h="$height" -v dpi="$dpi" \
    'BEGIN { printf "%d x %d dots at %d dpi, %.2f mm long\n", w, h, dpi, h * 25.4 / dpi }'
if [[ $mode == --dry-run ]]; then
    exit 0
fi

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
printer=${EPSON_RASTER_PRINT:-"$here/../build/epson-raster-print"}
[[ -x $printer ]] || die "Build examples/epson_raster_print.ab first or set EPSON_RASTER_PRINT."
"$printer" "$mode" "$target" "$pbm"

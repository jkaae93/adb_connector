#!/usr/bin/env python3
"""SVG app icon을 macOS용 PNG 아이콘셋으로 변환."""

import cairosvg
import os

SVG_PATH = os.path.join(os.path.dirname(__file__), '..', 'assets', 'app_icon.svg')
OUTPUT_DIR = os.path.join(
    os.path.dirname(__file__), '..',
    'macos', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset',
)

SIZES = [16, 32, 64, 128, 256, 512, 1024]

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    for size in SIZES:
        output_path = os.path.join(OUTPUT_DIR, f'app_icon_{size}.png')
        cairosvg.svg2png(
            url=os.path.abspath(SVG_PATH),
            write_to=output_path,
            output_width=size,
            output_height=size,
        )
        print(f'  {size}x{size} -> {output_path}')

    print('Done.')

if __name__ == '__main__':
    main()

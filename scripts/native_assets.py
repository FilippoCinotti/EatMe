"""Generate native icon rasters from the approved EatMe+ app-icon master.

The original flat two-leaf SVG and native splash vectors are intentionally not
rewritten: they remain the clearer source for small launch treatments.
"""
import json
from pathlib import Path

from PIL import Image


IOS_SLOTS = [
    ('iphone', 20, 2), ('iphone', 20, 3), ('iphone', 29, 2),
    ('iphone', 29, 3), ('iphone', 40, 2), ('iphone', 40, 3),
    ('iphone', 60, 2), ('iphone', 60, 3), ('ipad', 20, 1),
    ('ipad', 20, 2), ('ipad', 29, 1), ('ipad', 29, 2),
    ('ipad', 40, 1), ('ipad', 40, 2), ('ipad', 76, 1),
    ('ipad', 76, 2), ('ipad', 83.5, 2), ('ios-marketing', 1024, 1),
]


def save_rgb(source, destination, size):
    image = source.resize((size, size), Image.Resampling.LANCZOS).convert('RGB')
    image.save(destination, 'PNG', optimize=True)


def generate(mobile):
    source_path = mobile / 'assets/brand/eatme-plus-app-icon.png'
    with Image.open(source_path) as source:
        if source.size != (1024, 1024):
            raise SystemExit('The approved app-icon master must be exactly 1024x1024.')
        for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
            folder = mobile / 'android/app/src/main/res' / ('mipmap-' + density)
            folder.mkdir(parents=True, exist_ok=True)
            save_rgb(source, folder / 'ic_launcher.png', size)
            save_rgb(source, folder / 'ic_launcher_round.png', size)
        foreground = mobile / 'android/app/src/main/res/drawable-nodpi'
        foreground.mkdir(parents=True, exist_ok=True)
        save_rgb(source, foreground / 'ic_launcher_foreground.png', 432)

        asset = mobile / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
        asset.mkdir(parents=True, exist_ok=True)
        images = []
        for idiom, points, scale in IOS_SLOTS:
            filename = f'Icon-{points}-{scale}.png'
            save_rgb(source, asset / filename, int(points * scale))
            images.append({'filename': filename, 'idiom': idiom, 'size': f'{points}x{points}', 'scale': f'{scale}x'})
        (asset / 'Contents.json').write_text(
            json.dumps({'images': images, 'info': {'version': 1, 'author': 'EatMe+'}}, indent=2) + '\n'
        )


if __name__ == '__main__':
    generate(Path(__file__).resolve().parents[1] / 'apps/mobile')

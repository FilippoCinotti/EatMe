"""Generate original EatMe native icons using deterministic vector-like geometry."""
import math
import struct
import zlib
from pathlib import Path


def icon_png(size):
    pixels = bytearray()
    for y in range(size):
        pixels.append(0)
        for x in range(size):
            a, b = x / size, y / size
            background = (238, 243, 228)
            # A rounded plate and an E-shaped sprig, drawn in normalized coordinates.
            plate = math.hypot(a - .5, b - .5) < .36
            stem = .34 < a < .41 and .29 < b < .72
            leaf = ((a - .51) / .17) ** 2 + ((b - .32) / .055) ** 2 < 1
            middle = ((a - .49) / .15) ** 2 + ((b - .50) / .05) ** 2 < 1
            lower = ((a - .51) / .17) ** 2 + ((b - .68) / .055) ** 2 < 1
            color = (49, 80, 61) if stem or leaf or middle or lower else (249, 249, 240) if plate else background
            pixels.extend(color)
    def chunk(name, data):
        return struct.pack('>I', len(data)) + name + data + struct.pack('>I', zlib.crc32(name + data) & 0xffffffff)
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>2I5B', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(bytes(pixels))) + chunk(b'IEND', b'')


def generate(mobile):
    import json
    for density, size in {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}.items():
        folder = mobile / 'android/app/src/main/res' / ('mipmap-' + density)
        folder.mkdir(parents=True, exist_ok=True)
        (folder / 'ic_launcher.png').write_bytes(icon_png(size))
    asset = mobile / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    asset.mkdir(parents=True, exist_ok=True)
    images = []
    for idiom, points, scale in [('iphone', 20, 2), ('iphone', 20, 3), ('iphone', 29, 2), ('iphone', 29, 3), ('iphone', 40, 2), ('iphone', 40, 3), ('iphone', 60, 2), ('iphone', 60, 3), ('ipad', 20, 1), ('ipad', 20, 2), ('ipad', 29, 1), ('ipad', 29, 2), ('ipad', 40, 1), ('ipad', 40, 2), ('ipad', 76, 1), ('ipad', 76, 2), ('ipad', 83.5, 2), ('ios-marketing', 1024, 1)]:
        filename = f'Icon-{points}-{scale}.png'
        (asset / filename).write_bytes(icon_png(int(points * scale)))
        images.append({'filename': filename, 'idiom': idiom, 'size': f'{points}x{points}', 'scale': f'{scale}x'})
    (asset / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'version': 1, 'author': 'EatMe'}}, indent=2) + '\n')


if __name__ == '__main__':
    generate(Path(__file__).resolve().parents[1] / 'apps/mobile')

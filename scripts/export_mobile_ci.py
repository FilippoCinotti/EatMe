"""Export generated native sources and resolved lockfiles for reproducible commits."""
import zipfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
mobile = root / 'apps/mobile'
excluded = {'.gradle', 'build', 'Pods', '.symlinks', 'ephemeral', '.dart_tool'}
forbidden = {'local.properties', 'Generated.xcconfig', 'flutter_export_environment.sh', 'GeneratedPluginRegistrant.java', 'GeneratedPluginRegistrant.h', 'GeneratedPluginRegistrant.m'}
with zipfile.ZipFile(root / 'mobile-sources.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for folder in ('lib', 'test', 'android', 'ios'):
        for path in (mobile / folder).rglob('*'):
            if path.is_file() and not excluded.intersection(path.parts) and path.name not in forbidden and not path.is_symlink():
                archive.write(path, path.relative_to(root))
    for filename in ('pubspec.lock', '.metadata'):
        path = mobile / filename
        if path.exists():
            archive.write(path, path.relative_to(root))

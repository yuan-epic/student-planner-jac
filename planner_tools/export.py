"""Create a clean coursework repository without the pre-existing robotics files.
Usage: python3 planner_tools/export.py /tmp/student-planner-submission
Only explicit source files are copied; an existing target is refused.
"""
from pathlib import Path
import shutil
import sys

root = Path(__file__).resolve().parent.parent
target = Path(sys.argv[1]).resolve() if len(sys.argv) == 2 else None
if target is None or target.exists():
    raise SystemExit('Pass a NEW destination directory: python3 planner_tools/export.py /tmp/student-planner-submission')
target.mkdir(parents=True)
for name in ['jac.toml', 'README.md', '.gitignore']:
    shutil.copy2(root / name, target / name)
for folder in ['core', 'web', 'mobile', 'cli', 'planner_tests', 'planner_tools', 'planner_docs']:
    for src in (root / folder).rglob('*'):
        if not src.is_file() or '__pycache__' in src.parts:
            continue
        if src.name == 'README.original-robotics.md':
            continue
        if src.suffix not in ['.jac', '.css', '.py', '.md', '.txt', '.json', '.lock']:
            continue
        dest = target / src.relative_to(root)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dest)
print(target)

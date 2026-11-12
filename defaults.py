#!/usr/bin/env python3
"""Small argv-only adapter to Omarchy's default-app commands."""
import json
import shutil
import subprocess
import sys

APPS = {
    'browser': [('chromium', 'Chromium', 'chromium'), ('chrome', 'Chrome', 'google-chrome-stable'), ('brave', 'Brave', 'brave'), ('brave-origin', 'Brave Origin', 'brave-origin'), ('edge', 'Edge', 'microsoft-edge-stable'), ('firefox', 'Firefox', 'firefox'), ('zen', 'Zen', 'zen-browser')],
    'editor': [('code', 'VS Code', 'code'), ('cursor', 'Cursor', 'cursor'), ('zed', 'Zed', 'zeditor'), ('sublime_text', 'Sublime Text', 'sublime_text'), ('helix', 'Helix', 'hx'), ('vim', 'Vim', 'vim'), ('emacs', 'Emacs', 'emacs'), ('nvim', 'Neovim', 'nvim')],
    'terminal': [(x, x.title(), x) for x in ('alacritty', 'foot', 'ghostty', 'kitty')],
}

def run(*args):
    return subprocess.run(['omarchy', 'default', *args], check=True, capture_output=True, text=True, timeout=15).stdout.strip()

def available(row):
    return bool(shutil.which(row[2]))

def main(args):
    if args:
        if len(args) != 2 or args[0] not in APPS:
            raise ValueError('Expected a category and application')
        category, app = args
        if not any(row[0] == app and available(row) for row in APPS[category]):
            raise ValueError('Application is unsupported or not installed')
        run(category, app)
    result = []
    for category, apps in APPS.items():
        current = run(category)
        if category == 'editor' and current == 'zeditor':
            current = 'zed'
        result.append(dict(category=category, current=current,
                           apps=[dict(value=r[0], label=r[1]) for r in apps if available(r)]))
    print(json.dumps(result))

if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(getattr(error, 'stderr', None) or str(error), file=sys.stderr)
        sys.exit(1)

#!/usr/bin/env python3
"""Small argv-only adapter to Omarchy's default-app commands."""
import configparser
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

APPS = {
    'browser': [('chromium', 'Chromium', 'chromium'), ('chrome', 'Chrome', 'google-chrome-stable'), ('brave', 'Brave', 'brave'), ('brave-origin', 'Brave Origin', 'brave-origin'), ('edge', 'Edge', 'microsoft-edge-stable'), ('firefox', 'Firefox', 'firefox'), ('zen', 'Zen', 'zen-browser')],
    'editor': [('code', 'VS Code', 'code'), ('cursor', 'Cursor', 'cursor'), ('zed', 'Zed', 'zeditor'), ('sublime_text', 'Sublime Text', 'sublime_text'), ('helix', 'Helix', 'hx'), ('vim', 'Vim', 'vim'), ('emacs', 'Emacs', 'emacs'), ('nvim', 'Neovim', 'nvim')],
    'terminal': [(x, x.title(), x) for x in ('alacritty', 'foot', 'ghostty', 'kitty')],
    'agent': [(value, label, value) for value, label in (
        ('pi', 'Pi'), ('omp', 'Oh My Pi'), ('opencode', 'OpenCode'),
        ('claude', 'Claude Code'), ('codex', 'Codex'), ('grok', 'Grok'),
        ('gemini', 'Gemini'), ('openclaw', 'OpenClaw'), ('hermes', 'Hermes'),
        ('copilot', 'GitHub Copilot'), ('crush', 'Crush'),
        ('cursor-agent', 'Cursor CLI'), ('muse', 'Muse Code'))],
}

def run(*args):
    return subprocess.run(['omarchy', 'default', *args], check=True, capture_output=True, text=True, timeout=15).stdout.strip()

def available(row):
    return bool(shutil.which(row[2]))

def set_agent(app):
    # Match omarchy-default-agent's path. Its setter installs and launches;
    # this panel only changes the saved preference.
    target = Path.home() / '.config/omarchy/defaults/agent'
    target.parent.mkdir(parents=True, exist_ok=True)
    name = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', dir=target.parent, delete=False) as out:
            name = out.name
            out.write(app + '\n')
        os.replace(name, target)
    finally:
        if name and os.path.exists(name):
            os.unlink(name)

def file_managers():
    """Discover directory handlers, honoring XDG desktop-file overrides."""
    roots = [Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))]
    roots += [Path(x) for x in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if x]
    seen, result = set(), []
    for root in roots:
        folder = root / 'applications'
        for path in sorted(folder.rglob('*.desktop')) if folder.is_dir() else []:
            desktop_id = str(path.relative_to(folder)).replace('/', '-')
            if desktop_id in seen:
                continue
            seen.add(desktop_id)
            config = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                config.read(path, encoding='utf-8')
                entry = config['Desktop Entry']
                if entry.get('Type') != 'Application' or entry.get('Hidden', '').lower() == 'true':
                    continue
                if 'inode/directory' not in entry.get('MimeType', '').split(';'):
                    continue
                if not entry.get('Exec') or (entry.get('TryExec') and not shutil.which(entry['TryExec'])):
                    continue
                result.append(dict(value=desktop_id, label=entry.get('Name', desktop_id)))
            except (OSError, UnicodeError, configparser.Error, KeyError):
                continue
    return sorted(result, key=lambda row: (row['label'].casefold(), row['value']))


def directory_default(app=None):
    command = ['xdg-mime', 'default', app, 'inode/directory'] if app else ['xdg-mime', 'query', 'default', 'inode/directory']
    result = subprocess.run(command, check=True, capture_output=True, text=True, timeout=15).stdout.strip()
    if app and directory_default() != app:
        raise ValueError('The desktop did not accept the selected folder default')
    return result


def main(args):
    if args:
        if len(args) != 2 or args[0] not in (*APPS, 'file manager'):
            raise ValueError('Expected a category and application')
        category, app = args
        if category == 'file manager':
            if app not in [row['value'] for row in file_managers()]:
                raise ValueError('Application is not an available directory handler')
            directory_default(app)
        elif not any(row[0] == app and available(row) for row in APPS[category]):
            raise ValueError('Application is unsupported or not installed')
        if category == 'agent':
            set_agent(app)
        elif category != 'file manager':
            run(category, app)
    result = []
    for category, apps in APPS.items():
        current = run(category)
        if category == 'editor' and current == 'zeditor':
            current = 'zed'
        result.append(dict(category=category, current=current,
                           apps=[dict(value=r[0], label=r[1]) for r in apps if available(r)]))
    result.append(dict(category='file manager', current=directory_default(), apps=file_managers()))
    print(json.dumps(result))

if __name__ == '__main__':
    try:
        main(sys.argv[1:])
    except (ValueError, OSError, subprocess.SubprocessError) as error:
        print(getattr(error, 'stderr', None) or str(error), file=sys.stderr)
        sys.exit(1)

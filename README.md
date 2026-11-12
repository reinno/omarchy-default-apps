# Default Apps for Omarchy

A native shell bar popup for switching the default browser, editor, and
terminal, and coding agent using Omarchy's own `omarchy default` commands. Shows current
defaults and offers supported applications found on PATH. Agent choices are commands available on PATH (including launcher wrappers). Selecting an agent only saves the preference; it does not install or launch it. Changes apply
immediately when selected. Open the panel again or click Refresh to detect
external changes.

Requires the Omarchy Quickshell plugin system and Python 3. Editor selection
controls `omarchy launch editor`; it does not change every document MIME
association. Browser and terminal behavior follows the installed Omarchy
commands. Flatpak-only applications and custom desktop entries are not yet
supported.

## Install

From this directory:

```sh
mkdir -p ~/.config/omarchy/plugins/reinno.default-apps
cp manifest.json Panel.qml defaults.py ~/.config/omarchy/plugins/reinno.default-apps/
omarchy-shell shell rescanPlugins
omarchy plugin enable reinno.default-apps --section right
```

Click the settings icon in the bar. You can also open it with:

```sh
omarchy-shell reinno.default-apps open
```

To disable: `omarchy plugin disable reinno.default-apps`.

## Checks

```sh
omarchy plugin validate .
python3 defaults.py
```

The second command only reads defaults. Manifest validation and local app
discovery have been checked; the popup still needs an in-session visual check.

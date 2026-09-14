# Tactical Modules

This directory contains user-maintained modules that extend WarStick. Modules are shown in menu option 4 and can also be run from option 3 with a command such as `/geo_ip_lookup`.

## Add a Module

1. Create a `.sh`, `.ps1`, or `.py` file in this directory.
2. Give the file a lowercase descriptive name with underscores, such as `service_lookup.sh`.
3. Add the metadata headers below. They supply the menu name, description, and whether WarStick should ask for a target argument.
4. Test the script directly on the intended operating system before using it from the menu.

```sh
#!/bin/bash
# NAME: Service Lookup
# DESC: Describe what this module does
# ARGS: true

TARGET="$1"
printf 'Target: %s\n' "$TARGET"
```

## Metadata

- `# NAME:` is the display name in the Tactical Modules menu.
- `# DESC:` is the short menu description.
- `# ARGS:` is `true` when the module requires a target, otherwise `false`.

PowerShell modules receive the supplied target through a `param([string]$Target)` declaration. Python and shell modules receive it as their first positional argument.

## Run a Module

Use menu option 4 to browse and run modules interactively. From option 3, type the module name with an optional target:

```text
/geo_ip_lookup
/dns_over_https example.com
```

Keep modules self-contained, validate their input, and avoid writing outside this directory or the operating system's temporary directory.

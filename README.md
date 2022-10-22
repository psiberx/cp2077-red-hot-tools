# Red Hot Tools

This plugin aims to help in the Cyberpunk 2077 mods development, offering the following features:

- Hot reload archives, scripts and tweaks
- See scripts validation and binding errors 
- Prevent game from starting if scripts compilation fails 

For greater convenience it integrates with other tools:

- **WolvenKit**: Pack & reload archives from the editor with a press of a button
- **Visual Studio Code**: Reload scripts and tweaks from the editor using context menu or hotkeys
- **Cyber Engine Tweaks**: Reload assets using in-game menu or console commands

## Getting Started

### Prerequisites

- [RED4ext](https://docs.red4ext.com/getting-started/installing-red4ext) 1.8.0+

### Installation

1. Download [the latest release](https://github.com/psiberx/cp2077-red-hot-tools/releases) archive
2. Extract the archive into the Cyberpunk 2077 installation directory

### Compatibility

The current CET 1.20 is not compatible with scripts hot reloading. 
You must use the latest CET from GitHub or Discord if you wanna use CET and scripts hot reloading at the same time.

## Documentation

### Limitations

- Functions are never removed (functions removed in the script source still exist in scripting runtime)
- Struct fields are not reinitialized (if you change the fields of a struct and an instance of that struct exists during hot reload, this can lead to issues)

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

- [RED4ext](https://docs.red4ext.com/getting-started/installing-red4ext) 1.9.0+

### Installation

1. Download [the latest release](https://github.com/psiberx/cp2077-red-hot-tools/releases) archive
2. Extract the archive into the Cyberpunk 2077 installation directory

## Visual Studio Code

The extension can be installed by dragging the `.vsix` file onto your VS Code extension bar.

## Documentation

### Limitations

- Struct fields are not reinitialized (if you change the fields of a struct and an instance of that struct exists during hot reload, this can lead to issues)
- Handlers for scriptable systems requests aren't registered on scripts load, if you add a new handler you have to reload the game session 

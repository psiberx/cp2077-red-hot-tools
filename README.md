# Red Hot Tools

This plugin aims to help in the Cyberpunk 2077 mods development, offering the following features:

- Hot reload archives, scripts and tweaks
- See scripts validation and binding errors 
- Prevent game from starting if scripts compilation fails
- Inspect entities and world nodes

For greater convenience it integrates with other tools:

- **WolvenKit**: Pack & reload archives from the editor with a press of a button
- **Visual Studio Code**: Reload scripts and tweaks from the editor using context menu or hotkeys
- **Cyber Engine Tweaks**: Reload assets using in-game menu and inspect world nodes and entities

>  Archive reloading is not supported on game version 2.0+ yet

## Getting Started

### Compatibility

- Cyberpunk 2077 2.02
- [Cyber Engine Tweaks](https://github.com/yamashi/CyberEngineTweaks) 1.28.1+

### Installation

1. Install requirements:
   - [RED4ext](https://docs.red4ext.com/getting-started/installing-red4ext) 1.18.0+
2. Extract the release archive `RedHotTools-x.x.x.zip` into the Cyberpunk 2077 directory.
3. _(Optional)_ Install CET UI: Extract the archive `RedHotTools-x.x.x-CET.zip` into the Cyberpunk 2077 directory.
4. _(Optional)_ Install VS Code extension: Drag the `red-hot-vscode-x.x.x.vsix ` file onto your VS Code extension bar.

## Visual Studio Code

With extension installed, when editing scripts or tweaks files in VS Code, 
you'll get new editor commands in the menu to hot reload the scripts or tweaks.
As any other command they can also be bound to hotkeys.

## Limitations

- Struct fields are not reinitialized (if you change the fields of a struct and an instance of that struct exists during hot reload, this can lead to issues)
- Handlers for scriptable systems requests aren't registered on scripts load, if you add a new handler you have to reload the game session 

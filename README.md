# Red Hot Tools

This plugin aims to help in the Cyberpunk 2077 mods development, offering the following features:

- Inspect game entities and world nodes
- Inspect ink layers and widgets (user interface)
- Hot reload archives, scripts and tweaks
- Prevent game from starting if scripts compilation fails

For greater convenience it integrates with other tools:

- **WolvenKit**: Pack & reload archives from the editor with a press of a button
- **Visual Studio Code**: Reload scripts and tweaks from the editor using context menu or hotkeys
- **Cyber Engine Tweaks**: Reload assets using in-game menu and inspect world nodes and entities

## Getting Started

### Compatibility

- Cyberpunk 2077 2.2
- [ArchiveXL](https://github.com/psiberx/cp2077-archive-xl) 1.18.0+
- [Cyber Engine Tweaks](https://github.com/yamashi/CyberEngineTweaks) 1.34.0+
- [redscript](https://github.com/jac3km4/redscript) 0.5.25+

### Installation

1. Install requirements:
   - [RED4ext](https://docs.red4ext.com/getting-started/installing-red4ext) 1.25.1+
2. Extract the release archive `RedHotTools-x.x.x.zip` into the Cyberpunk 2077 directory.
3. _(Optional)_ Install CET UI: Extract the archive `RedHotTools-x.x.x-CET.zip` into the Cyberpunk 2077 directory.
4. _(Optional)_ Install VS Code extension: Drag the `red-hot-vscode-x.x.x.vsix` onto your VS Code extension bar.

## Visual Studio Code

With extension installed, when editing scripts or tweaks files in VS Code, 
you'll get new editor commands in the menu to hot reload the scripts or tweaks.
As any other command they can also be bound to hotkeys.

## Limitations

- Struct fields are not reinitialized (if you change the fields of a struct and an instance of that struct exists during hot reload, this can lead to issues)
- Handlers for scriptable systems requests aren't registered on scripts load, if you add a new handler you have to reload the game session 

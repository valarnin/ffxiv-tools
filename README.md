# FFXIV Tools
Tools for installing and configuring FFXIV and ACT on Linux.

## If you're running Lutris with XIVLauncher
Use the [lutris-xivlauncher](https://github.com/valarnin/ffxiv-tools/tree/lutris-xivlauncher) branch

## If you're running Steam with a Proton version of 5.21 or less
Use the [old-steam](https://github.com/valarnin/ffxiv-tools/tree/old-steam) branch

## If you're running Lutris with the vanilla launcher
This setup is currently unsupported. You can modify the lutris-xivlauncher branch's process detection to look for the vanilla launcher's executable name, run through stage1 to stage3, and then before doing anything else, install .NET Framework 4.8 in the prefix.

## If you're running Steam with a Proton version greater than 5.21
Valve changed to using pressure-vessel/bubblewrap after Proton 5.21, which breaks the way these scripts modify the runtime to support reading network data. There's no known workaround to the issue currently. If you're technically capable and willing to experiment and test things, feel free to reach out on the #ffxiv-linux-discussion channel of the FFXIV ACT Plugin's discord.
# Transmission <img src="macosx/Images/Images.xcassets/AppIcon.appiconset/icon_256x256.png" alt="Transmission" width="32" style="vertical-align: text-top;">

Current Transmission, built for older Macs.

This fork keeps Transmission usable on Snow Leopard-era Macs. OS X 10.6 Snow Leopard through OS X 10.9 Mavericks are tested. OS X 10.10 and newer legacy targets still need testing. Some UI polishing remains.

<p align="left">
  <img src="docs/images/readme-main-window.png" alt="Transmission main window on Snow Leopard" width="420">
</p>

## What is different

- OS X 10.6 support, with compatibility presets covering 10.6 through 10.13.
- Torrent groups can use an **Announce as** setting to advertise a selected Transmission version to trackers. This is useful for trackers with strict client whitelists.
- Files inside a torrent can be renamed in batches, with a live preview before anything is changed.

The announce identity is applied where trackers and peers see it: HTTP user agent, peer ID prefix, and extension handshake client string. Batch rename supports replace, append, prepend, date, sequence, character removal, regular expression, and case changes.

<details>
<summary>Additional screenshots</summary>

<p align="left">
  <img src="docs/images/readme-torrent-inspector.png" alt="Torrent inspector on Snow Leopard" width="430">
</p>

<p align="left">
  <img src="docs/images/readme-preferences.png" alt="Preferences window on Snow Leopard" width="560">
</p>

<p align="left">
  <img src="docs/images/readme-batch-rename.png" alt="Filename batch rename on Snow Leopard" width="560">
</p>

</details>

## Build

- [Mac OS X 10.6 Snow Leopard](docs/macOS-10.6.md)
- [OS X 10.7 Lion through macOS 10.13 High Sierra](docs/macOS-Legacy.md)

For modern builds, use the regular Transmission build documentation:

- [How to Build Transmission](docs/Building-Transmission.md)
- [Official Transmission site](https://transmissionbt.com/)

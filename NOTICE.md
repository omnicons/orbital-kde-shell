# Credits and third-party material

## Inspiration

Orbiter recreates the look of "KDE Plasma Orbiter", a rice by captianjonez
shared on r/unixporn: an ASCII-rendered planet as a live wallpaper, with
lock and login screens on the same grid. None of that project's code is
included; everything here was written independently from screenshots and
the post's description.

## Bundled

These keep their own terms; the MIT licence in `LICENSE` covers the rest of
the repository.

| What | Where | Source | Terms |
|---|---|---|---|
| Share Tech Mono font | `src/theme/fonts/ShareTechMono-Regular.ttf` | Carrois Type Design, via Google Fonts | SIL Open Font License 1.1 (`ShareTechMono-OFL.txt`) |
| Doto font | `src/theme/fonts/Doto.ttf` | The Doto Project Authors, via Google Fonts | SIL Open Font License 1.1 (`Doto-OFL.txt`) |
| Earth and cloud maps | `src/scene/textures/earth.jpg`, `earth_clouds.jpg` | NASA Earth Observatory, Blue Marble | Public domain |
| Moon map | `src/scene/textures/moon.jpg` | NASA Scientific Visualization Studio, LRO colour map | Public domain |
| Star map | `src/scene/textures/stars.png` | Baked from the Yale Bright Star Catalogue, 5th revised ed. (Hoffleit & Warren, 1991) | Freely distributed by NASA's Astronomical Data Center |

`tools/` has the scripts and download links that produced the textures.

## Used, not bundled

IBM Plex Sans and Mono (SIL Open Font License) are installed from the
distribution (`ttf-ibm-plex` on Arch, `ibm-plex-sans-fonts` and
`ibm-plex-mono-fonts` on Fedora). Icons come from the system's icon
theme (Breeze).

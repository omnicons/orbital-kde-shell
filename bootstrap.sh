#!/bin/sh
# Sets up Orbiter on a CachyOS, Arch or Fedora 44+ machine running Plasma 6,
# from its git repository, with chezmoi:
#   sh bootstrap.sh <repository url>
# chezmoi clones the repository to ~/.local/share/chezmoi, asks a few
# questions about this machine (variant, lock and login screens, boot theme),
# then installs packages and builds everything. Later, `chezmoi update` pulls
# changes and rebuilds what changed.
set -e

repo="$1"
if [ -z "$repo" ]; then
    echo "Usage: sh bootstrap.sh <repository url>" >&2
    exit 1
fi

. /etc/os-release
case " $ID $ID_LIKE " in
*" arch "*|*" cachyos "*) sudo pacman -S --needed chezmoi git ;;
*" fedora "*) sudo dnf install chezmoi git ;;
*)
    if ! command -v chezmoi >/dev/null || ! command -v git >/dev/null; then
        echo "Install chezmoi and git, then run this again." >&2
        exit 1
    fi
    ;;
esac
chezmoi init --apply "$repo"

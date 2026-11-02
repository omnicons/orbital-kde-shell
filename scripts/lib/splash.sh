# Selects Orbiter's Plasma splash and puts the previous one back (sourced, not
# run). The previous theme and engine are kept in $DATA/orbiter/splash-previous,
# for theme --revert and uninstall. An engine of "none" means splash turned off.

splash_key() {
    kreadconfig6 --file ksplashrc --group KSplash --key "$1"
}

use_orbiter_splash() {
    saved="${XDG_DATA_HOME:-$HOME/.local/share}/orbiter/splash-previous"
    if [ "$(splash_key Theme)" != org.orbiter.splash ]; then
        mkdir -p "$(dirname "$saved")"
        printf '%s\n%s\n' "$(splash_key Theme)" "$(splash_key Engine)" > "$saved"
    fi
    kwriteconfig6 --file ksplashrc --group KSplash --key Theme org.orbiter.splash
    kwriteconfig6 --file ksplashrc --group KSplash --key Engine KSplashQML
}

# Leaves a splash chosen since alone.
restore_splash() {
    saved="${XDG_DATA_HOME:-$HOME/.local/share}/orbiter/splash-previous"
    if [ "$(splash_key Theme)" = org.orbiter.splash ]; then
        theme="" engine=""
        if [ -f "$saved" ]; then
            { read -r theme; read -r engine; } < "$saved"
        fi
        if [ -n "$theme" ]; then
            kwriteconfig6 --file ksplashrc --group KSplash --key Theme "$theme"
        else
            kwriteconfig6 --file ksplashrc --group KSplash --key Theme --delete
        fi
        if [ -n "$engine" ]; then
            kwriteconfig6 --file ksplashrc --group KSplash --key Engine "$engine"
        else
            kwriteconfig6 --file ksplashrc --group KSplash --key Engine --delete
        fi
    fi
    rm -f "$saved"
}

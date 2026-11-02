# Orbiter's fish colours. Every colour is one of the terminal's 16 named
# colours rather than a hex value, so they follow Konsole's palette: switching
# variants recolours open shells without touching fish. Universal variables,
# so running shells pick them up immediately. apply-theme.sh runs this.

set -U fish_color_normal normal
set -U fish_color_command blue
set -U fish_color_keyword magenta
set -U fish_color_quote green
set -U fish_color_redirection cyan
set -U fish_color_end yellow
set -U fish_color_operator yellow
set -U fish_color_escape cyan
set -U fish_color_error red
set -U fish_color_param normal
set -U fish_color_option cyan
set -U fish_color_valid_path --underline
set -U fish_color_comment brblack
set -U fish_color_autosuggestion brblack
set -U fish_color_selection --reverse
set -U fish_color_search_match --background=brblack
set -U fish_color_history_current --bold
set -U fish_color_cancel --reverse
set -U fish_color_cwd blue
set -U fish_color_cwd_root red
set -U fish_color_user brblue
set -U fish_color_host normal
set -U fish_color_host_remote yellow

set -U fish_pager_color_prefix normal --bold
set -U fish_pager_color_completion normal
set -U fish_pager_color_description brblack
set -U fish_pager_color_progress brblack
set -U fish_pager_color_selected_background --background=brblack

# Pure, CachyOS's prompt: the directory is already blue (the heading colour);
# the ❯ takes the accent instead of magenta.
set -U pure_color_success yellow

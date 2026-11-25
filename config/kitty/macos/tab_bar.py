# Tab titles for kitty's `tab_title_template "{custom}"`: an icon for the program in the
# foreground, the directory it runs in and a zoom mark.
import os

from kitty.fast_data_types import get_boss

HOME = os.path.expanduser("~")
SHELLS = {"zsh", "bash", "fish", "sh"}

# Nerd Font glyphs, by executable name
ICONS = {
    "claude": "",                                     # cod-claude
    "hx": "\U000F0684",                                     # md-dna (helix)
    "git": "", "lazygit": "",
    "java": "", "mvn": "", "mvnd": "", "gradle": "",
    "node": "", "npm": "", "npx": "", "pnpm": "",
    "python": "", "python3": "", "uv": "",
    "ssh": "",
    "docker": "",
    "kubectl": "\U000F10FE", "k9s": "\U000F10FE",
    "aws": "",
    "mysql": "", "psql": "", "harlequin": "",
    "lnav": "", "less": "", "bat": "", "tail": "",
    "htop": "", "btop": "", "top": "",
}
FALLBACK_ICON = ""  # terminal
FOLDER, HOUSE, ZOOM = "", "", ""


def _dir_name(wd):
    if not wd or wd == HOME:
        return "~"
    return os.path.basename(wd.rstrip("/")) or "/"


def _is_active(tab_id):
    tab = get_boss().tab_for_id(tab_id)
    manager = tab.tab_manager_ref() if tab else None
    return manager is not None and manager.active_tab is tab


def draw_title(data):
    tab, fmt = data["tab"], data["fmt"]
    exe = os.path.basename(tab.active_oldest_exe or "").lstrip("-")
    where = _dir_name(tab.active_oldest_wd)

    if not exe or exe in SHELLS:
        title = f"{HOUSE if where == '~' else FOLDER} {where}"
    else:
        # color8 is unreadable on the active tab's coloured block, so only inactive tabs dim
        dim = "" if _is_active(tab.tab_id) else fmt.fg.color8
        title = f"{ICONS.get(exe, FALLBACK_ICON)} {exe}{dim} · {where}{fmt.fg.tab}"

    if data["num_windows"] > 1 and data["layout_name"] == "stack":
        title += f" {ZOOM}"
    return title

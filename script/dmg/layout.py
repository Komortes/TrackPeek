# dmgbuild executes this file with the -D arguments in "defines".
app = defines["app"]
files = [(app, "TrackPeek.app")]
symlinks = {"Applications": "/Applications"}
background = defines["background"]
format = "UDZO"

window_rect = ((160, 140), (600, 340))
default_view = "icon-view"
show_status_bar = show_tab_view = show_toolbar = show_pathbar = show_sidebar = False
arrange_by = None
icon_size = 96
text_size = 14
icon_locations = {"TrackPeek.app": (150, 211), "Applications": (450, 211)}

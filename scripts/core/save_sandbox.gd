class_name SaveSandbox
extends RefCounted

## Test switch: when on, SaveManager and MetaProgression never touch user://,
## and the game never captures the mouse (the `--shots` window runs off-screen
## at -10000,-10000, and capturing there would grab the owner's real cursor).
## Read at autoload time (autoload _ready runs before the main scene), so it is
## initialised from the command line: the smoke test passes `-- --smoke-sandbox`.
static var enabled: bool = OS.get_cmdline_user_args().has("--smoke-sandbox")

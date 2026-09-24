class_name SaveSandbox
extends RefCounted

## Test switch: when on, SaveManager and MetaProgression never touch user://.
## Read at autoload time (autoload _ready runs before the main scene), so it is
## initialised from the command line: the smoke test passes `-- --smoke-sandbox`.
static var enabled: bool = OS.get_cmdline_user_args().has("--smoke-sandbox")

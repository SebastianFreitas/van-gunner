class_name DebugConfig
extends RefCounted

## Set true to ship the console in a release export. Default follows the build.
const FORCE_ENABLED := false
static var ENABLED: bool = OS.has_feature("debug") or FORCE_ENABLED

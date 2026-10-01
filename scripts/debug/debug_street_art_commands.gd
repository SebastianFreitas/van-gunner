extends RefCounted
## Debug console commands for the street-art pool: print its stats or save its atlas as a contact sheet PNG.


const _Pool := preload("res://scripts/travel/facades/street_art/street_art_pool.gd")

const _SHEET_SCALE := 3


## `args` are the words after `art`.
static func run(args: Array) -> String:
	_Pool.ensure(GameSession.run_seed)
	if args.is_empty():
		return _Pool.stats()
	if String(args[0]) == "sheet" and args.size() >= 2:
		var img := _Pool.atlas().duplicate() as Image
		img.clear_mipmaps()
		img.resize(img.get_width() * _SHEET_SCALE, img.get_height() * _SHEET_SCALE,
				Image.INTERPOLATE_NEAREST)
		var path := String(args[1])
		var err := img.save_png(path)
		if err == OK:
			return "saved street art sheet to %s" % path
		return "could not save %s (error %d)" % [path, err]
	return "usage: facade art [sheet <path>]"

# Copy an Image to the OS clipboard. Godot exposes clipboard_get_image but not set.
extends RefCounted
class_name ClipboardImage

const _TMP_PNG := "user://share_clipboard_tmp.png"
const _TMP_PS1 := "user://share_clipboard_set.ps1"


static func copy_image(image: Image) -> bool:
	if image == null:
		return false
	var err := image.save_png(_TMP_PNG)
	if err != OK:
		return false
	var abs_png := ProjectSettings.globalize_path(_TMP_PNG)
	match OS.get_name():
		"Windows":
			return _copy_windows(abs_png)
		_:
			push_warning("ClipboardImage: image clipboard not implemented on %s" % OS.get_name())
			return false


static func _copy_windows(abs_png: String) -> bool:
	var script := """param([string]$ImagePath)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
if (-not (Test-Path -LiteralPath $ImagePath)) { exit 2 }
$img = [System.Drawing.Image]::FromFile($ImagePath)
try {
	[System.Windows.Forms.Clipboard]::SetImage($img)
	exit 0
} catch {
	Write-Error $_
	exit 1
} finally {
	if ($null -ne $img) { $img.Dispose() }
}
"""
	var f := FileAccess.open(_TMP_PS1, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(script)
	f.close()
	var abs_ps1 := ProjectSettings.globalize_path(_TMP_PS1)
	var output: Array = []
	var code := OS.execute(
		"powershell.exe",
		PackedStringArray([
			"-STA",
			"-NoProfile",
			"-ExecutionPolicy", "Bypass",
			"-File", abs_ps1,
			"-ImagePath", abs_png,
		]),
		output,
		true,
		false
	)
	return code == 0

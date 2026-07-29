# scenes/profile/share/profile_share_render_worker.gd
class_name ProfileShareRenderWorker
extends RefCounted

## Runs OS.execute on a worker thread so the main loop (and LoadingOverlay spinner) keep moving.


static func execute_async(cmd: String, args: PackedStringArray) -> Dictionary:
	var thread := Thread.new()
	var err := thread.start(_execute.bind(cmd, args))
	if err != OK:
		return {"exit_code": -1, "detail": "thread start failed (%s)" % str(err)}
	while thread.is_alive():
		await Engine.get_main_loop().process_frame
	return thread.wait_to_finish()


static func _execute(cmd: String, args: PackedStringArray) -> Dictionary:
	var output: Array = []
	var exit_code := OS.execute(cmd, args, output, true, false)
	var lines: PackedStringArray = PackedStringArray()
	for line in output:
		var s := str(line).strip_edges()
		if s != "":
			lines.append(s)
	return {
		"exit_code": exit_code,
		"detail": "\n".join(lines),
	}

extends RefCounted
## click_driver part: game speed x3 -> intro stage plays at 1x, board keeps x3 after the card closes (also mid-attack, no-rig path).

static func run(d: SceneTree, g: GameScreen, u: Dictionary) -> void:
	var old_style := Token.fig_style
	for fig: String in [old_style, ""]:
		Token.fig_style = fig
		g.cards.intro_card(u, 0, 1)
		await d.process_frame
		var stage := g.cards.intro_stage
		var ph: Array[String] = []
		stage.phase_changed.connect(ph.append)
		d.call("ok", stage.fx.spd() == 1.0 and FX.speed == 3.0, "intro[%s]: stage x1 at game x3 (%s / %s)" % [fig, stage.fx.spd(), FX.speed])
		for i in 600:
			if ph.has("attack"):
				break
			await d.process_frame
		g.cards.intro_closed.emit()
		await d.create_timer(1.5).timeout # stop() waits out the in-flight FX.attack timer
		d.call("ok", ph.has("attack") and g.cards.intro_layer == null, "intro[%s]: closed mid-attack (%s)" % [fig, ph])
		d.call("ok", g.fx.spd() == 3.0 and FX.speed == 3.0, "intro[%s]: board x3 after close (%s)" % [fig, g.fx.spd()])
	Token.fig_style = old_style

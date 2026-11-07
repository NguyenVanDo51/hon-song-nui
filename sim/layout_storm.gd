extends RefCounted
## minimum_size_changed storm counter for drivers / probes. A layout handler that re-queues itself every flush
## (place_hud.call_deferred from minimum_size_changed) never lets the message queue drain -> "Message queue out of
## memory" crash. watch() counts emits; tick() once per frame keeps the peak; past LIMIT in one frame every other
## listener is cut so the run fails a check instead of crashing.

const LIMIT := 200

var peak := 0
var cut := false

var _n := 0
var _watched: Array[Control] = []

func watch(cs: Array[Control]) -> void:
	for c in cs:
		_watched.append(c)
		c.minimum_size_changed.connect(_hit)

func tick() -> void:
	peak = maxi(peak, _n)
	_n = 0

func stop() -> void:
	for c in _watched:
		if c.minimum_size_changed.is_connected(_hit):
			c.minimum_size_changed.disconnect(_hit)
	_watched.clear()

func _hit() -> void:
	_n += 1
	if _n <= LIMIT or cut:
		return
	cut = true
	push_warning("layout storm: %d minimum_size_changed in one frame, listeners cut" % _n)
	for c in _watched:
		for k: Dictionary in c.minimum_size_changed.get_connections():
			var cb: Callable = k.callable
			if cb != _hit:
				c.minimum_size_changed.disconnect(cb)

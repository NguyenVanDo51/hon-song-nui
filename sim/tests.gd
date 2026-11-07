extends SceneTree
## headless tests: <godot> --headless --path . -s sim/tests.gd   -> exit code 1 on failure
## suites live in sim/tests/ (test_base.gd = check / eq / run + helpers); this file runs them in order and sums.

const ParityTests := preload("res://sim/tests/parity.gd")
const ContentTests := preload("res://sim/tests/content.gd")
const RulesTests := preload("res://sim/tests/rules.gd")
const Rules2Tests := preload("res://sim/tests/rules_2.gd")
const MissionsTests := preload("res://sim/tests/missions.gd")
const DuelTests := preload("res://sim/tests/duel.gd")
const PlannerTests := preload("res://sim/tests/planner.gd")
const LevelgenTests := preload("res://sim/tests/levelgen.gd")
const AudioTests := preload("res://sim/tests/audio.gd")
const QuestTests := preload("res://sim/tests/quests.gd")

var failed := 0
var passed := 0

func _init() -> void:
	_add(ParityTests.new(), "parity_tests")
	_add(ContentTests.new(), "content_tests")
	_add(RulesTests.new(), "rule_tests")
	_add(Rules2Tests.new(), "rule_tests_2")
	_add(MissionsTests.new(), "mission_tests")
	_add(DuelTests.new(), "duel_tests")
	_add(PlannerTests.new(), "planner_tests")
	_add(PlannerTests.new(), "tactics_tests")
	_add(PlannerTests.new(), "v4_tests")
	_add(PlannerTests.new(), "v5_tests")
	_add(LevelgenTests.new(), "levelgen_tests")
	_add(AudioTests.new(), "audio_tests")
	_add(QuestTests.new(), "quest_tests")
	_add(QuestTests.new(), "quest_content_tests")
	print("tests: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

## run one suite function, add its counts
func _add(t: RefCounted, fn: String) -> void:
	t.call(fn)
	var p: int = t.get("passed")
	var f: int = t.get("failed")
	passed += p
	failed += f

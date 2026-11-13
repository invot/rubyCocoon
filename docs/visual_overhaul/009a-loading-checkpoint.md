# Step 009a — loading phase instrumentation checkpoint

**Historical checkpoint, superseded by [accepted 009a evidence](009a-loading-phases.md).** The resumed focused-01
runs completed two clean passes per renderer on 2026-11-12. Keep the earlier invalid attempts for traceability.

**In progress, 12 November 2026. No accepted phase measurement yet.** User selected “Keep working; checkpoint the
measurement” after two native window attempts lost foreground focus. Do not automatically repeat these while the user
is using other windows. Step 010a has not started and must wait for 009a's evidence.

Instrumentation is opt-in with `--load_phases=1` in `main.gd`; the ordinary transition keeps the same calls and awaits.
The vo-perf report saves teardown, dependency/script wait, world build, explicit finish, spawn, first battle prewarm,
audio prewarm, arrival/warm-up setup and the two existing process-frame awaits after viewport re-enable.
These await intervals are CPU wall intervals around frame scheduling, not isolated GPU compilation timers.

Invalid attempts retained intact:

- `build/perf/vo/009a/mobile-cost.json/.log`: one pass, one focus loss, one benchmark problem.
- `build/perf/vo/009a/gl_compatibility-cost.json/.log`: same. Tests were subsequently allowed while this already-invalid
  attempt finished; it is not a clean timing comparison. No second pass was accepted. Both runner processes have exited.

Their phase traces are useful leads: the Compatibility delay falls mainly in the first frame-await interval, while
construction/finish traversals are much smaller. **Do not use their numbers as accepted first/return evidence.**
No clean return pass exists and no shader/budget change was made from these traces.

Checks via server.py: quick (4 checks), vo-perf-route, transitions all passed. Results are beside the invalid traces.
Python compilation and `git diff --check` passed. Existing ObjectDB shutdown warnings remain.

When the user is ready to leave the window focused, run sequentially, with a new attempt name:

```text
python tools/vo_cost.py --phases --renderer mobile --attempt focused-01
python tools/vo_cost.py --phases --renderer gl_compatibility --attempt focused-01
```

The wrapper acquires the shared artwork/model lock and isolates state; do not wrap it again. Run outside the sandbox
as required for native Godot. It refuses existing report paths. Validate both passes, zero problems/focus losses,
phase sums against transition bounds, and errors in logs before completing 009a. Then write its ranking and automatically
continue to the isolated-phone resolution/pacing experiment 010a. Player package and lock settings remain untouched.

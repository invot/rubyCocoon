# Tutorial coverage

Introduce a rule where it becomes useful. Use short pages, then let the player perform the action. The shared
dialogue and battle controllers provide keyboard, controller and on-screen input without extra tutorial buttons.
The Coastal Path's four teachers give short guided battles from their own anchored bubbles. After them, the
**Codex** (`scripts/ui/codex.gd`, topics in `scripts/data/codex_db.gd`) explains everything else: a little robot
head at the top-left of the battle screen whose bubbles hang under it. It chimes in once per topic
(`codex_seen_<topic>`), answers questions without using a turn (Codex ? on the trainer's bar, a tap on it, the
Start book's Codex page), and only offers topics the player is eligible to know. Settings ► Codex tips turns its
chime-ins off; a journey played over three hours before the Codex existed has it turn them off itself, saying so.
Persistent flags belong to normal phone saves; previews and tests use `res://build/` saves only.

| Mechanic | Introduction |
| --- | --- |
| Actions, moves, aiming and confirming (two taps to target), damage | Tilly's Coastal Path battle |
| Defend | Dale's battle |
| Items and potions (Kit hands over a Minor Potion mid-battle, two more after) | Kit's battle |
| Slingshot and your own action going first; Mae then gives the Codex | Mae's battle |
| Turn order, Run and Forfeit, the basics again | Codex topics, always available |
| Middle guard, shields and attacking a trainer | Codex, first trainer battle |
| Several beasts on a side, choosing each one's move, aiming among several foes | Codex, first battle with two beasts on either side |
| Moving a beast, especially into a fainted middle | Codex, when your middle beast is down, or when Move is first picked |
| Weakness, resistance and the facing side's move element | Codex, when an elemental attack is first picked |
| The flute in battle, Weaken, eggs only from eggs | Codex, first battle with a flute (the first lone wild beast after Rafe's lessons always leaves an egg) |
| Rotating a larger party | Codex, first ordinary battle with more than three party beasts and a different living side; completion requires a real turn |
| Rhythm weapons | Lucille unlocks them at trainer Lv 4; the Codex then explains them in the next battle with one safe practice beat that repeats after a miss |
| Summons | Codex, first battle after a summon is yours |
| Move rules: accuracy, recharge, ally/group targets, status, stat changes, recoil/drain, protection | Codex, before confirming a relevant option the first time; exact move effects remain in the top bar |
| Automatic replacement targets, passives and equipment | Codex, at the first opposing group and the first active beast with a passive or gear |
| Boomerang and Bat in battle | Codex, before confirming each new weapon (only once it's owned) |
| Weapons for treasure and shortcuts | Ranger beside every unsolved weapon fixture; identifies required weapon and ownership, explains A/tap and the result; leaves after a successful solve |
| Fishing | Gil's guided first cast, strike and reeling lesson |
| Healing, eggs, storage, adoption and merging | Beast Center attendants, Guide Dottie and the machines' existing explanations and confirmations |
| Trainer growth, shield and slot upgrades | Trainer rewards, arena ladder and Volt's existing explanations |
| Later flute songs, capture levels, ghosts and temple puzzles | Existing song demonstrations, practice screens, teachers, singing stones and contextual prompts |
| Field powers, push puzzles, saving, courier and fast travel | Existing contextual people, signs, interactions and confirmations beside the feature |

Dustwell has one north road two tiles wide. Jasper occupies both tiles while his model is seated at their centre;
either tile interacts with the same actor. Lucille gives Jasper's Shoes as a key item with the lesson.
Returning the shoes clears both tiles and removes Jasper from subsequent loads. The studio keeps the old
`dustwell#1` identity and is always open. Existing saves with a previously learned rhythm attack retain it; saves
that already visited Sunwall (map `sundown`) retain their road access.

Focused verification:

```text
bash tools/run_tests.sh mechanic-lessons mechanic-lessons-touch
godot --path . --resolution 1920x1080 -- --scene=mechanic-lessons --shots=res://build/shots/tutorial_desktop --shot_w=0 --save_dir=res://build/tutorial_desktop_saves/
godot --path . --rendering-method mobile --resolution 2400x1080 -- --scene=mechanic-lessons --touch --shots=res://build/shots/tutorial_touch --shot_w=0 --save_dir=res://build/tutorial_touch_saves/
```

`--part=dance|summon|rhythm|ring|field` isolates one feature for windowed inspection. The regression deliberately
misses the Codex's first rhythm practice beat, uses real A/ring-tap input, checks that nobody waits outside the
temple and that summons are only explained once one is yours, that ring confirmation cannot skip the turn, that the
trainer's bar has Codex with its ? icon, that the Codex stays quiet when switched off, and saves/loads the shoes and
lesson completion. Weapon-walk tests cover
each fixture, touch approaches, ownership hints, treasure and guides remaining absent on re-entry.

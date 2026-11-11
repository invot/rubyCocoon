# Tutorial coverage

Introduce a rule where it becomes useful. Use short pages, then let the player perform the action. The shared
dialogue and battle controllers provide keyboard, controller and on-screen input without extra tutorial buttons.
Opposing trainers speak from anchored white bubbles, including the new ring and first-use explanations; wild
encounters use the shared dark system window for those instructions.
Persistent flags belong to normal phone saves; previews and tests use `res://build/` saves only.

| Mechanic | Introduction |
| --- | --- |
| HP, MP, actor selection, action and target confirmation, two taps to target | Tilly's Coastal Path battle |
| Rounds, speed, action order, plain attacks, MP and Defend | Dale's battle |
| Trainer actions, Slingshot, Watch, Items, Flute, Run and Forfeit | Kit's battle |
| Healing items, MP restoration and cures | Mae's battle |
| Active ring side, elements, middle guard, shields and attacking a trainer | Holt's battle |
| Three active beasts and choosing their individual actions | Rory's arena battle |
| Weakness, resistance and the facing side's move element | Ondine's arena battle |
| Reading songs, Weaken, capture and protecting a weakened target | Rafe's lessons and the first guided wild capture |
| Rotating a larger party | First ordinary battle with more than three party beasts and a different living side; choose your trainer action, then turn with up/down beyond the outer beast; completion requires a real turn |
| Rhythm weapons | Dustwell Dance Studio: trainer Lv 4 required; one safe practice beat repeats after a miss, followed by a protected weapon battle; completion unlocks chains |
| Summons | Ondine replaces the keeper outside the Temple of Tides after Abyssion joins, so only one person waits there; practise Summon and Song of Tides, shield cost, once-per-battle limit and a retry after a failed song |
| Move, recharge, ally/group targets, status, stat changes, recoil/drain, protection | Brief saved first-use explanations before confirming a relevant option; exact move effects remain in the top bar |
| Misses, automatic replacement targets, passives and equipment | First-use accuracy explanation; automatic-target explanation at the first opposing group; passive/gear explanation when an active beast has one |
| Boomerang and Bat in battle | First-use explanations before confirming each new weapon |
| Weapons for treasure and shortcuts | Ranger beside every unsolved weapon fixture; identifies required weapon and ownership, explains A/tap and the result; leaves after a successful solve |
| Fishing | Gil's guided first cast, strike and reeling lesson |
| Healing, eggs, storage, adoption and merging | Beast Center attendants, Guide Dottie and the machines' existing explanations and confirmations |
| Trainer growth, shield and slot upgrades | Trainer rewards, arena ladder and Volt's existing explanations |
| Later flute songs, capture levels, ghosts and temple puzzles | Existing song demonstrations, practice screens, teachers, singing stones and contextual prompts |
| Field powers, push puzzles, saving, courier and fast travel | Existing contextual people, signs, interactions and confirmations beside the feature |

Dustwell has one north road two tiles wide. Jasper occupies both tiles while his model is seated at their centre;
either tile interacts with the same actor. Lucille gives Jasper's Shoes as a key item once the lesson is won.
Returning the shoes clears both tiles and removes Jasper from subsequent loads. The studio keeps the old
`dustwell#1` identity and is always open. Existing saves with a previously learned rhythm attack retain it; saves
that already visited Sundown retain their road access.

Focused verification:

```text
bash tools/run_tests.sh mechanic-lessons mechanic-lessons-touch
godot --path . --resolution 1920x1080 -- --scene=mechanic-lessons --shots=res://build/shots/tutorial_desktop --shot_w=0 --save_dir=res://build/tutorial_desktop_saves/
godot --path . --rendering-method mobile --resolution 2400x1080 -- --scene=mechanic-lessons --touch --shots=res://build/shots/tutorial_touch --shot_w=0 --save_dir=res://build/tutorial_touch_saves/
```

`--part=dance|summon|ring|field` isolates one feature for windowed inspection. The regression deliberately misses
the first rhythm practice beat, uses real A/ring-tap input, plays a failed then successful summon song, checks that
ring confirmation cannot skip the turn, and saves/loads the shoes and lesson completion. Weapon-walk tests cover
each fixture, touch approaches, ownership hints, treasure and guides remaining absent on re-entry.

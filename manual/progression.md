# Progression and unlocks

[◀ Manual index](index.md)

The main story runs in one order: each objective has a gate that holds it, and clearing that gate opens the next place or system. This page is the single reference for that chain, from the first egg to the end of the Legion. Saved story flags are shown in `code` so a step can be matched to a save or a test.

The **Edition** column marks what the exported demo includes. The demo allows the towns through Dustwell and the routes between them; it ends at Captain Reed's riverboat, where boarding shows the credits and then leaves you free to keep exploring. Everything from the Mesa Trail onward is in the full game only.

## The progression table

| # | Objective | Gate | What it opens | Edition |
|---|---|---|---|---|
| 1 | Pick up the journal, leave home and choose a starter egg. | Take the journal from the bedroom floor; get an egg from Elder Rowan (`got_egg`) and hatch it at the Beast Center (`has_starter`). | Cocoon Cove, Scout Bram stepping aside, and the Coastal Path. | Demo + full |
| 2 | Complete the Coastal Path lessons and mend the creek footbridge. | Beat Tilly, Dale, Kit and Mae (`lesson_attack`, `lesson_defend`, `lesson_potions`, `lesson_sling`; then `tutorial_done`); ask Old Hal (`builder_asked`), take five logs (`bridge_log`) and lay them at the footbridge. | Bellerive; wild encounters, potions, the slingshot and the Codex; Old Hal's Driblo egg (`builder_egg`). | Demo + full |
| 3 | Get your father's flute and learn Weaken in Bellerive. | Talk to Neighbor Nell, then Uncle Rafe; play Weaken back (`has_flute` and the Weaken song). | Songs and arena entry; the first wild beast after this always leaves an egg (`flute_lesson_done`). | Demo + full |
| 4 | Win Bellerive's arena and passage to the Isle of Tides. | The arena door and Captain Gull both require a flute. Beat Tide Captain Marina for the Wave Crest. | Bellerive Shanty and Captain Gull's ferry to Shellhaven. | Demo + full |
| 5 | Open Kelpwick's reef path. | Hear the Shellhaven and Kelpwick chiefs (`shell_heard`, `kelp_heard`); beat Reef Warden Nerissa for the Coral Crest (`island_peace`). | Kelpwick's villagers step aside; the Coral Reef and the Temple of Tides. | Demo + full |
| 6 | Calm the Temple of Tides. | Solve the tide puzzles, wear down Abyssion and play the Song of Tides (`guardian_water`). | The water summon; the Dune Road sandstorm lifts and the Dune Ranger stops sending you back. | Demo + full |
| 7 | Restore Dustwell's well. | Arrive for the missing-trainer trail (`missing_trainers`); talk to Rosa (`met_rosa`); descend the well, beat its five beavers (`well_beaver_0` to `well_beaver_4`) and mend its bridges, door and ladder; reach Dale (`dale_met`) and wake the spring (`well_restored`). | The water stone, the Water spell, the town well and Rosa's Rubywave Five. | Demo + full |
| 8 | Learn Torrent and refill the Dustwell river. | Carry the water stone into the Temple of Tides sanctuary (`water_mages_found`); learn Torrent from Keeper Nerine; play it at the dry spring (`river_restored`). | The lake and river; Captain Reed's riverboat; the demo's end state, or the Mesa Trail in the full game. | Demo + full |
| 9 | Board Captain Reed's riverboat. | `river_restored`; in the demo (`BuildEdition.is_demo()`) the boat offers Board or Stay. | **Demo only:** the credits, then free play in the areas already reached. The demo map check blocks every later map. | Demo only |
| 10 | Cross the lake and climb the Mesa Trail. | `river_restored` in a non-demo build; board at the landing (`riverboat_west`). | Mesa Trail (`route4`), the Scaraba Desert (`route5`) and Scaraba. | Full game only |
| 11 | Help Captain Dalton and break the Jackals. | Talk to Dalton (`met_sheriff`); the hideout stays shut until then. Beat Bart the Jackal (`bandits_cleared`). | Dalton's bounty and the Bat. (The desert no longer has a barricade: the road from the Mesa Trail reaches Scaraba through it.) | Full game only |
| 12 | Calm Valkoog. | Climb its four floors, answering each floor's star (1, 3, 5, 2, 4, 1) to still its trap; learn the Song of Winds from the keepers (`song_winds`, `winds_song_door`); wear Zephyrax down with Tam and Saffi and play the song to it (`guardian_air`). | The air summon; the released wind scours the dune and bares the gear conduit (`conduit_rubbing`). | Full game only |
| 12a | Get out of Valkoog and report back. | Beat Bart's crew on the temple road (`jackals_ambush`); hear Grubb out in Scaraba (`grubb_report`). | The searched cistern's handbills; the gate wagon to Reed's landing and the boat to Dustwell (both ways). | Full game only |
| 12b | Search the Dustwell church and free the trainers. | Grubb unlocks the church (`grubb_report`); follow Hoss's story down the well, befriend the beavers and let them chew the barred door (`trainers_door`); Hoss confesses and is beaten (`hoss_confessed`, `jackals_disbanded`); the strongbox gives the **Coded Ledger** and **Freight Manifest**. | The reunion on the square (`trainers_freed`); Clem keeps his hat and leaves for the Caldera Road (`clem_left`). | Full game only |
| 12c | Take Hoss's ledger home and beat Windcaller Sable. | Ride the gate wagon back; Captain Dalton takes the coded ledger and keeps a copy of the manifest for you (`dalton_ledger`); Sable's three juniors are home at the arena (`sable_trainers_home`). Win the Spur Crest in the arena (`north_road_open`). | The north-gate soldiers stand aside; Riposo Valley (`route5b`) to Copperpick and the Mine Road. Its crayon statues shut the pass (`riposo_statues_seen`); Volt in Bellerive builds the `crayon_eater` that clears each one (`crayon_statue_<n>`). | Full game only |
| 13 | Earn a Miner's Pass and cross the Mine Road. | Beat Mine Foreman Gorran at Copperpick Arena for the Ore Crest and a `miner_pass`; show it to Inspector Grubb (`mine_pass_ok`). | Mine Road (`route6`) to Cogsworth. | Full game only |
| 14 | Climb Gearheart Tower and free the missing trainers. | Beat each floor's sentries to unlock its stairs; beat CEO Matt Gearheart (`ceo_defeated`); use the top-floor Freight Lock Control (`trainers_freed`). | The Caldera Road steam gate (`route7`); Lio, Bea and Orin rescued. `trainers_freed` is required before the final confrontation. | Full game only |
| 15 | Calm the Temple of Flame. | Capture the fire guardian (`guardian_fire`). | The fire summon; the story's next objective is the jungle relics. | Full game only |
| 16 | Cross Summit Pass. | Clear the sliding ice wall with a fire beast. | Summit Pass (`route8`) to Vinehollow and the jungle. | Full game only |
| 17 | Open the deep jungle and collect the three relics. | Beat Warden Kato (`warden_beaten`); take Shaman Ayo's quest (`relic_quest`); find the Sun (Vinehollow), Moon (Summit Pass) and Earth (Jungle Trail) relics (`relic_sun`, `relic_moon`, `relic_earth`). | The shrine ritual and the deep Jungle Trail. | Full game only |
| 18 | Raise and calm the Temple of Roots. | Place all three relics at the shrine (`ritual_done`); capture the earth guardian (`guardian_earth`). | The earth summon and the road on to Riverbend. | Full game only |
| 19 | Cross the Moor Road to Gravenmoor. | Blow the fog away with an air beast; beat Sentinel Morrow (`sentinel_beaten`). | Gravenmoor; ghost eggs and merging; Old Mort's Requiem (`got_requiem`). | Full game only |
| 20 | Break the Legion in Gravenmoor. | Beat Grunt Vesper at the cathedral door (`tr_gravenmoor_gate`); beat Commander Nyx (`nyx_defeated`); capture the crypt guardian (`guardian_ghost`). | The cathedral and the crypt stairs; the final confrontation with Vexmora. | Full game only |
| 21 | Defeat Vexmora and shut down the network. | `trainers_freed` is required. Beat Vexmora (Jared), then use the Intake Isolator, Spirit Reservoir and Network Shutdown in that order (`game_cleared`). | The ending, post-game free play, ghost companions and the Andrew/Jared bonus wedding. | Full game only |

Optional side content, such as Deputy Rusk and Slim in Dustwell, story-irrelevant arenas and Sky Tower lockers, is left out unless it gates the main line.

## How this was checked

- **Order and flags** come from `Story.next_goal()` in `scripts/autoload/story.gd`, including its `demo_freeplay` branch.
- **Hard gates** come from `Story.can_use_exit` (demo map check, cathedral and crypt stairs) and `Story.can_enter` (arena flute rule, hideout `met_sheriff`), plus the route gates in `scripts/data/maps/route_maps.gd` (`bandits_cleared`, `ceo_defeated`) and `scripts/data/maps/town_maps.gd` (`island_peace`).
- **Travel and the demo cutoff** come from `Story._ferry`, `Story._riverboat` and `BuildEdition.allows_map` in `scripts/core/build_edition.gd`.
- `godot --headless --path . --script res://tools/check_data.gd` reports `DATA CHECK DONE: 0 problem(s)`.

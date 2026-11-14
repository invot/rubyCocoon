# The Rubywave Five: desert debt and Cogsworth concert

**User direction: 14 November 2026. Status: planned only; not implemented.**
This is the story specification for the additions scheduled in [runbook.md](runbook.md)
steps 082a–082b and 105a–105c, with documentation and hint checks in 094 and 108.
It extends the existing missing-trainer/Gearhart story rather than replacing it.

## The band

- **The Rubywave Five has exactly four people.** Whenever they introduce themselves,
  they identify themselves as the **first, second, fourth and fifth members**.
  Never explain the missing third member or add a fifth performer to resolve the joke.
- They dream of making it big in Cogsworth, where they already have fans.
- They are deeply in debt to a saloon in a desert town. Dialogue must make clear
  that its owner trapped them in a shady contract designed to keep them in debt.
- They have been searching the desert for valuable gems to buy their freedom,
  but have found nothing.
- Member names, instruments, singer identity and the saloon owner's identity are
  not yet specified. Preserve Dusty's existing Card Ledger/Slim quest if using
  Dustwell's saloon; do not silently rewrite that role.

## Desert sequence

1. **Meet the band on the desert path toward Cogsworth.** Plan placement on the
   **Dune Sea**, which already contains the Temple of Winds, with space for the
   four members and a required patch of cacti. Their conversation establishes
   the contract, failed gem hunt, ambitions and existing Cogsworth fans.
2. **Defeat the Temple of Winds guardian.** One of the temple's chests contains
   a **diamond**. After the guardian is defeated, the player **cannot leave the
   temple until they collect that diamond**. Make the chest and next objective
   clear; do not require opening unrelated chests or block retreat before victory.
3. **Return to the saloon owner and give them the diamond.** The owner explicitly
   says the band's debt is paid off. This is the quest hand-in, not an ordinary
   sale: protect the diamond as a key item until handed over.
4. **The freed band plays at the cactus blockage.** The cacti dance and clear
   the path permanently. This is a required band performance; the optional
   Singing Cactus/flute song must not bypass this story event.
5. **The band moves ahead toward Cogsworth.** Before leaving, they tell the
   player to visit the concert venue there: **two free tickets** will be waiting.

Keep the existing Jackals, Temple of Winds and Copperpick/Miner's Pass progression.
The saloon must remain reachable for the diamond hand-in; place the cactus gate
after access to the temple and the return route, without a circular dependency.

## Cogsworth sequence

1. **Tower entry is refused.** When the player tries to enter Gearhart Tower,
   a security guard stops them. Establish that the guard is a huge Rubywave Five
   fan. This is a new entrance gate before the existing tower sentry fights.
2. **Collect the two free tickets at the theater/concert venue.** The attendant
   says the show is not until later and tells the player to find someone to bring.
   This is story progression, not a real-time wait.
3. **Return to the tower and invite the guard.** They excitedly accept the spare
   ticket. The show follows once the invitation is resolved; allow visiting the
   venue before the first tower attempt without losing or blocking the invitation.
4. **Attend “Table Banana.”** Play the silly, skippable concert film described
   below, with the player and guard attending together.
5. **Receive a backstage invitation.** After the show, the attendant approaches
   the player and guard and invites both backstage.
6. **Talk to the band backstage.** The guard says they are going to stick around
   backstage. The player can then leave and enter the tower without being stopped.

The invitation alone does not unlock the tower: the concert/backstage sequence
explains why the guard leaves their post. The backstage conversation remains
available after a skipped performance.

## “Table Banana” concert film

- **Audio will be supplied by the user.** Lyrics, duration and timed cues must be
  derived from that supplied track; do not invent final lyrics or substitute audio.
- The four-member band gives a very energetic performance. The crowd stands and
  cheers throughout. The guard loses their mind with excitement, screams how
  much they love the singer and sings along.
- Venue lighting goes wild through movement, colour and intensity changes,
  **with no strobes**. Keep the band, crowd and bubbles readable.
- The singer's lyrics appear in speech bubbles. The guard's sung lyrics are
  **ALL CAPS**, with **wiggling letters** to emphasize excitement. Extend the
  shared dialogue presentation for this effect when implemented; retain readable
  text, speaker anchoring and safe-area/touch clearance.
- Use the established film controls on keyboard, gamepad and touch, including
  visible touch A/B and hold-B skip. Skipping must advance cleanly to the
  post-show/backstage invitation, with the same quest outcome as watching.
- Tell the sequence through performance and character speech, with no narration,
  captions or title cards. Stage and world signs use the shared world alphabet.

## Existing story after entry

Once the guard stays backstage, the existing four-floor Gearhart Tower chapter
continues: defeat each floor's sentries, defeat Gearhart, and use the top-floor
Freight Lock Control to rescue Lio, Bea and Orin. Their testimony points to
Vexmora in Gravenmoor. Gearhart's defeat still opens Caldera Road to Emberfall;
the water-beast lava crossing remains, and the rescue is still required before
confronting Vexmora. The Cogsworth arena is not the tower-entry unlock.

## Implementation acceptance (future work)

- Save each quest milestone and permanent cactus/tower access. Repeated dialogue,
  hand-ins, map changes and loads must not duplicate the diamond or tickets,
  repay the debt twice, strand the band or restore the guard to a cleared doorway.
- Preserve player data: saves already beyond a new gate must not be locked out
  or forced to replay earlier story. Define the migration when implementing.
- Verify temple exit before victory, after victory without the diamond, and
  after collection; saloon backtracking; cactus-gate order; venue-first and
  tower-first visits; invitation; watched and skipped concerts; backstage exit;
  and tower access after reloading. Check touch, keyboard and gamepad.
- Capture the band, dancing cacti, concert, excited guard's bubbles and backstage
  at desktop and wide touch sizes; get visual approval at each runbook checkpoint.
- Keep concert crowd, animation and lighting inside the established phone budgets.
  The existing pageant remains a separate optional activity; sharing its venue
  is an implementation choice, not a replacement for either event.

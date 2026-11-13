# Font update — 12 November 2026

User-requested visual exception while 010b phone evidence remains pending. Status: waiting for visual approval.

Bundled Short Stack Regular and Noto Sans Old North Arabian from the official Google Fonts repository with OFL licenses. UIKit body/dialogue/action/value font now Short Stack; names/headings retain League Spartan 600. Each face owns symbol fallback metrics so their line heights do not contaminate each other. The title logo remains unchanged.

World lettering helper maps A–Z to U+10A80–U+10A99 (case insensitive, left-to-right fictional alphabet). Original English is retained as label metadata. Applied to frontier sign words/missing posters, island HOTEL lettering and STAFF ONLY plates. Existing procedural pseudo-writing on generic signpost meshes is still legacy artwork; replacing it with this font needs a separate artwork/capture pass. This is not a claim that every baked asset has been audited.

Actual dialogue captures: build/shots/fonts-before-dialog.png, fonts-after-dialog.png and fonts-after-dialog-touch.png (2400×1080). Short Stack is wider; the captured sentence stays within its bubble and retains readable sizing. World lettering still needs dedicated visual captures/review.

Checks: quick, video-settings, video-settings-touch, polish, exteriors (112 buildings) and cove-exteriors passed. The old hardcoded Spartan line-height assertion was replaced by an invariant comparing fallback height with the selected body face. Existing exit resource warnings remain. Player saves untouched. Final polish rerun passed all 26 mapped glyphs and deterministic mapping checks.

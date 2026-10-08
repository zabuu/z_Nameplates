# zNameplates

Standalone extraction of the pfUI nameplate module for OctoWoW. It only owns
nameplates and nameplate settings; combat text and damage numbers are not
included.

## Setup

1. Enable `zNameplates` in the addon list.
2. Turn off the pfUI nameplate module if pfUI is enabled. Only one addon should
   own Blizzard nameplates at a time.
3. Open the settings window with `/znp` or `/znameplates`.
4. Toggle the movable, collapsible combat-nameplate list with `/znp list`.

Settings use an opaque, screen-fitting panel with sidebar categories, grouped
scrollable rows, and cross-category search. All original controls and saved
paths are preserved. Sliders have bounded exact-number entry; textures display
friendly names rather than file paths. Dependent controls dim when inactive,
and descriptions/tooltips explain precedence, limits and optional APIs.
Changes apply live. Undo reverses the last change; category and full resets
require confirmation. Crowds exposes the clustering threshold (30 default),
health bands, and count-badge size/colour/opacity. List exposes visibility,
collapsed state, scale, opacity, and independent width (0 = automatic).
Preview collects the existing dummy controls; Advanced includes `/znpdump`.
Raid-marker positioning and cast-time precision (0–3 decimals) now honour their
selectors instead of using hard-coded placement or only 1/2 decimal modes.

Regular settings rows are compact (32 px; sliders 38 px), with explanatory
text in tooltips rather than permanent spacer lines. The Profiles category
keeps the existing per-character `zNameplatesDB` storage unchanged. Its account
index, `zNameplatesProfiles`, stores a separate new-character baseline and
character copies for discovery. The first established character seeds that
baseline automatically; existing characters never inherit over their saves.
Log in to each character once to make it available as a copy source. Copies
and restores require confirmation and retain the previous configuration in
`profileRestorePoints`. `profileMigrationSnapshot` retains each character's
pre-profile settings, and learned flight-path data stays character-local.
"Use my settings as the default" affects only future/new characters and reset
defaults; it does not modify existing characters. Before this migration, the
current saved-variable files were copied to the ignored `SavedVariablesBackups`
directory without changing their originals.
The settings panel is fully opaque and renders above world nameplates, chat,
and cluster badges. Colour pickers and confirmation dialogs opened from it
render above the panel and restore their original UI strata when closed.

The Preview settings page can show a 1-30 plate dummy cluster for live
appearance and overlap testing. With zAPI available, its shared origin is
locked into world space, each plate receives a stable 1-5 yard X/Y offset, and
the formation responds to camera position, rotation, pitch, and zoom. When
zDNumbers is enabled, **Dummy Damage!** pulses representative outgoing damage
through its real MSBT rendering path.

Distance sizing scales the entire plate, rather than changing font sizes in
steps. With zAPI loaded, it uses floating-point world positions and updates
the scale every rendered frame. The minimum distant size supports 0.01%
adjustments.

Name, guild/sub-name, and level labels use a 4x font on a quarter-scale,
non-interactive surface that inherits the whole plate's floating-point distance
scale. Combat-red names apply only to attackable hostile units, not friendlies
or neutral names. Nameplates remain visible over UI windows, but the current
mouse-focus stack (or legacy open-panel checks) prevents clicks through them.

Plate text has its own non-interactive layer above bars/icons. Parent-first
explicit strata/level updates keep backdrops below their bars, including when
strata changes without a depth-rank change. Per-frame checks repair text and
health-backdrop drift without rewriting healthy layers. The 4x font surfaces
and cluster-count badge participate in the same ordering.
For missing fills or flickering labels, mouse over or target the affected unit
and run `/znpdump`; it reports native/rendered health values, fill, backdrop,
text/font-surface layers, opacity, size, depth, and clustering state.

The Distance page also offers **Smooth nameplate transitions**, enabled by
default with a 0.12-second transition. New plates fade in, and sudden native
stacking corrections ease into place. With zAPI available, projected unit
movement is excluded from this smoothing so normal camera movement stays
responsive. Reused frames reset their animation and distance-scale state;
large teleports are not eased across unrelated units.

Crowded scenes refresh the entire depth ordering together at 30 Hz (60 Hz
with up to 20 plates). Unit attachment/removal and target changes bypass that
limit. Movement, transition smoothing, and distance scaling still update every
rendered frame. Native projection results are shared between consumers within
that frame, and the player's world position is read once rather than per plate.
Pool recovery scans run twice a second; normal lifecycle events remain immediate.
The anti-flash guard checks opacity without rewriting already-invisible regions.

Above the configured threshold (30 visible plates by default), crowd clustering combines attackable NPCs with the
same name, level, tag ownership, and health band. Crowds settings include a
toggle and a 10–20% health-band slider (20% default). A cluster displays, for
example, `Lasher x7` with its mean remaining-health percentage. The count is a
larger bright-gold badge with a thick black outline and shadow; it does not
inherit the overlay's distance shrink or distance fade. Membership is
refreshed every 0.1 seconds and the representative stays at the same member's
world anchor while that member remains in the band. Clicking a cluster targets
its currently lowest-HP living member, even when regular plates are click-through.
Your target, raid-marked units, players, friendly/unprovoked neutral NPCs,
critters, and totems remain individual. Representative-only auras and casts
are hidden because they would misrepresent the whole group. Hidden members
skip normal rendering/data and depth ordering work, but their native unit
frames remain available for exact clicks and damage-number anchoring.
Individual plates return when the visible count drops to the configured threshold or fewer.

The Text page provides live hostile, friendly, and combat font-style previews.
Combat styling is optional and is applied only while a plate is confirmed to
be in combat with the player. Numeric settings use bounded sliders; selectors
open full dropdown lists, with every font choice previewed in its own face.

The Chat page enables speech beside visible speakers' names.
It uses the current chat channel colours and offers position, offsets, scale,
font, width, duration, fade, opacity, and channel filters.
Supported speech includes say/yell, party and leaders, raid and warnings,
guild/officer, incoming/outgoing whispers, emotes,
battleground/instance groups, and NPC/boss speech. Each category can be filtered
on the Chat page. Numbered/custom channels are intentionally excluded.
Only locatable nearby speakers can receive bubbles, not remote guild members
or whisper senders outside the client's visible unit data. System notices and
internal addon messages are not speech and are not displayed as bubbles.
Enabling it turns off
Blizzard's normal and party chat bubbles and suppresses any surviving native
bubble frames (including skins); disabling it restores their previous opacity and the bubble
settings captured when it was enabled during this session. Speech expires
after eight seconds by default and follows a confirmed speaker rather than a
reused nameplate frame. Duplicate NPC names are left unassigned when ambiguous.
Appearance also includes level-text reference, position, and X/Y offsets.
"Show chat when player nameplates are hidden" is an additional opt-in Chat
setting. With zAPI loaded, it projects player speech at the speaker's head,
including your own character, even without a visible plate. Speakers are
resolved by chat GUID, current units, group units, or the optional player cache.
It hides speech behind the camera and returns to the actual nameplate anchor
when one becomes visible. NPC speech still requires a visible nameplate.
Messages have no added colon or pointer. A borderless background with subtly
rounded corners hugs the message text with minimal padding. Its colour and
opacity are configurable on the Chat tab (default charcoal at 35% opacity);
setting background opacity to zero removes it. It follows the chat scale and
fade while the text retains its channel colour.

The first time zNameplates loads, it imports only relevant nameplate,
appearance, font, cooldown, and throttle values from an available pfUI saved
configuration. Later changes are stored independently in `zNameplatesDB`.

For MSBT-powered damage attached to visible nameplates, install the separate
`zDNumbers` addon and configure it with `/zdn`.

The extracted nameplate implementation is based on pfUI and retains its MIT
license in `LICENSE-pfUI`.

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

The General settings page can show a 1-30 plate dummy cluster for live
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

Above 30 visible plates, crowd clustering combines attackable NPCs with the
same name, level, tag ownership, and health band. Distance settings include a
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
Individual plates return when the visible count drops to 30 or fewer.

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

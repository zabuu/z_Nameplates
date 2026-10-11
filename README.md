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

General includes a default-on mouseover-unit option for SuperWoW or Nampower
clients that provide `SetMouseoverUnit`. Hovering a clickable plate sets its
unit without changing your target; leaving or removing the plate clears it.
Cluster hover uses the same live lowest-health member as clicking. Without
that API, existing mouse behaviour is unchanged.
To click through friendly plates while retaining hostile clicks, turn off
`Click-through nameplates` and enable `Click through friendly nameplates`.
Click-through plates do not receive hover events; neutral NPCs are unaffected
by the friendly-only option.

Distance includes optional `Sticky non-overlapping placement` (default on).
With zAPI, a warm local layout favours compact placement near each mob's home
anchor rather than permanent columns. It resolves persistent collisions with
small upward or modest sideways adjustments and gently returns home as room
opens. Relocation is damped and speed-limited; genuine camera/mob motion follows
immediately. The displacement limit, smoothing, speed and hover protection are
adjustable. Hover pauses layout relocation and holds briefly after departure;
displaced selected/hovered plates can show a subtle dotted anchor connection.
Overlap-allowed plates retain native placement. Their centre-to-projection
bias is recorded before combat, then preserved during sticky stacking without
adopting subsequent native collision shifts or applying the bias twice.
Sticky visuals use screen-relative anchors calculated after distance scaling,
so later native collision-frame movement cannot shove them for one frame.
Brief missing projection samples retain the last good placement for at most
0.12 sec; hidden or recycled units never inherit that grace period.
Meaningful collisions must persist for 0.15 sec by default. Open space is
reclaimed continuously through the same non-bouncy motion, not a delayed snap.
Collision bounds use the visible name, level, guild, health/cast bars, raid
marker and auras, not the old oversized placeholder. Dense scenes can still
overlap at the displacement limit; clustering is preferable to detached towers.
Disable it to restore native placement with the existing transition smoothing. Missing projection data,
teleports and scenes above 100 non-overlapping plates safely fall back.
General / Stacking provides independent horizontal and vertical plate buffers
(0–40 px per side, default 0). Buffers scale with the plate and affect both
native collision frames and sticky placement, not visible bar/text dimensions.

Settings use an opaque, screen-fitting panel with sidebar categories, grouped
scrollable rows, and cross-category search. Unrelated controls and saved
paths are preserved; obsolete HP-band/column controls were superseded, but
their saved values remain intact for rollback. Sliders have bounded exact-number entry; textures display
friendly names rather than file paths. Dependent controls dim when inactive,
and descriptions/tooltips explain precedence, limits and optional APIs.
Changes apply live. Undo reverses the last change; category and full resets
require confirmation. Crowds exposes the clustering threshold (30 default),
health-range opacity, debuff subgroups, and count-badge size/colour/opacity. A
cluster bar is solid from zero to its lowest HP member, then translucent up to
its highest HP member. Exact debuff names separated by `#` split matching mobs
into unique subgroups; the first matching list entry wins. Enemy type, level
and tag-ownership boundaries remain separate. List exposes visibility,
collapsed state, scale, opacity, and independent width (0 = automatic).
Preview collects the existing dummy controls; Advanced includes `/znpdump`.
Preview also includes adjustable cluster range/member-count samples using the
real range renderer. Its first two debuff subgroups reflect the Crowds list.
`Dummy cluster in combat with me` simulates combat fonts, name/threat colours,
castbars and overlap rules without affecting real player combat. Camera-aware
dummies use the same placement solver in an isolated scene. Full preview
opacity and foreground display are enabled by default: while Preview is open,
dummy plates render above the settings background but below modal dialogs.
Turn either off to restore world-layer rendering or actual distance/inactive
fading. These controls affect only the dummy preview, not real nameplates.
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

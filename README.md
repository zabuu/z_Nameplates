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
All world-owned plates use the projected nameplate anchor plus the configured
vertical offset. With zAPI 1.9+, that anchor is the client's model name
attachment plus its native clearance, taken before Blizzard's collision
layout. This restores the original height without capturing an already-pushed
frame, applying a manual lift, or reseeding it on combat/toggle changes. Older
DLLs retain the collision-height projection until the client restarts with
the updated DLL. Overlap/combat settings change avoidance only; they never
replace that anchor or recalibrate height from Blizzard's frames. Native
collision frames are reduced to 1x1; the visible overlay handles clicks/hover.
Friendly/pet and hostile plates have separate collision groups. Live unit
GUIDs and frame associations are validated; recycled/stale slots are excluded.
Sticky visuals use screen-relative anchors calculated after distance scaling,
so later native collision-frame movement cannot shove them for one frame.
Brief missing projection samples hold the last good placement for 0.12 sec,
then hide without discarding the anchor state or returning to native stacking.
Missing samples are not obstacles. Hidden or recycled units never inherit grace.
Meaningful collisions must persist for 0.15 sec by default. Open space is
reclaimed continuously through the same non-bouncy motion, not a delayed snap.
Collision bounds use the visible name, level, guild, health/cast bars, raid
marker and auras, not the old oversized placeholder. Dense scenes can still
overlap at the displacement limit; clustering is preferable to detached towers.
Disable it (or run without zAPI) to restore native placement with the existing
transition smoothing. Above 100 projected plates, avoidance work is suspended
while stable world anchoring continues; clustering is recommended.
General / Stacking provides independent horizontal and vertical plate buffers
(0–40 px per side, default 0). Buffers scale with the plate and affect both
native collision frames and sticky placement, not visible bar/text dimensions.
When world anchoring owns the plates, only the custom collision bounds use
these buffers; native frames stay 1x1 so they cannot create a second layout.

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

Every rendered frame checks the front-to-back order using the camera depths
already calculated for world attachment. An unchanged order needs only a linear
check, with no sorting, screen-overlap comparisons or layer reassignment.
Actual depth crossings and membership changes repair the order immediately,
including the high-FPS visual-only path. Legacy depth fallbacks and defensive
layer audits retain their 30 Hz crowd / 60 Hz small-scene cadence.
Movement, transition smoothing, and distance scaling still update every
rendered frame. Native projection results are shared between consumers within
that frame, and the player's world position is read once rather than per plate.
Pool recovery scans run twice a second; normal lifecycle events remain immediate.
The anti-flash guard checks opacity without rewriting already-invisible regions.

Depth-layer slots follow relative front-to-back order, not absolute distance
bands. Camera movement that preserves that order no longer re-layers whole
plate trees. Removing plates preserves surviving slots; new plates use free
gaps, and depth crossings exchange slots locally. Target and mouseover styling
remain active but never promote a farther plate above a closer one. Each rank
has a separate twelve-level band, including its text, cooldowns, count badge and
chat label, so adjacent plates' contents cannot interleave. No world-depth
testing is added: plates still render over terrain and buildings. The existing
100-slot rank budget is unchanged; over-budget scenes share bounded slots.
Render-rate movement updates the existing anchor rather than clearing all its
points first; identity/reference changes still reset it. Settled avoidance
offsets skip spring integration and closure allocation. LOS unit-existence
validation follows the phased 10 Hz raycasts, not every rendered frame.
World-owned projection gaps retain their last depth during the short visibility
grace instead of chaining legacy native projection/position fallbacks.

Routine half-second data refreshes are phased across ten small batches; health,
aura and target events still refresh immediately and never run the same full
data pass twice in one tick. LOS checks retain a 100 ms cadence but use eight
phases to avoid a synchronized raycast spike. Shared player-combat state,
unchanged fonts, layer repair and cluster range geometry avoid redundant work.
Camera projection, distance animation and depth ordering remain synchronized.

Town/crowd updates exclude overlap-allowed labels from the avoidance solver
entirely, while retaining their render-rate world anchors. A mixed scene solves
only the plates that actually need collision avoidance; friendly/hostile families
remain separate. Distance reads use phased 20 Hz floating-point samples, while
whole-plate scale and opacity still interpolate every rendered frame. Unit/API
changes invalidate samples immediately, including failed reads.

Unchanged depth layers use a small root check instead of walking all aura,
cooldown and icon frames. New aura/config changes request an immediate repair;
root/strata changes repair immediately, text drift retains its fast guard, and
phased half-second full audits catch unexpected child-only modifications.
Per-frame unit validation reuses each plate's record instead of allocating a new
table every frame; identity checks and recycled-frame safety are unchanged.
No character settings, visibility rules, nameplate range, or DLL are changed.

Interface click protection uses the client's constant-time top mouse focus,
not a full UI-frame scan every rendered frame. Only ambiguous plate hovers
inspect the underlying frame stack, at most 10 Hz while the focus is unchanged.
Mouse enter, clicks, and right-click actions validate immediately so interface
windows still take precedence. Blocked plates do not repeatedly re-enable their
mouse receiver, and owned mouseovers are cleared. With a known unit GUID,
only the actual target uses the target refresh rate; opaque bystanders no
longer take the target fast path.

With the optional OctoPerf recorder, `/octoperf on` also records narrow zNP
operation spans: native projection/layout, depth/layers, visual/data work,
distance samples, placement/scale writes, LOS, opacity, interface input guards,
and full data refreshes.
The spans are inclusive (do not add them to callback totals), and are inactive
outside a recording. A short stationary town capture followed by
`/octoperf off` and `/reload` saves the breakdown without changing any settings.

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
Chat keeps its configured opacity regardless of nameplate distance, line-of-sight,
inactive-target, or appearance fading, while retaining smooth distance scaling
and the message's own expiry fade. This also applies to chat projected without
a visible player nameplate.
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
When forced self-chat is enabled, your own messages are centred above the
character's head, using the real model name attachment when available. General
left/right placement and chat X/Y offsets continue to apply to other speakers.

## World timers

The **World timers** settings page enables compact markers for your own hunter
traps and flares. Icons come from the game, default to 22 px / 45% opacity, and
have full-opacity outlined countdowns. Icon size/opacity, timer font, world
height and scale are configurable. A subtle gold line means an armed trap;
green means its effect has triggered. Markers never capture mouse input.

zAPI 2.2 discovers only matching player-owned trap/dynamic objects. Their actual
coordinates are locked in world space and reprojected with the camera, without
per-frame object scans or guessed cursor locations. Flare counts down to expiry;
traps count down to despawn, then switch on a confirmed own trigger to the
effect's client-reported duration. Duplicate aura events do not restart it.
Early removal clears single-target trap effects, while leaving a frost patch's
timer intact when a victim exits its slow. Timers clear on world transitions.
When Frost Trap consumes its armed object without a usable trigger event, the
tracker can confirm the owned ice field at that same ground position and keep
the existing icon through the handoff. It uses the field duration, not a victim's
shorter slow, and does not rebind a vanished field to another trap. Markers use
the same WorldFrame-to-UI scale conversion as nameplates, independently of the
icon-size slider.

Only casts observed this session are tracked: a reload cannot recover an old
object's original creation time. Unknown/missing objects and unsupported DLLs
fail closed rather than displaying a fabricated position. Pending discovery
lasts at most three seconds; discovered objects are checked four times per
second, and no discovery/render callback runs while idle.

Trigger payloads and modified spell durations follow the
[Nampower event](https://github.com/brues-code/nampower/blob/main/EVENTS.md) and
[spell API](https://github.com/brues-code/nampower/blob/main/SCRIPTS.md) contracts.

The first time zNameplates loads, it imports only relevant nameplate,
appearance, font, cooldown, and throttle values from an available pfUI saved
configuration. Later changes are stored independently in `zNameplatesDB`.

For MSBT-powered damage attached to visible nameplates, install the separate
`zDNumbers` addon and configure it with `/zdn`.

The extracted nameplate implementation is based on pfUI and retains its MIT
license in `LICENSE-pfUI`.

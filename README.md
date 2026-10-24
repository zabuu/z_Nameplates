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
No character settings, visibility rules or nameplate range are changed.

Version 2.1.4 skips visual work for world-owned overlays after their existing
projection grace expires: no invisible LOS samples, distance animation or layer
repairs. Live projection and ordinary event/data refreshes continue, including
tap ownership used by clustering. Returning plates resume on the next render
with a fresh LOS sample. Overlap-allowed labels also skip unused collision-scale
reads, and settled placement skips elapsed-time integration setup.
zAPI 2.9 speeds up the existing projection batch by sharing successful Windows
memory-region checks only during its native computation phase. Unit/model data
is still read live, with no page views retained across Lua input/output or frames.
The native change requires a full client restart; the Lua changes work with older
DLLs too. Offline fixtures verify reduced work; live FPS needs a new capture.

Version 2.1.5 uses zAPI 3.0's optional batched LOS queries for due real plates.
It shares the player's position/height read and replaces repeated UnitXP bridge
calls with private reusable buffers. UnitXP's shorter-height ray, second head
ray, collision mask, distance guard and 100–160 ms cache-age range are retained;
cache dither is deterministic per GUID. The native cache has 512 fixed slots and
stores no object pointers. Hidden/stale/cluster-hidden units and previews are
excluded. Existing 10 Hz / background-friendly 5 Hz dispatch, immediate sampler
upgrades on interaction, render-rate fades and anchors remain. Missing/unknown
native results or an older DLL use the existing UnitXP provider.

Version 2.1.6 uses zAPI 3.1's combined live validation/projection batch. Each
render checks the token's current GUID and both directions of its native frame
association, then projects from that same unit lookup. The shared validation
record replaces per-plate UnitExists, UnitGUID and GetNamePlateForUnit calls in
the regular and fast visual render paths. A 50-plate fixture eliminates 150 Lua
bridge calls per render while retaining current camera/model reads. Stale slots
fail immediately; current units with temporarily missing models retain the
existing projection grace. The batch is capped at 512, reuses private buffers,
and falls back to Lua validation with older DLLs or failed calls. This is an
offline work reduction; a new capture after a full client restart is needed to
measure the live gain.

OctoPerf 1.7.2 records the loaded zAPI/addon versions and separate timing totals
for frames with native plates present and empty scenes, plus at most 600
one-second windows. These describe observed plate presence; toggle flags and
mixed-toggle seconds are saved alongside them. Existing endpoints are reused
without new timing reads. World transitions and new recordings reset interval
tracking. `zNP sight preparation` includes the native LOS batch, so account for
that stage when comparing LOS work with older captures.
OctoPerf 1.7.3 also saves bounded first/latest native LOS and validation counters
once per observed second, so subsequent captures can separate rays/cache hits
and confirm the combined path ran.

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

## Conservative performance pass (October 17, 2026)

Local pre-change Git checkpoint: `backup/znp-pre-perf-2026-10-17`, commit
`511f5b8589229811fa65c6419e4228103649da84`. The checkpoint was not pushed.

The avoidance solver reuses its ordering comparator and one distance comparator
per placement state. Each comparator reads that state's current position;
hover priority, equal-distance ordering, the 32-neighbor cap, separate collision
families, preview scenes and the solver's existing cadence are unchanged.

Chat caches text measurements, rounded-background geometry, colours and stable
anchors instead of hiding/re-showing and rebuilding unchanged bubbles. Content,
fonts, wrapping, settings, identity/visibility changes and reparenting still
invalidate the necessary properties. Moving projected coordinates, owner scaling,
channel colours, independent opacity and message fade/expiry continue to update.
Player combat queries share the existing timestamp/API cache; combat, player-flag
and entering-world events invalidate it immediately, even within one timestamp.

Mocked-client call counts against that checkpoint (not FPS measurements):

- 40 plates, 20 solves after warm-up: 820 new sort comparators -> 0;
  all 840 projection calls, including warm-up, remain.
- One unchanged bubble, 25 updates: 1,525 UI writes and 50 text measurements -> 0.
- One unchanged forced bubble, 25 updates: 1,800 UI writes -> 0;
  all 25 native projection calls remain.
- 100 combat-colour consumers at one timestamp: 100 player combat reads -> 1.

The regression tests cover dynamic motion and invalidation, not just the warm
case. The profiler-breakdown test also initializes the newer optional recorder's
threshold in its mock; production recorder code is untouched. No visual/native
projection cadence, depth-crossing checks, native suppression, input handling,
world timers, zDNumbers or native DLLs were changed by this pass.

Use `/reload` to load the Lua changes. In-game checks still needed: crowded-town
camera movement/FPS, hovered avoidance and dummy scenes, combat transitions and
chat settings/hidden-player speech. Existing diagnostics attributing particular
mail/gossip hitches to native frame calls are separate; these changes do not prove
those stalls, or other frame drops, have been eliminated.

## Orgrimmar render pass (2.1.1, October 18, 2026)

The October 18 town capture recorded 2,858 ms in the main nameplate callback
across 1,108 calls (2.58 ms/call), peaking at 23 ms with 47 plates visible.
This is a mixed friendly-on/off run, not a measured on/off comparison. Its
largest 648 ms interval instead included a 583 ms MailFrame:Raise operation.

The central render pass now samples common UI/world scale, dimensions and
transition settings once. Its reusable context ends after that pass; independent
chat/preview consumers still read live values even at the same timestamp.
Nameplate cast checks reuse the current frame's validated unit identity and
timestamp, falling back to a live token lookup if the association is absent
or stale. Render-rate projection, distance animation, depth crossings, LOS
cadence, cast events, appearance and settings behavior are unchanged.

Mocked 50-plate render comparison against the preserved 2.1.0 source:

- Common base/effective-scale reads: 300 -> 3.
- All 50 native projections and identity validations remain.
- Fifty subsequent known-identity cast checks: 50 extra GUID reads -> 0.
- Dynamic camera/scale, appearance, offsets, recycled identities and live
  same-timestamp calls outside the context match the prior rendering.

All 28 Python/Lua test scripts pass. These counts are not an FPS claim and do
not establish a fix for the native mail-window stall. Use `/reload`, then record
two short stationary OctoPerf runs from the same camera: friendly plates off,
then on. Keep mail/gossip closed to isolate plate cost. The source and log
backup are under `_pfUIFreezeFix/backups/2026-10-18-org-friendly/` and
`_pfUIFreezeFix/captures/2026-10-18-org-friendly-before.lua` in the AddOns root.

## Batched native projection (2.1.2, zAPI 2.8)

Visible nameplates now submit their validated GUIDs to one reusable native batch
per render pass (up to 512; additional plates keep the single-unit path). Camera
and viewport setup are shared; every plate still gets the same model-name
attachment, native projection and depth every rendered frame, including the
high-FPS visual-only branch. There is no positional interpolation/staggering,
guessed height, native-frame collision anchor, or cached client object pointer
in this change. Existing depth crossing/order, world-distance sampling, smooth
size/opacity animation, input, avoidance, chat and damage-number behavior remain.

The addon probes capability once per API instance. Older DLLs and whole-call
failures retain the old path; individual missing/off-camera model attachments
remain gaps rather than snapping to another height. GUID/token ownership checks,
recycling checks, WorldFrame-to-UI scale conversion, and per-render serials prevent
stale results being reused for another unit or same-timestamp camera pass.

In the 50-plate/122-render mocked camera replay, 6,100 single-unit projection calls
become 122 batches, retaining all 6,100 projections and identity validations.
Native harness results match the unchanged per-unit helper, with one camera and
viewport capture per batch. Ten thousand warm native batches do not grow scratch
capacity; 2,000 warm Lua renders also reuse their buffers without meaningful
allocation growth. These are regression/call-count checks, not in-game FPS data.
The optional recorder labels the new native operation `zNP native anchor batch`.

Pre-change source snapshots are saved locally in both addon repositories as
`backup/pre-projection-batch-2026-10-18` (including the already-pending edits).
The zDNumbers snapshot also stores the exact pre-change game-root DLL at Git path
`native/zAPI/checkpoints/zAPI-installed-pre-projection-batch-2026-10-18.dll`.
No profiles or saved settings were changed. Fully restart WoW for zAPI 2.8, then
compare stationary and camera-moving town scenes from the same location. `/reload`
alone cannot replace the native DLL already loaded into the client.

## Background friendly updates (2.1.3, October 18, 2026)

General now includes **Lighter background friendly plates**, enabled by default.
Outside player combat, non-target, non-hovered friendly plates sample distance
at 10 Hz and line of sight at 5 Hz, instead of 20 Hz / 10 Hz. Size and opacity
continue interpolating, and world anchors/depth continue projecting every
rendered frame. Selecting, hovering (including hover grace), entering combat,
or disabling the option immediately restores the normal sampling policy.
Hostiles and dummy previews retain the normal behavior.

Background friends skip anchor writes below 0.05 screen pixels and scale writes
below 0.00025, while continuous scale integration continues. Targets/hovered
units use the original precision. Normal dimensions, fonts, opacity limits,
cast/aura updates and mouse handling are preserved. Shared blend calculations
also avoid repeating the same exponential for every plate in a frame.

Combo-point widgets and their backdrops are created on first use instead of
for every pooled plate. They still show all five points and honor settings;
unused plates no longer create ten extra native frames each.

All 30 Python/Lua test scripts pass. In the modeled 50-plate / 10-second run:
distance reads 10,050 -> 5,050; LOS reads 5,050 -> 2,550; all 30,050 rendered
anchor updates remain. Blend exponentials drop from 30,000 to at most 600. A small-jitter
anchor case needs one native write over 120 renders, with error bounded to
0.05 px. Fifty unused combo displays avoid 500 native frames. These are call
counts and behavior checks, not measured live FPS gains.

Use `/reload`; no DLL replacement/restart is needed. Compare the same friendly
off/on captures again to measure the actual effect. Source and tests before
this pass are backed up in the AddOns-root maintenance folder
`_pfUIFreezeFix/backups/2026-10-18-background-friendly-2.1.2/`.

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

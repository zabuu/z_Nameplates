# Connected follower vitals

With zBox 0.9.0, each authorized connected follower can show two thin bars
beneath its existing friendly nameplate name: green health and resource-colored
power. Each bar is exactly 2 framebuffer pixels high. Version 2.2.1 uses 70%
of the original width (name width plus 8 pixels), centered under the name,
with a 1-pixel gap and no labels or border. Existing nameplate
visibility and settings are preserved. Stale data, disconnect, revoked pairing
or plate reuse hides the bars.

Optional API: `zNameplates.SetPairedVitalsProvider(function(guid) ... end)` returns
`{health, maxHealth, power, maxPower, powerType}` as named fields for that exact
GUID, or nil. Pass nil to remove the provider and hide bars. zBox owns pairing
and freshness checks. zNameplates owns rendering. No addon messages originate
from this module.

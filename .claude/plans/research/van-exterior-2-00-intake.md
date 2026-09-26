# van-exterior-2 · 00 intake research (in progress)

Ideas in our own words; nothing copied. Sources at the end of each block.

## Cab and front (the missing front)

- **The War Rig recipe (Fury Road):** a stock truck cab (Tatra T815) widened with a second car's rear half, windshield cut down and re-framed, rear-hinged doors, a roll cage inside the cab, the cab pushed to the vehicle's centre. Takeaway for us: the cab is *its own box* bolted to the cargo body, with its own roof line lower than the box, a visible gap or joint between them, and a windshield that is a framed hole with depth, not a pane on a wall. Cage bars over glass read "war rig" instantly. (madmax.fandom.com Tatra T815 page; machinesinaction.com; thefilmbandit.com)
- **Box-truck anatomy:** front = hood (or flat cab-over face), grille opening, bumper bar below, headlights in the fender corners; sides = A-pillar (windshield edge, carries the door hinge), cab door with its own window, B-pillar behind it, then the box. A cab-over (flat-face) truck matches our van-local -Z front better than a hood: the face is one plane with the windshield high and the grille low. (engrary.com truck parts; Wikipedia Pillar (car); summitfleet.com anatomy)

## Windows from outside at night

- Vehicle games give glass two materials: an outer face (reflective, dirt, tint) and an inner face (lighter tint, less dirt), never one two-sided pane. Interior light seen from outside should come from the interior's own lamps through a *tinted* outer pane, with the pane's rim/fresnel doing the "glass" and no emissive on the glass itself. Our bug: the interior pane (albedo with rim recipe, layer 2) is the only pane, so from outside it shows the interior recipe and the interior lamps unfiltered. Fix direction: an exterior pane on layer 1 with a darker tint and strong fresnel, sitting a few cm outside the interior pane within the reveal. (Sollumz vehicle shader docs; Assetto Corsa window material thread)

## Body seams, holes, arches

- Low-poly armoured vehicles read as solid when every panel edge is a real edge with a small bevel or a dark seam line, and wheel arches are cut into the body with a lip, never a wheel floating beside a flat sill. Armour plates sit *on* the skin with visible bolts (our `plate_mode` already does bolts). (CGTrader armoured SUV; ArtStation stylized armoured vehicle)

## Still to research (next round)

- Underside: frame rails, fuel tank, rear bumper/underride, side steps on box trucks.
- Lighting an exterior for inspection vs for play: how night games (Dishonored, Half-Life 2 vans, Fury Road night scenes) let a dark vehicle read: rim light from the environment, emissive markers, wet sheen.
- Precedents for a cab-over war van in games: Crossout cabins, Convoy, Mad Max (2015) Magnum Opus.

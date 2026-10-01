# Arms research (open handout)

## Step 1: the left wrist bump (2026-10-01)

Setup under study: CC0 low-poly arm (about 520 tris), Rigify DEF bones with a forearm twist bone
(DEF-forearm.001), Godot 4 linear blend skinning (LBS) only, and a load-time "inflate" that pushes
each vertex radially away from each bone's axis weighted by bone weight with per-bone gains (twist
bone 2.5, hand 1.7) plus seeded muscle lumps. Symptom: a pointy, localised bump on the outer side of
the relaxed LEFT wrist, seen when looking down.

### 1. LBS artefacts at the wrist, and what makes a POINTY bump

- LBS is `v' = (sum_i w_i T_i) v` with weights summing to 1; blending matrices "lacks closure", so a
  bend or twist adds scale and shear: limbs "pinch or flatten", cross-sections shrink, twists give
  spiral "candy-wrapper" distortion (https://www.emergentmind.com/topics/linear-blend-skinning-lbs).
- Those classic artefacts are smooth: a whole ring collapses or thins together
  (https://www.researchgate.net/figure/The-well-known-candy-wrapper-artefact-of-linear-blend-skinning-Left-The-character_fig2_318590047).
  A pointy single-vertex bump is a weight or displacement discontinuity, not a blending artefact.
- Single-bone vertex: "A vertex needs to be assigned to two or more bones or it will move 100% with
  the bone it is assigned to, regardless of its weight"; the fix is "add a small amount of weight
  from a neighboring bone" and normalise (https://blenderartists.org/t/weight-paint-problem/672422).
- Normalisation gaps: a vertex in only one group "can't normalize properly", so it keeps full
  influence while its neighbours are blended; the engine renormalises per vertex on import, which
  turns a stray 0.1 into 1.0
  (https://blenderartists.org/t/solved-graduated-influence-of-weight-painting-ignored-by-bone/1301786/4).
- Godot keeps 4 or 8 weights per vertex, normalised and rounded so 16-bit weights sum to exactly 1,
  and blends position and normal with one matrix: a pruned or missing weight is redistributed per
  vertex, never smoothed with neighbours
  (https://forum.godotengine.org/t/how-to-get-vert-normal-before-transform-from-skinning-animation-posing-or-how-to-reproduce-same-transforms-in-shader/59881).
- "Stray verts being affected by outside joints" is the named cause of local shearing spikes; the
  rigging fix is Weight Hammer (set the vertex to the mean of its neighbours) and the smooth brush
  "to ease the transition between two joints" (https://www.3dfiggins.com/writeups/paintingWeights/).
- Pruning tiny weights "below a threshold like 0.01" is standard and un-pruned stray weights cause
  "visual artifacts"; both directions bite on a twist bone whose weight is small on most verts
  (https://mocaponline.com/blogs/mocap-news/weight-painting-skinning-guide).
- Twist-bone spike: a vertex with a large twist-bone weight beside vertices on the parent follows the
  rolled bone alone, so a rolled, drooped hand (the relaxed left pose) pulls it sideways on its own
  (https://www.3dfiggins.com/writeups/forearmTwist/).
- Duplicated vertices (UV seam, hard edge) are unwelded in glTF; each copy is "pushed independently
  based on its local face orientation", giving a gap or a spike where the two copies separate
  (https://forum.babylonjs.com/t/vertex-normals-and-positions-split-at-uv-bolder-points-after-displacement-map-applied/37667).

### 2. How FPS viewmodel rigs weight the wrist

- The game-engine twist solution is joint-based: Forearm_1/_2/_3 evenly spaced elbow to wrist,
  weighted "Elbow > Forearm1 > Forearm2 > Forearm 3 > Wrist. All weighted 1 to 1, with slight fading
  to ease the transitions between joints" (https://www.3dfiggins.com/writeups/forearmTwist/).
- Twist joints "spread out the distribution of the rotation value along the entire chain"; without
  them forearm volume is lost "if weighed to the wrist joint or left to sheer if not influenced at
  all" (https://www.3dfiggins.com/writeups/paintingWeights/).
- Commercial FPS arm rigs ship two lowerarm twist bones (lowerarm_twist_01, _02) for the wrist roll
  (https://superhivemarket.com/products/fps-arms-02-rigged); Rigify's single DEF-forearm.001 is the
  one-bone version, so its weight ring is the whole falloff.
- Twist "candy wrapper" is "typically forearms and shins"; the fix is more roll bones, not a heavier
  single one (https://mocaponline.com/blogs/mocap-news/weight-painting-skinning-guide).
- Topology: joints need loops "to fold without collapsing"; a loop that "runs directly over a joint
  line ... will create a sharp crease", so put one loop slightly above and one below the joint
  (https://thundercloud-studio.com/article/topology-for-low-poly-game-characters/).
- "You need two full loops, one weighted to each bone" at a low-poly joint so it clips instead of
  collapsing (https://polycount.com/discussion/84889/low-poly-joints-how-can-i-stop-the-deform).
- On a few-hundred-tri arm there are only 2 or 3 rings across the wrist, so the weight step between
  rings is 0.3 to 0.5: any per-vertex error is a visible facet, and "Even spans mean even weighting"
  means the falloff must be as wide and even as the rings allow
  (https://www.3dfiggins.com/writeups/paintingWeights/).

### 3. Procedural radial displacement on a skinned mesh

- Displacement edits must be "defined in the local frame of reference so they orient correctly as the
  mesh is animated": a push computed in rest pose and then skinned rides the vertex's own weight blend,
  so neighbours with different weight mixes carry their pushes through different rotations
  (https://imagine.inrialpes.fr/people/Francois.Faure/htmlCourses/PoseSpaceDeformation.html).
- A per-bone radial push with per-bone gain is `sum_i w_i * g_i * r_i`: where forearm meets twist
  (2.5) and hand (1.7) the push jumps with the weight mix, so the ring where weights cross shows a
  ridge and a lone vertex with an odd mix shows a point, the same mechanism as a stray weight
  (https://blenderartists.org/t/weight-paint-problem/672422).
- The radial direction `r_i` also differs per bone: at the wrist the forearm axis and the hand axis
  are not collinear, so pushes point different ways, cancelling on some verts and adding on others;
  the fix is one blended axis, or the smoothed vertex normal, per vertex.
- Offsetting along per-vertex normals splits unwelded seam copies: "any seam in the mesh can be a
  source of split. Be it t-junctions, normals, UVs"; fixes are position-based offsets, smooth
  normals and "no t-junctions"
  (https://discussions.unity.com/threads/vertex-offset-splitting-meshes.697373/).
- Post-fix for seams: group coincident vertices, "average their positions after displacement" and
  average their normals, i.e. weld after the push
  (https://forum.babylonjs.com/t/vertex-normals-and-positions-split-at-uv-bolder-points-after-displacement-map-applied/37667).
- Standard fixes in order: equalise gains across the joint (ramp 2.5 to 1.7 along the twist bone,
  not a step at the wrist ring); smooth the scalar push over the one-ring (one Laplacian pass) before
  applying it; apply lumps (brachioradialis at t 0.22, angle 20 deg) in bone-local space and give
  seam copies the same push; prune then renormalise weights before using them as gains, so the
  inflate and the engine agree on every vertex's mix.

### 4. What a diagnostic should measure (summary)

Load the mesh once, run the same inflate, and for every vertex record its push vector, its weight
list and its one-ring neighbours (merged by position so seam copies share a ring). A spike is a
vertex whose push magnitude or direction differs from its one-ring mean by more than a threshold
(start at 2x the ring's standard deviation, or 3 mm absolute); also report any vertex whose weights do
not sum to 1 before Godot's renormalisation, any single-bone vertex, any vertex whose dominant bone is
not the dominant bone of most of its ring, and any seam-duplicated pair whose pushes differ. Print the
worst ten with bone names and bone-local t along the forearm so the lump rows can be checked.

### What the diagnostic measures

- Per vertex: push magnitude and direction vs the one-ring mean (position-merged ring); flag |d - mean| > k*sigma.
- Per vertex: weight sum before normalisation, bone count, largest weight and its bone, prune residue < 0.01.
- Per vertex: dominant bone vs the majority dominant bone of its ring (a lone twist-bone or hand-bone vertex).
- Per vertex: twist-bone weight vs the mean twist-bone weight of its ring (large delta = roll spike).
- Per seam pair (same position, different index): push delta and normal delta; any nonzero delta is a tear.
- Per lump: the vertices it touched, their t along the bone and the max push it added, to see if a lump row lands on the wrist ring.
- Per ring across the wrist (bucket by t along DEF-forearm.001 and DEF-hand): mean and max push, so a gain step shows as a ring ridge rather than a point.

### Step 1 findings (measured, 2026-10-01)

Diagnostic: `C:/Users/Traff/AppData/Local/Temp/claude/vg-diag/wrist.gd` (headless, builds the real
left arm with `ArmsBuilder.build` for seeds 0,1,2,3,12345, measures original / inflated / posed
positions per vertex, one-ring merged by position). Mesh: 369 verts, 520 tris, mean edge 0.052,
forearm head to hand head 0.505. Weights all sum to 1; no seam copy splits after inflate.

1. **The point** is vertex 10 (copies 15, 24) at t 0.95 along the forearm, angle 178 deg from the
   thumb (ulnar-dorsal edge, the side the player sees on the hanging left hand). It is already the
   sharpest vertex in the source mesh (Laplacian 0.13 = 2.5 edges, a modelled wrist bone with a
   3-vertex ring). It is 0.89 on `DEF-forearm.L.001` (gain 2.5, radial ratio 2.3 to 2.6) while its
   ring is hand-weighted (ratio 1.45), so its push differs from the ring mean by 1.06 to 1.28 mean
   edge lengths, the largest outlier on the arm; posed Laplacian 0.15 (2.9 edges).
2. **The ring step**: the last forearm ring (t 0.95, 19 verts) is inflated 2.3 to 2.6x in radius,
   the first hand ring (t 1.0) 1.45x and t 1.1 1.23x. That is the "fat forearm open end" ridge.
3. **Family bug** (`arm_muscle.gd` `_family`): bind names are `DEF-forearm.L.001` and
   `DEF-upper_arm.L.001` (side before `.001`). `_family` strips `.001` and leaves `DEF-forearm.L`,
   which matches no lump table and gets vein MASK 0. So every twist-dominated vertex (the wrist
   half of the forearm, the lower half of the upper arm, where the biceps row t 0.55 sits) gets no
   lump and no veins, and the flexor/extensor tails stop dead at t about 0.5 (outliers v142/v157,
   t 0.57, 0.8 to 1.05 edges).

Fixes chosen (spec `.claude/specs/1.md`): `_family` strips `.001` before the side suffix too;
`ArmBulk.inflate` ramps the forearm twist gain from `FOREARM_WRIST_GAIN` at half the twist bone to
the hand gain at the wrist (research section 3: ramp, do not step). Re-run the diagnostic after:
expect v10's push outlier under 0.4 edges and the t 0.9 / t 1.0 radial ratios within 0.3.

### Step 1 results (measured, 2026-10-01, seeds 0,1,2,3,12345)

Both fixes landed (`_family` strips `.001` before the side suffix; the forearm twist gain ramps
from `WRIST_RAMP_START` 0.5 to the hand gain). Diagnostic before / after:

| measure | before | after spec 1 | after + push smoothing (reverted) |
|---|---|---|---|
| v10 push outlier vs its one-ring | 1.06 to 1.28 e | 0.67 to 0.89 e | 0.71 to 0.89 e |
| v10 posed Laplacian | 0.15 (2.9 e) | 0.14 (2.7 e) | 0.14 |
| t 0.9 ring radial ratio | 2.3 to 2.6 | 1.76 to 1.92 | 1.90 |
| t 1.0 ring radial ratio | 1.45 | 1.36 to 1.44 | 1.40 |
| ring step t 0.9 minus t 1.0 | about 1.0 | 0.40 to 0.48 | 0.50 |
| v142/v157 (t 0.57) outlier | 0.8 to 1.05 e | 0.71 to 0.92 e | 0.63 to 0.87 e |

Neither target (outlier under 0.4 e, ring step under 0.3) is met, and the reasons are now in the
mesh, not the gains:

1. **The styloid is modelled.** v10's source Laplacian is 0.13 (2.5 mean edges) with a 3-vertex
   ring; posed it is 0.14. The inflate only scales a point the source already has. No gain change
   or push smoothing moves it (push smoothing changed v10's push 0.0463 to 0.0453).
2. **No ring between t 0.6 and t 0.9.** The forearm's last two rings are at t 0.57 (9 verts,
   push 0.09) and t 0.95 (19 verts). Any gain ramp between them is a single step across one edge
   span, and a one-ring Laplacian pass on the push magnitude (tried as spec 2, lambda 0.5) pulled
   the t 0.95 ring toward the fat t 0.57 ring: ring mean push 0.037 to 0.043, ring step 0.40 to
   0.50. Reverted; nothing of it is in the tree.
3. The ramp's target is the hand bone's gain (1.7 x bulk), but the first hand ring measures 1.36
   to 1.44 because its vertices mix palm (1.6) and finger (1.5) weights; so even a perfect ramp
   leaves about 0.3 at the wrist unless the ramp aims at the measured hand-ring ratio.

Conclusion: the remaining wrist faults need vertices (a ring in the gap, a rounder styloid) or a
different approach, which is what Step 2 reviews.

## Step 2: approach review (research, 2026-10-01)

### Findings

**a. Shape keys versus runtime inflation.** Godot imports glTF shape keys as `MeshInstance3D` blend
shapes (set by index or name), mixed before the skin; export needs "Deformation Bones Only"
(https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).
`ArrayMesh.add_blend_shape` exists but runtime blend shapes have open 4.x bugs
(https://github.com/godotengine/godot/issues/63198). Keys are fixed hand-authored offsets: good for a
few corrective shapes (wrist twist), wrong for continuous seeded bulk and lumps, which stay in code
on top of the rest mesh.

**b. Subdividing before displacing.** Godot 4 core has no runtime subdivision; the OpenSubdiv proposal
is still open (https://github.com/godotengine/godot-proposals/issues/784). `MeshDataTool` edits existing
vertices (bones and weights kept), is slower than raw arrays and is not meant for adding vertices
(https://docs.godotengine.org/en/stable/tutorials/3d/procedural_geometry/meshdatatool.html);
`generate_lods` only removes triangles; `SurfaceTool` can write bones and weights. The addon
godot-subdiv (GDExtension, Loop for triangles, skinning and blend shapes on CPU, badge says 4.2) works
but is a native build for 4.7 (https://github.com/tefusion/godot-subdiv), heavy for 369 verts. A GDScript
midpoint pass is small: one split per edge (about 780) gives about 1150 verts and 2080 tris, once at
load; new vertex = mean of the two endpoints for position, UV, CUSTOM0, and weights (union of bones,
normalise, keep top 4); edges keyed by position so seam copies split alike. Loop also smooths the old
vertices and shrinks the shape (the gains absorb that). Blender "Simple" only subdivides, Catmull-Clark
also smooths (https://docs.blender.org/manual/en/2.81/modeling/modifiers/generate/subdivision_surface.html);
an applied modifier exports new vertices with bone weights averaged from the base vertices, and the
proposal #784 author saw animation artefacts from smoothing before skinning.

**c. Muscle by shading.** Stylised practice: "a character's muscular definition comes from normal maps,
not individual muscle topology", with painted AO and vertex colours
(https://80.lv/articles/004adk-talking-about-stylized-character-art); Overwatch-style assets read as hand
painted over light PBR (https://polycount.com/discussion/178211/how-to-achieve-overwatch-style-textures).
No viewmodel-specific source found. A bake-free version builds the normal in the fragment shader from
the analytic derivatives of a height function, `NORMAL = cross(TANGENT + NORMAL*d.x, BINORMAL - NORMAL*d.y)`
(https://catlikecoding.com/godot/procedural-gpu-patterns/08-value-noise-derivatives/), with the bone-local
lump table as the height and dark AO bands between muscles. It fixes the lump look, not the silhouette.

**d. Wrist join.** Joints want two loops, "one weighted to each bone", none on the joint line
(https://polycount.com/discussion/84889/low-poly-joints-how-can-i-stop-the-deform). Taper comes from
scaling the wrist loop in while "keeping the same amount of loops all the way down the arm", and extra
loops along the twist span cut volume loss (https://polycount.com/discussion/161450/help-with-topology).
A gain ramp needs rings to ramp over: our empty t 0.6 to 0.9 is the missing pair. Stylised low-poly arms
normally leave the styloid out (flat or rounded cuff); that page was blocked for me, taken from its
search summary (https://www.tripo3d.ai/blog/explore/smart-mesh-topology-for-hands-fingers-low-poly).

### Options

1. **Runtime midpoint subdivision, then relax the styloid.** New load-time helper before
   `ArmBulk.inflate` splits every edge once (weights, UVs, CUSTOM0 averaged), then sets the 3-vertex
   styloid ring to the mean of its neighbours in rest pose. Code only. Fixes 1 (new rings at t 0.6
   to 0.9, so the gain ramp is a curve), 2 (spike removed before inflation), 3 in part (4x the
   vertices to shape a lump). Risk: seam copies must split identically, tris x4 (cheap), and every
   per-bone constant and diagnostic number shifts and needs one re-tune.
2. **Shader-side muscle on the current mesh.** Drop the vertex lumps, evaluate the same bone-local
   lump table per pixel as a height function, perturb the normal analytically, add dark AO bands, keep
   a plain smooth gain ramp. Code only (shader plus the CUSTOM0 frame). Fixes 3 fully; 1 only
   partly (fewer features, but the step stays); 2 not at all (the spike is silhouette). Risk: near-black
   night light may make normal-only definition read flat; lumps vanish from the outline.
3. **Re-export from Blender with one Simple subdivision, a wrist loop pair and no styloid.** Hand work
   by the owner: add loops at t 0.7 and 0.85, delete or round the styloid, apply a Simple
   level on the rigged mesh, hammer the wrist weights, export deformation bones only. Fixes 1, 2 and
   3 at the source, as the references teach. Risk: blocks on the owner's time, exporter weights need
   re-checking, and the new mesh invalidates every measurement, seed table and CUSTOM0 frame.

### Recommendation

Option 1. It is code only and is the one option that gives the gain ramp the rings it needs (problem 1)
and removes the styloid before inflation (problem 2), while the extra vertices also make lumps readable
(problem 3). If lumps still read as bumps afterwards, add Option 2's per-pixel bump as a second step,
on a mesh that no longer has the step or the spike.

### Decision (owner, 2026-10-01)

Option 1: runtime midpoint subdivision once at load, then relax the styloid, before `ArmBulk.inflate`'s gain pass.

## Step 3: hands (research, 2026-10-01)

# Step 3: hand proportion research (a, b, c, Numbers)

Evidence is thin on hard ratios; artist sources give rules of thumb, anthropometry gives measured means.
"Fetched" = page text read; "snippet" = only a search-result summary was seen.

### a. Proportions
- Middle finger length = palm length (realistic). Fetched: https://tips.clip-studio.com/en-us/articles/6936 and https://tips.clip-studio.com/en-us/articles/8210
- Hand = palm half, fingers half; knuckles sit at half of wrist-to-middle-fingertip. Fetched: https://tips.clip-studio.com/en-us/articles/8225
- Measured (US Army ANSUR II, male+female): hand length 189.3 mm, palm length 113.9 (0.60 of hand), hand breadth 85, wrist circumference 169. Fetched: https://www.sota2.com/research/sota/hand-anthropometry-on-ansur-ii-combined-male-and-female
- Male-only means (one survey, snippet): breadth at metacarpals 78.4 mm, wrist breadth 56.3 mm, so wrist:palm width about 0.72 (0.66 using ANSUR's 85). https://www.matec-conferences.org/articles/matecconf/pdf/2017/33/matecconf_imeti2017_01044.pdf
- Artist rule: "palm and wrist equal in width, minus the thinner area where they meet"; palm width about equal to finger length. Snippets: https://www.tumblr.com/undergroundwubwubmaster/178553396532/please-explain-your-hand-to-arm-ratio-its and https://www.how-to-art.com/en/draw-people/how-to-draw-hands/
- Thenar: "the thumb muscle makes up a quarter of the palm" (snippet, same Clip Studio family). Bridgman: the hand has two masses, the hand proper and the thumb, and the thumb mass dominates, its ball facing front. http://www.artgraphica.net/free-art-lessons/constructive-anatomy-george-bridgman/anatomy-art-book-drawing-hands.html (snippet; fetch failed)
- Hand size vs head: realistic = chin to mid-forehead (about 3/4 head), https://tips.clip-studio.com/en-us/articles/6936. Anime heroine 1/2 head, shounen 3/5 to 3/4, ikemen 3/4, small/cute = large round palm with short fingers. Fetched: https://animeartmagazine.com/lets-talk-hand-head-ratio-how-does-the-size-of-a-characters-hands-change-depending-on-genre/
- Heroic: TF2 Heavy has "huge hands" with the arms made longer and the hips low so they still read proportional (snippet, fan blog, no numbers): https://jessiedoodles.tumblr.com/post/92091412678/tf2-character-design-heavy
- Overwatch/Fortnite, Valorant, Borderlands hand ratios: no source found. One pipeline note: do not "improve" the exaggeration back toward correctness. https://discover.therookies.co/2024/10/07/developing-a-character-concept/ (snippet)

### b. Where mass sits
- Knuckles are the metacarpal heads, the widest rounded point of the finger zone; "all bones are narrower in the shaft than at either end, especially the fingers". Fingers taper from the middle joint toward the nail. Fetched: https://chestofbooks.com/arts/drawing/Anatomy/The-Fingers-Anatomy-Masses-Movements-Fingers-Creases.html (Bridgman text)
- The back of the hand is wedges and squares, a blunt wedge entering the knuckle square (same page). The second knuckle is larger and higher than the rest (snippet, https://en.wikipedia.org/wiki/Metacarpal_bones).
- Wrist: oblong, wider than deep; flexor tendons set its width (Bridgman, snippet). Numeric width:depth: no artist source found; ANSUR gives only circumference.
- Forearm: tapered cylinder/box; brachioradialis mass is a diagonal bulge near the elbow, with a gradual (soft) edge to the wrist, hard edge only at the ulna head. Snippet: https://www.artistsnetwork.com/art-mediums/drawing/drawing-basics-understanding-anatomy-of-the-arm/ . No flare ratio found.
- Thenar and hypothenar pads give the palm "weight"; palm is a rigid spade volume, not a plane (snippet): https://www.creativebloq.com/3d-world/how-sculpt-detailed-3d-hand-21410804

### c. What a radial per-bone gain does
- No source found on skinned radial scaling itself; this is inference. Each finger is pushed from its own axis, so finger spacing stays real-size while thickness x1.5: neighbours overlap into a mitten/sausage.
- Stylised practice found: beefy hands = "meatballs not sausages", extra width at the knuckles, tapered cylinders per phalanx, knuckle bones bigger. Snippets: https://www.clipstudio.net/how-to-draw/archives/156336 , https://www.creativebloq.com/3d-world/how-sculpt-detailed-3d-hand-21410804 . Exaggerating taper reads as cartoon strength.
- So: scale the root (proximal, by the knuckle) most, tip least; thicken palm and thenar, not finger shafts.

### Numbers
Real wrist:palm width is about 0.66 to 0.72 (sources above). With radial gains the width ratio becomes real ratio x wrist gain / palm gain.

| Part | Gain now | Implied vs reference | Proposed | Reason |
|---|---|---|---|---|
| Forearm at wrist | 2.5 | wrist:palm = 0.66 x 2.5 / 1.6 = 1.03 (wrist as wide as palm; artist rule "equal minus the join" is the ceiling) | 2.1 | Target wrist:palm about 0.75-0.8 so the wrist reads strong but the hand is the big end |
| DEF-hand (wrist to palm) | 1.7 | 1.7/2.1 = 0.81 against forearm end | 1.9 | Ramp forearm 2.8 elbow to 2.1 wrist to hand 1.9: no step |
| DEF-palm.01-04 | 1.6 | palm 85 mm real; ok base | 1.7 | Palm should out-width the wrist (above); .01 and .04 (outer) 1.8 for hypothenar |
| Knuckle row (metacarpal head end of palm, or palm.* vertices near the finger root) | none | knuckles are the widest point (Bridgman) | extra x1.15 on palm gain there | Knuckle mass is the heroic read; no ratio source |
| Fingers root / mid / tip (.01/.02/.03) | 1.5 flat | uniform = sausage; spacing fixed so 1.5 overlaps | 1.35 / 1.2 / 1.1 | Taper, meatball root; keeps gaps between fingers |
| Thumb .01 / .02 / .03 | 1.55 flat | thenar is about 1/4 of palm, thumb mass dominates (snippets) | 1.9 / 1.4 / 1.15 | Fat thenar base, tapered thumb |

Unverified: all proposed values are derived from the ratio arithmetic above plus judgement, not from a source; tune by eye in the shots.
Caveat: hand 1.7 -> 1.9 raises the palm/wrist ring; check the finger-root loops do not intersect at the 1300-vert subdivision.

## Step 4: veins (research, 2026-10-01)

# Step 4: raised, soft veins (research)
Shader: scenes/player/arm_surface.gdshader (worktree game-arms-weapon-visuals-c13029). Web sources fetched 2026-10-01; where a source gave nothing, it is marked "derived".

### Current vein lines (quoted)
- L40-52 vein_field: `float r = abs(noise21(q) * 2.0 - 1.0);` then `sum += ws * (1.0 - smoothstep(vein_width * 0.5, vein_width, r));` (vein_width 0.07, L29)
- L69-73: `vn = vein_field(vein_data) * vein_strength; vn *= 1.0 - smoothstep(0.3 / vein_around_m, 0.8 / vein_around_m, fw); col = mix(col, vein_color, vn * 0.6);`
- L11 `vein_color = vec3(0.12, 0.17, 0.18)` (comment L10: "Darker than the skin base so veins never brighten the albedo")
- L86 `ROUGHNESS = clamp(roughness_value - 0.04*(grain-0.5) - 0.05*vn, 0.78, 0.95)`
- L88-100: `h = vn * vein_bump * 0.01` (0.6 * 0.01 = 0.006), `hx = dFdx(h)`, `hy = dFdy(h)`, `NORMAL = normalize(abs(det)*NORMAL - grad)` (Mikkelsen-style, no tangents needed).

### a. How raised veins are shaded
- Real veins: 2-4 mm visible diameter, best seen at 0.5-1.0 mm depth; they look "darker and more bluish" because red is absorbed and blue/green scatters back (phantom study https://pmc.ncbi.nlm.nih.gov/articles/PMC12904536/; why-blue summary https://www.scienceabc.com/humans/if-blood-is-red-why-do-veins-appear-blue-through-the-skin). So the hue goes cool/blue-green; it is a hue shift, not a black line.
- Basilic lumen about 6.5 mm in an adult male forearm, cephalic 2-3 mm (https://pmc.ncbi.nlm.nih.gov/articles/PMC8606620/, https://en.wikipedia.org/wiki/Basilic_vein). Ratio (derived, my assumption of a 60-80 mm wide forearm): real 3-6% of forearm width; a muscular stylised arm is exaggerated to about 8-10% for main veins, branches 50-60% of that. No game source states a ratio.
- Sculpt practice: veins are inflated, soft-falloff tubes; "a softer falloff can create subtle veins, while a harder falloff will produce more pronounced lines" (https://novedge.com/blogs/design-news/zbrush-tip-mastering-the-inflate-brush-for-realistic-vein-detailing-in-zbrush-models). Normal/displacement veins are a cheat that works under most light (https://www.daz3d.com/forums/discussion/518511/thick-blood-vessels-on-characters). Vein maps ship as diffuse+normal+displacement+AO sets, i.e. colour and height together (https://www.filterforge.com/filters/438-normal.html).
- Branching: Y-forks that merge back toward the wrist, tapering; main trunk along the arm axis with side branches at 20-40 degrees (derived from anatomy references; no fetched source gave angles). The existing fbm wiggle (L47) suits this.
- Normal source options: painted normal map (needs UVs/tangents), procedural ridge from a 1D profile (this shader), vertex displacement (true silhouette, needs mesh density; low-poly arm has none). Procedural is right here.

### b. Procedural ridge maths
- Profile, d = signed distance to vein centre, t = clamp(|d|/w, 0, 1): `h = (1 - t*t)^2` (C1 at centre and edge; same family as `(1 - smoothstep(0,w,|d|))^2`). Slope `dh/d|d| = -4 t (1 - t^2) / w`; steepest at t = 0.577 where |slope| = 1.54 / w * H (H = peak height).
- Tilt rule (Blinn bump): `N' ~ N - (dh/du) T - (dh/dv) B` ; Mikkelsen: `T_p = T + dh/du N`, `B_p = B + dh/dv N`, `N_p = T_p x B_p`, expanded `(T x B) + dh/du (N x B) + dh/dv (T x N)` (https://zero-radiance.github.io/post/surface-gradient/; paper https://mmikk.github.io/papers3d/mm_sfgrad_bump.pdf). This is exactly L95-99, so the method is right; the height field is the problem.
- Pitfall: dFdx/dFdy(h) are constant per 2x2 pixel quad, so a profile narrower than about 6-8 px gives blocky, hard-edged shading. Better: build the across direction from CUSTOM0's local frame and tilt along it with the analytic slope (derived).
- Godot: `NORMAL_MAP` = "Set normal here in tangent space if reading normal from a texture instead of NORMAL"; `NORMAL_MAP_DEPTH` = "Depth from NORMAL_MAP. Defaults to 1.0"; blue is ignored/reconstructed (https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html). It uses mesh TANGENT/BINORMAL; ArrayMesh without ARRAY_TANGENT triggers "shader that requires tangents with a mesh that doesn't contain tangents" (https://github.com/godotengine/godot/issues/84875; fix: add ARRAY_TANGENT or SurfaceTool.generate_tangents, https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/procedural_geometry/arraymesh.rst). Docs do not say what happens with none, so for a procedural mesh bend `NORMAL` directly (view space, inout) as the shader already does; do not set NORMAL_MAP.

### c. Why a normal-only ridge vanishes in the dark
- Shading is albedo x light x N.L; with near-black ambient and one warm lamp, a normal tilt changes brightness only where the lamp reaches, and by a few percent at low tilt. Artists add: albedo/cavity variation multiplied into the colour (https://polycount.com/discussion/177467/problem-with-specular-in-unreal-engine-4 , https://texturemap.app/texture-mapping), fresnel rim (https://dev.epicgames.com/documentation/en-us/unreal-engine/using-fresnel-in-your-unreal-engine-materials), and lower roughness so the lamp glints. Flat frontal light erases texture; raking light and specular define it (https://www.tripo3d.ai/blog/explore/hd-model-lighting-setups-that-reveal-surface-detail).
- Art rule fit: no emission; use albedo lift, roughness drop, SPECULAR bump, all of which only react to real lamps.

### Proposed look
- Width: main vein full width 0.09 x forearm width (half-width w = 0.045 FW); branches 0.05. Real veins are 3-6%, exaggerated for muscle; must span at least 8 px at hold distance or the quad derivatives block up.
- Profile: `h = (1 - t*t)^2` with t = |d|/w (soft, no flat plateau; the current `1 - smoothstep(0.5w, w, r)` has a flat core and steep walls = a cut).
- Height: peak H = 0.4 w = 0.018 FW (about 1.2 mm on a 70 mm forearm) which gives max flank tilt of about 33 degrees (tan = 1.54 H / w = 0.62); real veins stand 0.5-1 mm, stylised 1.2-1.5 mm.
- Highlight / shadow: lit flank brighter and far flank darker by up to +15% / -20% albedo, taken from the tilt slope dotted with the lamp direction in view space (a faint fake of N.L that survives low ambient).
- Albedo: no dark mix. Ridge colour `skin * vec3(0.90, 1.00, 1.04)` (cool, greenish-blue, per the phantom study), luminance 1.00 to 1.06 x skin at the crest, blended with `h * 0.5` weight. The current 0.12/0.17/0.18 at 0.6 weight is 3-4x darker than skin.
- Specular: `ROUGHNESS` down by 0.25 x h (0.88 to about 0.63 at crest) and `SPECULAR` up from 0.5 to 0.7 x h, so the warm lamp catches the crown; fresnel does the rest at grazing angles.
- Edge: keep the L72 fw fade but start it at 0.8 px-per-vein-width, not 0.3/6 m, so the wide ridges are never faded away.

### Why the current veins read as cracks
- L48-49: `abs(noise*2-1)` makes a V at the noise zero-crossing, a single thin curve; the `smoothstep(0.5w, w)` falloff gives a plateau with steep sides (a cut, not a bulge); w = 0.07 in noise units is a narrow band.
- L73: the albedo is mixed 60% toward near-black `vein_color` (L11), so the dominant cue is a dark line, and nothing lifts the ridge.
- L88-100: height is 0.006 units from the same steep-sided field, derived with per-quad dFdx/dFdy, so the tilt exists only on a 1-2 px wall: a dark line with a hairline glint, the look of an incision.

## Step 5: subdivision landed (measured, 2026-10-01)

`ArmRefine.refine` (new, called first thing in `ArmBulk.inflate`'s surface loop) midpoint-subdivides
the arm once: 369 verts / 520 tris become 1250 / 2080, mean edge 0.0536 to 0.0264; bones and
weights merged (top 4, renormalised), normals and UVs averaged, tangents dropped (ArmMuscle nulls
them anyway). The diagnostic (`a0 = ArmRefine.refine(a0)` added to `vg-diag/wrist.gd`) now sees a
ring at t 0.7 (ratio 2.35) between the t 0.5 ring (2.49) and the wrist ring (1.68), the first hand
ring is 1.34, so the ramp is a curve of 2.49 / 2.35 / 1.68 / 1.34 instead of 2.49 / 1.76 / 1.36.
v10's posed Laplacian halved in absolute terms (0.140 to 0.070); the largest push outlier fell from
0.035 to 0.025 absolute.

**The relax-the-styloid half of option 1 was dropped, measured wrong:** merged by position, v10
(rep v2) has a 7-vertex ring and sits only 0.76 mean edges from its mean; the 2.5-edge figure in
Step 1 was v10's own 3-triangle seam fan. The only vertices over 1.8 edges are the eight vertices
of the shoulder's open boundary ring (v0..v9 bar v2 and v5, at z -0.732), which a relax would pull
inward. So there is no modelled spike to round; what is left at the wrist is the ring step (0.34)
and the lumps' edge, which the hands step (gains aimed at the measured hand-ring ratio 1.34, not the
hand bone's 1.7) and the vein pass address.

Shots `vg-arms8` vs `vg-arms7`: a01..a06 within tolerance (diff 0.34 to 0.92 of 1.0), the cabin
views that show the arms changed slightly. `a03-arms-left`: the forearm reads as one smooth
bulbous mass with a crease at the wrist; the veins are thin dark jagged cuts (Step 4's finding).

## Step 4 landed: raised soft veins (measured, 2026-10-02)
Shader rebuilt per "Proposed look": two layers per projection (main full width 0.022 mesh units,
branches 0.55 of it at 0.6 height), true distance to the noise zero crossing via
`abs(v) * fw / fwidth(v)`, profile `(1-t^2)^2`, normal tilt from the analytic slope times
`dFdx(t)` (height 0.0008 view m), crest albedo skin x (0.90,1.00,1.04) x 1.06 at `vn*0.5`, a
painted crown highlight from a fixed view-space key (+15 % / -20 %), ROUGHNESS -0.25*vn (floor
0.60), SPECULAR 0.5+0.2*vn, no dark mix, no emission. Measured forearm radius in the source mesh
(right arm, around DEF-forearm.R): t 0.5 mean 0.062, t 0.9 mean 0.049 (max 0.062), length 0.505;
inflated width about 0.25. Shots vg-arms8 (before) vs vg-arms9 (after): all six arms views under
the compare tolerance (mean diff 0.19-0.52 of 1.0); pixels moved by more than 8 levels: a01 0.8 %,
a03 0.8 %, a05 1.9 %, mean luminance unchanged. Read a05 once: soft lighter ridges along the
forearms, no dark lines. Open: whether the owner wants them stronger (raise `vein_height` or the
crest weight 0.5), and the key direction is a painted cue, not the arm lamp.

## Step 3 landed: hands, knuckles, wrist ramp aimed at the hand ring (measured, 2026-10-02)

`scripts/player/arms/arm_bulk.gd` (115 to 186 lines). Gains now: forearm 2.8 at the elbow ramping
linearly along the elbow-half bone to `FOREARM_WRIST_GAIN` 2.1 (was 2.5) at the twist-half head
(new `elbow_len`), twist half flat 2.1 then the existing ramp from `WRIST_RAMP_START` 0.5 to a new
`WRIST_END_GAIN` 1.5 (the measured first hand ring 1.34 scaled by 1.9/1.7) instead of the hand
bone's nominal gain; hand 1.9; palm 1.7 with the outer palms `.01`/`.04` 1.8 and a knuckle boost
(`KNUCKLE_GAIN` 1.15 on the raw palm gain, ramped over the knuckle half of each palm bone, bone
length taken from the matching finger `.01` head, `PALM_FINGERS` index to pinky); fingers
1.35 / 1.2 / 1.1 root to tip (`_raw_gain` reads `.02.` and `.03.`); thumb 1.9 / 1.4 / 1.15.
`_gain_for` is now `_bulked(_raw_gain(name), bulk)`.

Wrist diagnostic, seed 0 (`vg-diag/wrist.gd`; `wrist_wide.gd` is the same with the band opened to
t 0.05 so the elbow half shows), mean radial ratio per ring, before / after:

| t | 0.0 | 0.1 | 0.2 | 0.3 | 0.5 | 0.7 | 0.9 | 1.0 | 1.1 | 1.2 | 1.3 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| before | - | - | - | - | 2.49 | 2.35 | 1.68 | 1.34 | 1.22 | 1.09 | 1.11 |
| after | 2.72 | 2.80 | 2.99 | 2.41 | 2.10 | 2.00 | 1.54 | 1.43 | 1.29 | 1.14 | 1.13 |

Targets met: the wrist ring step (t 0.9 minus t 1.0) is 0.11, was 0.34 (target under 0.3); the
largest push outlier in the wrist band is 0.019 absolute, was 0.025 (target under 0.03). The first
hand ring rose from 1.34 to 1.43 and the knuckle rings (t 1.2, 1.3) from 1.09/1.11 to 1.14/1.13,
so the hand is now the wide end of the wrist. The first cut (wrist gain 2.1 with the elbow half
still flat 2.8) measured a 0.57 step at the twist boundary (2.68 to 2.11), which is why the
elbow-half ramp was added in the same step; with it the boundary step is 0.31 (2.41 to 2.10). The
t 0.2 ring (7 verts, ratio 2.99, push outliers 1.7-1.8 e) is the proximal muscle-lump row from
`ArmMuscle`, unchanged in kind by this step and outside the wrist band.

Shots `vg-arms10` vs `vg-arms9`: `a05-arms-down` and `a06-arms-reload` changed (1.39 and 1.13 of
1.0), `a01`..`a04` within tolerance; the cabin views that frame the arms (`01-idle-front`, the
back and stop views, `v04-idle-front-wall`) changed as before. `a05-arms-down`, read once: both
hands read as broad flat mitts with a palm wider than the wrist, the fingers keep their gaps and
taper to the claws, and the forearm no longer bulges past the hand.

Unverified: the thumb thenar (1.9) and the knuckle boost are not isolated by any diagnostic; tune
by eye in `a05`/`a06`. Open: the mid-forearm step of 0.31 could go lower by starting the elbow
ramp at the proximal lump row instead of the bone head, if it reads as a crease in the shots.

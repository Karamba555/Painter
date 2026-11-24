# AR Trace: device acceptance test

Status: implemented prototype, **not validated on physical hardware yet**. Simulator build/tests cannot prove anchoring quality.

## Implemented anchoring method

RealityKit `ARView` renders a transparent outline on a horizontal mesh. ARKit detects a horizontal surface; a tap uses an `existingPlaneGeometry` raycast and creates an AR anchor at the intersection. Width is adjustable from 5 to 35 cm. The anchor belongs to the table/world, **not to the paper**. This method does not use a printed visual marker and does not follow a moved sheet.

Limited tracking or an interrupted session hides the outline, unlocks placement, and requires explicit realignment. This avoids presenting an uncertain overlay as still aligned. AR placement is intentionally not persisted between launches; width, angle and opacity are restored, but the user places a new anchor.

## Physical test

Use an older supported iPhone without LiDAR and, if available, a newer iPhone/iPad. Place an ordinary A4 sheet on (a) a textured desk and (b) a plain table. Make small pencil marks at three points on the outline.

1. Scan the table, tap the sheet, set width and rotation, then lock.
2. With the sheet still, slowly move the phone 5–15 cm and tilt about 10–20 degrees. Measure outline-to-pencil drift at the three points.
3. Repeat while a drawing hand covers 25%, then 50% of the paper, keeping some table visible.
4. Test dim light, a fast phone movement, temporary camera occlusion, background/foreground and a camera interruption.
5. Confirm the outline hides on loss of tracking, the instruction is understandable, and Realign starts a new placement.
6. Move only the sheet to confirm the UI does not imply that the outline follows it.
7. Finish a drawing, capture its photo, open the saved project and verify that AR asks for new placement.

Record device/iOS, lighting, scan time, drift, tracking-loss frequency and relocalization behavior. Suggested go/no-go target for a tracing prototype: no visible jumps and drift under roughly 2–3 mm during a slow angle change. Treat this as a product acceptance target, not measured performance.

If ordinary-paper tests fail, compare a visible image marker before finalizing onboarding demonstrations or claiming stable surface anchoring. The bundled animation is a conceptual illustration, not evidence of tracking performance.

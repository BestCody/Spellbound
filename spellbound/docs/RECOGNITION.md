# Motion recognition

## Actual implementation

This is a small template recognizer plus conservative fallback rules, not a neural model. It uses only the accelerometer. It does not reconstruct hand paths, perform SLAM, understand arbitrary signs, or infer full-body pose.

A hold of A defines the capture window. Samples are polled no faster than every 20 ms. Each raw sample takes five bytes: two bytes of elapsed milliseconds and three quantized acceleration bytes (32 mg per step). A maximum capture is approximately 605 bytes; capture strings are temporary and are not broadcast or saved.

At release, the code rejects missing/invalid sensor data, saturation above 4 g per axis, very short/long captures, and near-stationary motion. It resamples the timestamped sequence into 16 evenly spaced three-axis points. The starting vector is subtracted, and each component is encoded at 50 mg per step. A signature is 48 bytes.

Subtracting the starting vector is not full gravity compensation or rotational invariance. Start with a consistent pose and the same hand. Changing gesture speed, orientation, sensor mounting, amplitude, or button timing can change the signature substantially.

## Learned classification

Each spell can store three examples. For each class, calculate the nearest-example root-mean-square distance in g across the 48 components. Accept a candidate only when its distance is at most 0.42 g RMS, its runner-up is at least 0.09 g farther away, and its distance is no more than 78% of the runner-up distance. These initial thresholds are configurable in `src/gesture.lua`; they have not been fitted to real HTN badge recordings.

Training collects three sufficiently similar examples (pairwise distance at most 0.48 g), rejects examples within 0.28 g of another learned spell, and then requires a fourth, fresh repetition to classify as the selected spell. A failed validation does not replace the saved model. Once a class is learned, its old preset rule is disabled.

The first three repetitions are training data. The fourth is a basic hold-out check, **not enough data for a credible general accuracy claim**. Gather multiple independent trials per spell and non-spell handling motions before reporting performance. Reject movements too similar to other spell gestures.

## Preset heuristics

For untrained classes, the code examines resampled movement extent, significant direction reversals along the strongest axis, final displacement from the starting acceleration vector, and stability near the end.

Fireball expects a strong push-and-stop pattern with one significant reversal and return near the starting vector. Recharge expects multiple reversals and a return near the starting vector. Shield expects a substantial, stable final orientation change. None of these validates a spatial hand trajectory.

The included fixtures are synthetic signals chosen to exercise those rules. Their passing tests prove the implementation recognizes those fixtures, not that it recognizes real people reliably. Use Teach on actual hardware rather than tuning indefinitely to synthetic curves.

## Saves

Models use a versioned binary format (`SBG1`), a bounded per-class count, and a weighted two-byte corruption checksum. Maximum model size is 441 bytes. Saves alternate between `appdata/gest0.dat` and `appdata/gest1.dat`; the new bytes are read back before changing the active-slot store key. On launch, a corrupt active save falls back to the other slot. This improves recovery but is not a formal atomic-filesystem or cryptographic guarantee.

Only an accepted training set is persisted. Raw recordings remain transient. Templates customize casting movements, not damage, mana costs, or cooldowns. Training and persistence run locally without external services.

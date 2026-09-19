# Motion recognition

## Actual implementation

This is a small template recognizer plus conservative fallback rules, not a neural model. It uses only the accelerometer. It does not reconstruct hand paths, perform SLAM, understand arbitrary signs, or infer full-body pose.

A hold of A defines the capture window. Samples are polled no faster than every 20 ms. Each raw sample takes five bytes: two bytes of elapsed milliseconds and three quantized acceleration bytes (64 mg per step). A maximum capture is approximately 1.1 KiB; capture strings are temporary and are not broadcast or saved.

At release, the code rejects missing/non-finite sensor data, readings beyond the 32 g sanity guard, very short/long captures, and near-stationary motion. It smooths and differentiates the active segment, normalizes it by RMS magnitude, and resamples it into 16 evenly spaced three-axis points. Each normalized component is quantized to one byte, so a signature is 48 bytes.

Subtracting the starting vector is not full gravity compensation or rotational invariance. Start with a consistent pose and the same hand. Changing gesture speed, orientation, sensor mounting, amplitude, or button timing can change the signature substantially.

## Learned classification

Each spell stores one 48-byte example. Accept a candidate only when its banded-DTW distance is at most 0.48 and its distance is less than 88% of the runner-up distance when another spell is trained. These thresholds are defined in `src/gesture_dtw.lua`; they have not been fitted to real HTN badge recordings.

Training captures one example and then requires a second, fresh repetition to classify as the selected spell. A failed validation does not replace an existing learned model.

The first repetition is training data. The second is a basic hold-out check, **not enough data for a credible general accuracy claim**. Gather multiple independent trials per spell and non-spell handling motions before reporting performance. Reject movements too similar to other spell gestures.

## Runtime and storage

There are no preset Fireball, Shield, or Recharge motion heuristics. An untrained
spell cannot be cast; each user chooses distinct movements in Teach. The
included synthetic fixtures exercise segmentation and classification behavior,
not real-person accuracy.

Learned models are session-only and remain in RAM. HOME/reopen or a power cycle
starts with three untrained spells. Neither raw recordings nor 48-byte templates
are written to files or the badge key/value store, and no gesture data is sent
over radio. Templates customize casting movements, not damage, mana costs, or
cooldowns.

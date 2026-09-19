# Gesture recognition design pass — segmented normalized derivative DTW

**Date:** 2026-09-19

## Goal

Make taught badge gestures repeatable under realistic variation without turning the recognizer into a permissive classifier.

The design targets failures observed with the previous recognizer:

- waiting after pressing A changed the template;
- slower or faster repetitions changed the acceleration waveform;
- hand tremor and orientation drift could become fake path distance;
- one noisy first training example could poison the rest of teaching;
- fixed global thresholds did not reflect each user's natural repeatability;
- generic UI failures did not expose why a physical recording was rejected.

The badge exposes cached 3-axis acceleration at 50 Hz and no continuous gyro stream, so this design does not claim full world-frame or yaw invariance.

## Runtime pipeline

    A pressed
       |
       v
    raw 50 Hz accelerometer buffer
       |
       v
    activity segmentation over the complete A-hold
       |
       +-- trim leading/trailing idle
       +-- keep pauses between first and last real movement
       |
       v
    3-sample smoothing
       |
       v
    first derivative of acceleration
       |
       +-- removes constant gravity/baseline offsets
       +-- reduces sensitivity to starting bias
       |
       v
    per-gesture RMS amplitude normalization
       |
       v
    16 x XYZ derivative nodes = 48-byte template
       |
       v
    banded DTW (+/-3 nodes)
       |
       v
    two-nearest-template class score
       |
       v
    per-spell learned threshold
       |
       v
    single relative runner-up margin
       |
       +-- accept
       +-- outside learned range
       +-- ambiguous

## Capture and segmentation

The A-hold and the active gesture are separate concepts.

- Maximum A-hold: 4.5 s.
- Minimum detected active gesture: 160 ms.
- Maximum detected active gesture: 2.8 s.
- Leading and trailing idle are removed before feature extraction.
- Brief pauses inside a gesture remain because segmentation searches the whole A-hold for the first and last meaningful movement rather than ending on the first quiet interval.

Start detection uses two complementary signals:

1. 60 ms short-lag acceleration change.
2. Displacement from an averaged six-sample starting reference.

A start requires sustained evidence rather than one threshold crossing. End detection uses short-lag change only, so ending a gesture at a different badge orientation does not make trailing idle appear continuously active.

Current tuning constants:

    START_DV      = 80 mg
    START_BASE    = 80 mg
    START_STRONG  = 180 mg
    END_DV        = 45 mg

These are physical-test tuning points, not universal sensor truths.

## Raw capture representation

Raw samples are transient and are not learned templates.

Each sample is 8 bytes:

    uint16 elapsed_ms
    int16  x / 32 mg
    int16  y / 32 mg
    int16  z / 32 mg

This replaces the previous one-byte-per-axis capture representation that effectively saturated around +/-4 g. The learned model remains 48 bytes per template.

The input sanity guard accepts finite readings up to 32 g rather than rejecting a whole recording when a legitimate wrist flick exceeds 4 g.

## Preprocessing

The first six readings are averaged for a stable initial reference instead of using one button-press sample.

Feature extraction uses derivatives of a three-sample moving average:

    d[t] = smooth(accel[t]) - smooth(accel[t-1])

This is deliberately high-pass-like:

- constant gravity projection mostly disappears;
- constant sensor offsets disappear;
- starting baseline error has less effect;
- the feature describes how acceleration changes through the gesture.

It does not make the system fully orientation invariant. Rotation during the gesture still changes the gravity projection and therefore contributes to the derivative trace.

## Amplitude normalization

Real faster or slower movements do not merely stretch time; they also change acceleration amplitude.

The active derivative trace is normalized by its RMS vector magnitude before quantization:

    normalized_delta = delta / gesture_rms

The 16 learned nodes use 3 signed-like byte channels centered at 128. One RMS unit corresponds to 32 quantization steps, with extreme values clipped to keep the template compact.

Result:

    16 nodes x 3 channels = 48 bytes/template

## Banded DTW

Template distance is no longer point-for-point Euclidean distance.

A dynamic-time-warping path is allowed within +/-3 nodes around the diagonal. This permits local speed changes and short hesitations while preventing arbitrary sequence rearrangement.

The implementation reuses two 17-entry work rows rather than allocating a full 16x16 matrix for every comparison.

Class score is the mean of the two closest template distances when a spell has three examples. This prevents one lucky or outlier template from dominating classification.

## Teaching and adaptive thresholds

Each spell still uses:

    3 teaching examples
    + 1 fresh validation repetition

But the heuristics are now user-adaptive.

### First two examples

A second example that is extremely far from the first no longer traps the training session. It replaces the first sample as the new baseline and asks the user to repeat that movement.

### Third example

A third example must be plausibly related to the established pair. The loose obviously-different guard is:

    nearest prior DTW distance <= 0.85

This is not the final casting threshold.

### Per-spell calibration

After three examples, compute all pairwise DTW distances.

    spread = largest pairwise distance
    threshold = clamp(spread * 1.35 + 0.08, 0.34, 0.68)

A very consistent user's Fireball therefore gets a tighter class than a naturally variable user's Shield, while no class can become arbitrarily permissive.

### Fresh validation

The fourth repetition is classified against the three new examples for this spell, all previously learned spell classes, and the newly calibrated per-spell threshold.

The spell is committed only when that held-out repetition is accepted.

## Ambiguity

The previous recognizer stacked two different ambiguity gates.

The new recognizer uses one relative rule:

    best_score <= runner_up_score * 0.88

The candidate must beat the next-best trained class by a meaningful relative margin.

A class must first pass its own learned acceptance threshold; ambiguity cannot turn an out-of-range gesture into a cast.

## Physical diagnostics

Production gesture logging and its metadata/score tables were removed for memory headroom. Physical failures should record the visible rejection, selected spell, approximate hold/movement timing, and movement description. Detailed logging can be restored only in a separate instrumented build; it is not part of the competition package.

## Memory and performance

The recognizer remains lazy-loaded on first motion capture.

Persistent learned payload:

    3 spells x 3 examples x 48 bytes = 432 raw template bytes

plus Lua table/string overhead and three small thresholds.

DTW working state is two short rows and is reused across comparisons. Raw capture is transient; each sample uses a two-byte timestamp and three quantized axis bytes, so a 50 Hz, 4.5 s hold is roughly 1.1 KiB before Lua string overhead.

## Automated validation

Desktop tests cover leading/trailing idle, faster/slower execution, nonlinear time warping, amplitude scaling, deterministic jitter, constant baseline offsets, button-press impulse, >4 g input, adaptive threshold calibration, ambiguity between indistinguishable classes, and the existing two-badge gameplay/protocol regressions.

These are deliberately less idealized than the earlier same-waveform-different-timestamps checks, but they still cannot replace physical badge recordings.

## Known limitation

Without a continuous gyroscope or a second world-frame reference, a 3-axis-accelerometer-only classifier cannot be made fully invariant to arbitrary badge orientation.

The intended interaction therefore remains custom user-chosen gestures, a reasonably consistent way of holding the badge, robust tolerance to pauses/speed/strength/noise/moderate baseline differences, and rejection when two trained motions are not separable on this sensor.

Physical logs should drive any further threshold change. Do not globally loosen the classifier based only on synthetic tests.

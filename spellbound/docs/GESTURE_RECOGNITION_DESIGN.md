# Gesture recognition design pass — segmented normalized derivative DTW

**Date:** 2026-09-19

## Goal

Make taught badge gestures repeatable under realistic variation without turning the recognizer into a permissive classifier.

The design targets failures observed with the previous recognizer:

- waiting after pressing A changed the template;
- slower or faster repetitions changed the acceleration waveform;
- hand tremor and orientation drift could become fake path distance;
- one noisy first training example could poison the rest of teaching;
- a fixed global threshold must balance repeatability against false accepts;
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
    2-sample smoothing
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
    single-template class distance
       |
       v
    fixed acceptance threshold
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

Each sample is 3 bytes; fixed 20 ms sample position supplies elapsed time:

    uint8  x / 64 mg, biased by 128
    uint8  y / 64 mg, biased by 128
    uint8  z / 64 mg, biased by 128

This compact representation covers approximately +/-8.1 g after quantization. The separate input sanity guard accepts finite source readings up to 32 g, so energetic motion is clamped into the raw representation instead of invalidating the complete recording. The learned model remains 48 bytes per template.

The input sanity guard accepts finite readings up to 32 g rather than rejecting a whole recording when a legitimate wrist flick exceeds 4 g.

## Preprocessing

The first six readings are averaged for a stable initial reference instead of using one button-press sample.

Feature extraction uses derivatives of a two-sample moving average:

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

The implementation performs the mathematically equivalent recurrence in one reusable band row rather than allocating a full 16x16 matrix. A differential test compares it with the conventional two-row recurrence.

Class score is the DTW distance to the spell's single stored example.

## Teaching and validation

Each spell uses:

    1 teaching example
    + 1 fresh validation repetition

The single example keeps teaching quick and reduces retained template/table memory. Classification uses the fixed 0.48 acceptance threshold.

### Fresh validation

The second repetition must be within the fixed 0.48 threshold of the new example for this spell. Other learned classes remain unchanged; the relative runner-up rule is applied when casting.

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

    3 spells x 1 example x 48 bytes = 144 raw template bytes

plus Lua table/string overhead.

DTW working state is one short row and is reused across comparisons. Raw capture is transient; three axis bytes per 50 Hz sample make a 4.5 s hold at most 681 raw bytes before temporary Lua string overhead.

## Automated validation

Desktop tests cover leading/trailing idle, faster/slower execution, nonlinear time warping, amplitude scaling, deterministic jitter, constant baseline offsets, button-press impulse, >4 g input, single-example held-out validation, ambiguity between indistinguishable classes, and the existing two-badge gameplay/protocol regressions.

These are deliberately less idealized than the earlier same-waveform-different-timestamps checks, but they still cannot replace physical badge recordings.

## Known limitation

Without a continuous gyroscope or a second world-frame reference, a 3-axis-accelerometer-only classifier cannot be made fully invariant to arbitrary badge orientation.

The intended interaction therefore remains custom user-chosen gestures, a reasonably consistent way of holding the badge, robust tolerance to pauses/speed/strength/noise/moderate baseline differences, and rejection when two trained motions are not separable on this sensor.

Physical logs should drive any further threshold change. Do not globally loosen the classifier based only on synthetic tests.

# Spellbound radio protocol, version SB1

Transport: the badge Lua broadcast API. The firmware adds/removes its own `LUA1` framing. Spellbound payloads have a separate `SB1` prefix and never exceed 44 bytes. The largest current application packet is a 42-byte state snapshot.

All hexadecimal fields use uppercase ASCII. A peer is identified by the normalized 12-character MAC supplied by `badge.radio.on_recv`; it is not taken from an untrusted claimed-sender field. This is routing/filtering, not cryptographic authentication.

| Packet | Body | Meaning |
|---|---|---|
| `SB1\|H` | None | Available peer; emitted only in Find a duel |
| `SB1\|I\|sid\|target` | 8-hex session, 12-hex target MAC | Invitation |
| `SB1\|J\|sid` | Session | Guest accepted; join |
| `SB1\|S\|sid` | Session | Host ready; start handshake |
| `SB1\|K\|sid` | Session | Guest received start; host can begin |
| `SB1\|C\|sid\|seq\|spell` | 4-hex sequence, `F/S/R/X` | Guest command; X surrenders |
| `SB1\|T\|sid\|rev\|state` | 4-hex revision, 22-hex state | Authoritative snapshot and implicit acknowledgement |
| `SB1\|P\|sid` | Session | Guest heartbeat |
| `SB1\|Q\|sid` | Session | Best-effort cancellation/exit |

The table escapes pipes for Markdown only; actual packet strings contain ordinary `|` characters.

## Pairing

Both users open Find a duel. One invites the selected opponent; the other explicitly accepts. The host sends I until J arrives, sends S until K arrives, then starts and sends T. The guest stays in joining until its first valid T. Repeated J/S/K messages are idempotent and do not reinitialize a live match.

Discovery retains the five strongest recently heard peers, with stale entries removed after four seconds. The UI shows six radio-address digits to reduce ambiguity. Invitations/handshakes time out after twelve seconds. A declined invitation is suppressed locally for fourteen seconds to avoid repeated prompts from delayed/retried packets. If both players invite simultaneously, the lower normalized radio address remains host and the other side joins it as guest.

## Command reliability and state

The guest allows one unacknowledged command. It retries the identical sequence every 350 ms. The host accepts exactly `last_ack + 1`; duplicates are answered with current state without replaying effects. Rejections for mana/cooldown are also acknowledged so they cannot block later commands. A rejected recognition sends no command at all.

Snapshots are sent every 200 ms and on important transitions. Their revision increases even when only timers change. The guest ignores old/equal revisions and impossible acknowledgements. Heartbeats run every 750 ms. After six seconds without a valid peer message, the live match is cancelled; a pending command also cancels after five seconds without acknowledgement. Locally cancelled matches ignore late traffic so they cannot be silently resurrected.

These rates are design choices, not measured BLE throughput. A successful `send` means queued, not delivered. Retries are bounded by cancellation/timeouts; no busy loops or blocking waits are used. Sequence numbers do not wrap during a match: users must start a new match at the limit.

## 22-character state layout

All positions below are one-based within the state string:

| Positions | Width | Meaning |
|---|---:|---|
| 1 | 1 | Result: 0 live, 1 host win, 2 guest win, 3 draw, 4 cancelled |
| 2–3 / 4–5 | 2 each | Host / guest health, 0–100 |
| 6–7 / 8–9 | 2 each | Host / guest mana, 0–100 |
| 10–11 / 12–13 | 2 each | Remaining shield time in 20 ms units |
| 14–15 / 16–17 | 2 each | Remaining incoming-fireball time in 20 ms units; 0 = none |
| 18–21 | 4 | Last guest command acknowledged |
| 22 | 1 | Reply: 0 accepted, 1 mana, 2 cooldown, 3 busy, 4 finished, 5 sequence |

Host indices are always 1 and guest indices 2, regardless of which device renders the snapshot. Relative countdowns avoid requiring synchronized device clocks, but network transit time still shifts guest visuals. The host alone resolves effects and determines the result.

## Security boundary

No encryption, signing, anti-replay authentication, host migration, durable in-progress matches, or anti-cheat claims. Random session IDs and expected-sender filtering prevent accidental cross-match interference. A malicious transmitter or modified host can still cheat. This is suitable for a consensual local demo, not an adversarial prize/tournament system.

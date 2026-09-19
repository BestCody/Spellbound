# Spellbound radio protocol, version SB2

Transport is the badge Lua broadcast API. Firmware owns its `LUA1` framing; every Spellbound payload begins with `SB2`. Packets use fixed positions rather than delimiter parsing, and the largest packet is the 30-byte authoritative snapshot.

Hexadecimal fields use uppercase ASCII. The normalized 12-character sender MAC comes from `badge.radio.on_recv`, not from a claimed-sender field. This is filtering, not cryptographic authentication.

| Packet layout | Length | Meaning |
|---|---:|---|
| `SB2H` | 4 | Available peer in Find a duel |
| `SB2I<sid8><target12>` | 24 | Invitation |
| `SB2J<sid8>` | 12 | Guest accepts/joins |
| `SB2C<sid8><seq4><spell1>` | 17 | Guest command; spell is `F`, `S`, `R`, or surrender `X` |
| `SB2T<sid8><rev4><state14>` | 30 | Authoritative state and command acknowledgement |
| `SB2P<sid8>` | 12 | Guest heartbeat |
| `SB2Q<sid8>` | 12 | Best-effort cancellation/exit |

Exact packet lengths and hexadecimal fields are validated before state changes. SB1 and SB2 badges are intentionally incompatible; replace every app file together on both badges.

## Pairing

Both users open Find a duel. One invites; the other accepts. The host retries `I`, the guest retries `J`, and the host's first valid `T` both starts the match and acknowledges the join. Repeated join and state packets are idempotent and cannot reinitialize a live match.

Discovery retains the five strongest recently heard peers and expires entries after four seconds. The UI shows six address digits. Invitations time out after twelve seconds; a declined invitation is locally suppressed for fourteen seconds. If both players invite simultaneously, the lower normalized address stays host and the other joins as guest.

## Reliability

The guest permits one unacknowledged command and retries the same sequence every 350 ms. The host accepts exactly `last_ack + 1`; duplicates receive current state without replaying an effect. Rejected commands are acknowledged so they cannot block later commands. Rejected gesture recognition sends no command.

Snapshots are sent every 200 ms and after important transitions. Guests reject old/equal revisions and impossible acknowledgements. Heartbeats run every 750 ms. Six seconds without a valid live-match peer message cancels the match; a pending command also cancels after five seconds without acknowledgement. Locally ended matches ignore late traffic. Sequence numbers never wrap within a match.

These are bounded nonblocking retries. A successful radio `send` means queued, not delivered.

## 14-character state layout

The first nine positions are printable byte values offset by 33. Durations use 40 ms units and saturate at 93.

| Positions | Meaning |
|---|---|
| 1 | Result: 0 live, 1 host win, 2 guest win, 3 draw, 4 cancelled |
| 2-3 | Host / guest health in 25-point units |
| 4-5 | Host / guest mana in 5-point units |
| 6-7 | Host / guest remaining shield time |
| 8-9 | Host / guest remaining incoming-fireball time; zero means none |
| 10-13 | Last acknowledged guest command as four hexadecimal digits |
| 14 | Command result: 0 accepted, 1 rejected |

Host indices are always first. The host alone resolves effects and results. Relative countdowns avoid clock synchronization, though network transit still shifts guest visuals.

## Security boundary

There is no encryption, signing, authenticated anti-replay, host migration, durable match, or anti-cheat guarantee. Random session IDs and expected-sender filtering prevent accidental cross-match interference; a malicious transmitter or modified host can cheat. This is for a consensual local demo, not an adversarial tournament.

# ADR 0001: Persistent attributed traffic history

- Status: Accepted
- Date: 2026-09-18

## Context

Network Pulse currently keeps aggregate upload and download samples in memory for
at most one hour. Relaunching the app loses that history, and the samples do not
identify the network interface that produced them.

The product needs a short, rolling history that survives app and Mac restarts
without becoming a long-term activity archive. Historical values must remain
attributable to a concrete BSD interface such as `en0` or `utun3`. VPN and
physical interfaces must not be summed because they can represent the same
transfer at different network layers.

## Decision

Use SwiftData to persist sparse `TrafficHistoryRecord` values. A record is keyed
by interface, resolution, and a UTC-aligned bucket start. It stores received and
sent byte deltas, peak rates, observed duration, and sample count.

Retention has three tiers:

1. Raw observations for the latest wall-clock hour.
2. One-hour buckets from one to twenty-four hours old.
3. Three-hour buckets from twenty-four hours to seven days old.

Records older than seven wall-clock days are deleted. Compaction runs at launch,
before historical queries, and hourly while the app is running.

Storage is sparse: raw records are written only when an interface transfers
bytes. Missing, idle, sleeping, closed-app, down, and removed periods all render
as zero. Consequently, bucket chart values divide transferred bytes by the full
bucket duration. The UI labels byte totals as "Transferred" even though traffic
that occurs while Network Pulse is not running cannot be observed.

Historical charts always display one explicit BSD interface. The live
"Automatic" mode remains live-only because it may source upload and download
from different interfaces. History remembers its own interface selection and
falls back to the manually selected live interface or the busiest recently
observed interface.

History saving is enabled by default and can be disabled in Settings. Disabling
it stops new writes but retains existing records until their seven-day expiry or
explicit deletion. "Clear Session" and "Delete Saved History" are separate
actions.

Writes are buffered and committed every ten seconds. A crash may lose that
unsaved tail. Normal monitoring remains available if the SwiftData store cannot
be opened or a persistence operation fails.

The raw tier preserves the configured monitoring cadence. It provides one-second
detail when the update interval is 1s; selecting a slower monitoring interval
also makes raw persisted history correspondingly coarser. History does not run a
second hidden high-frequency polling loop.

## User interface

History offers 5-minute, 15-minute, 1-hour, 24-hour, and 7-day ranges plus an
explicit interface picker. Charts plot average throughput. Hover details expose
transferred bytes, peak rate, bucket duration, and sample count.

The Settings screen includes a "Save traffic history" toggle. The History screen
continues showing retained records while saving is disabled and indicates that
collection is off.

## Consequences

- Storage stays bounded and small while preserving detailed recent activity.
- SwiftData introduces no third-party dependency and matches the macOS 14.6
  deployment target.
- Coarse buckets intentionally lose the timing of short bursts, but retain their
  peak upload and download rates.
- A BSD interface that reappears under a different name remains a distinct
  historical series. This avoids incorrectly merging unrelated VPN tunnels.
- Missing periods look like zero activity by product decision; the chart does
  not distinguish "idle" from "not observed."


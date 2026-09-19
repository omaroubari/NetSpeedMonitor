# Ubiquitous Language

## Traffic measurement

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **Traffic observation** | One timestamped measurement of byte deltas and rates for one BSD interface over an observed duration. | Sample, reading |
| **Raw observation** | An unaggregated **Traffic observation** retained during the latest wall-clock hour. | One-second sample |
| **Transferred** | The bytes observed by Network Pulse during an interval, excluding unobserved traffic while the app was not running. | Total usage, complete transfer |
| **Average rate** | **Transferred** bytes divided by the full displayed interval, with missing observations treated as zero. | Observed average |
| **Peak rate** | The highest upload or download rate among the **Traffic observations** summarized by a record. | Maximum average |

## Attribution

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **BSD interface name** | The system identity of one network interface, such as `en0` or `utun3`. | Connection, adapter ID |
| **Attributed history** | A traffic-history series belonging to exactly one **BSD interface name**. | Combined history, automatic history |
| **Live Automatic mode** | The live presentation that independently chooses the highest current upload and download rates. | Automatic interface, primary interface |

## Retention lifecycle

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **Attributed bucket** | A UTC-aligned summary of traffic for one **BSD interface name** and one fixed interval. | Sample, rolling window |
| **One-hour bucket** | An **Attributed bucket** retained for traffic between one and twenty-four hours old. | Hourly sample |
| **Three-hour bucket** | An **Attributed bucket** retained for traffic between twenty-four hours and seven days old. | Daily bucket |
| **Compaction** | The loss-aware replacement of expired raw observations with progressively coarser **Attributed buckets**. | Cleanup, deletion |
| **Retention window** | The latest seven wall-clock days eligible to appear in **Attributed history**. | Session, archive |

## User actions

| Term | Definition | Aliases to avoid |
| --- | --- | --- |
| **Clear Session** | Reset live in-memory samples, transfer counters, and peaks without changing **Attributed history**. | Clear History |
| **Delete Saved History** | Permanently remove all persisted **Traffic observations** and **Attributed buckets** after confirmation. | Clear Session |
| **Save History** | The preference controlling whether new **Traffic observations** enter persistent storage. | Monitoring, retention |

## Relationships

- A **Traffic observation** belongs to exactly one **BSD interface name**.
- An **Attributed history** contains raw observations, one-hour buckets, and three-hour buckets for exactly one **BSD interface name**.
- Many raw observations compact into one **One-hour bucket**; up to three one-hour buckets compact into one **Three-hour bucket**.
- **Live Automatic mode** is not a **BSD interface name** and never produces combined **Attributed history**.
- Disabling **Save History** preserves existing records until **Compaction** removes them outside the **Retention window**.

## Example dialogue

> **Dev:** “Should the History screen offer **Live Automatic mode**?”
>
> **Domain expert:** “No. Select one **BSD interface name** so the chart remains **Attributed history** and never combines VPN and physical traffic.”
>
> **Dev:** “What happens to its **Raw observations** tomorrow?”
>
> **Domain expert:** “**Compaction** rolls them into **One-hour buckets**, then **Three-hour buckets**, and removes them after the seven-day **Retention window**.”

## Flagged ambiguities

- “History” previously meant both current-session memory and saved traffic. Use **session** for live in-memory state and **Attributed history** for persisted records.
- “Automatic interface” implies one interface exists, but live upload and download may come from different interfaces. Use **Live Automatic mode** and never persist it as attribution.
- “One-second detail” only applies when the configured update interval is 1s. Use **Raw observation** when discussing the tier independent of sampling cadence.
- “Transferred” is intentionally the UI label, but it represents only bytes observed while Network Pulse was running; it is not complete device usage.


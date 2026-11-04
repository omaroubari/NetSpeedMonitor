# Product roadmap

Last updated: 2026-11-04

This file tracks the planned network monitoring and protection features. The current project is named Network Pulse; the proposed feature descriptions use NetMute. Product naming remains undecided.

## Tracking conventions

- `[ ]` means planned; `[x]` means implemented and verified against the acceptance criteria.
- Record implementation links and validation evidence under each feature as work progresses.
- Feature numbers match the original roadmap; they do not indicate implementation order.
- The phases below are a proposed sequence, not delivery commitments.

## Current baseline

The app provides live interface upload/download rates, menu-bar monitoring, session statistics, and saved interface traffic history with seven-day retention. Per-app attribution and network blocking are not implemented.

Existing interface-history terminology and behavior are documented in [UBIQUITOUS_LANGUAGE.md](UBIQUITOUS_LANGUAGE.md) and [the persistent history ADR](docs/adr/0001-persistent-attributed-traffic-history.md). The longer retention and per-app records below are future changes, not current behavior.

## Proposed delivery phases

| Phase | Scope | Exit criteria |
| --- | --- | --- |
| 0 — Validate the foundation | Network Extension prototype, signing, app attribution, live byte accounting, existing-flow blocking | Identify an app, measure its traffic, block an active transfer, record the deciding rule, and unblock it; validate TCP, UDP, and VPN coexistence |
| 1 — Core controls | Per-app firewall (1), traffic monitor (7), blocked activity (9), basic domain tracking (8) | App controls and connection records work together through one rule engine |
| 2 — Protection and review | Tracker Shield (2), Quiet Mode (5), App X-Ray (6), domain blocking (8), Protection Check (4), Safari Shield (3) | Protection is observable and testable, with explicit coverage limits and exceptions |
| 3 — History and discovery | Network reports (10), connection history (11), smart search (18) | Retention, aggregation, and search work across app and destination records |
| 4 — Automation and budgets | Network profiles (14), hotspot protection (12), data limits (13), Focus Sync (15) | Profile changes and budget actions are predictable and explainable |
| 5 — Rule maintenance | Rule insights (16), rule cleanup (17) | Users can assess and clean up rules with evidence and explicit deletion control |

## Feature checklist

### 1. Per-app firewall

- [ ] Turn internet access on or off for individual apps from the main window and menu bar.
- [ ] Keep the app running while blocking its network traffic.
- [ ] Apply changes to existing connections as well as new connection attempts.
- [ ] Verify that blocking one app leaves unrelated apps connected.

### 2. Tracker Shield

- [ ] Automatically block known advertising, analytics, and tracking services across Mac apps.
- [ ] Support exceptions for individual apps.
- [ ] Define tracker-list updates and precedence between tracker rules and app exceptions.

### 3. Safari Shield

- [ ] Provide a Safari content blocker using the product's tracker list.
- [ ] Validate coverage with iCloud Private Relay enabled and disabled.
- [ ] Document the additional coverage it provides relative to the network filter.

Do not assume Private Relay necessarily bypasses the network filter. Apple describes content filtering before relay processing; verify behavior on supported macOS versions before making coverage claims.

### 4. Protection Check

- [ ] Run an actual blocking test for each installed browser.
- [ ] Show test results separately from whether protection is enabled.
- [ ] Distinguish passed, failed, and inconclusive or unsupported tests.

### 5. Quiet Mode

- [ ] Allow new connections while recording them for later review, subject to existing blocking rules.
- [ ] Provide a review backlog with allow/block decisions.
- [ ] Avoid repeated prompts while Quiet Mode is active.
- [ ] Explain that retrospective decisions affect future traffic and cannot undo previous transfers.

### 6. App X-Ray

- [ ] Show the domains an app contacts and identify known trackers.
- [ ] Allow blocking selected domains for that app.
- [ ] Provide an A+–F grade based on observed, assessable connections.
- [ ] Explain grading criteria, missing observations, and unknown destinations; avoid presenting the grade as a complete privacy guarantee.

### 7. Real-time traffic monitor

- [ ] Identify apps currently consuming bandwidth.
- [ ] Show separate upload and download rates, including in the menu bar.
- [ ] Define how helper processes and system services are attributed to apps.
- [ ] Document sampling cadence, observation gaps, and VPN accounting limits.

### 8. Domain tracking

- [ ] Show server domains contacted by each app, contact frequency, and transferred bytes.
- [ ] Block a domain for an app while preserving its other connections.
- [ ] Preserve unknown hostnames and explain attribution limits.
- [ ] Define whether frequency counts connection attempts, established flows, or another explicit event.

### 9. Blocked activity

- [ ] Record timestamps, app names, destination addresses, and responsible rules.
- [ ] Support searching and filtering the log.
- [ ] Pause display updates while protection continues running.

### 10. Network reports

- [ ] Provide weekly, monthly, quarterly, and yearly reports.
- [ ] Show total uploads/downloads, biggest data-consuming apps, destination countries, and hourly activity.
- [ ] Distinguish unavailable history from observed zero usage.
- [ ] Label destination-country data as an estimate derived from destination IPs, with unknown values supported.

### 11. Connection history

- [ ] Offer retention of three months, six months, one year, or two years.
- [ ] Default retention to one year.
- [ ] Define detailed-record retention separately from aggregate-report retention.
- [ ] Provide deletion controls and enforce expiration consistently.

### 12. Hotspot protection

- [ ] Automatically restrict selected apps when joining a personal hotspot.
- [ ] Track a hotspot data budget.
- [ ] Restore the previous profile when leaving the hotspot.
- [ ] Validate hotspot detection and behavior when automatic detection is unavailable.

### 13. Data limits

- [ ] Support daily, monthly, and one-time caps for an app or the whole Mac.
- [ ] Scope caps to all networks, hotspots, or specific Wi-Fi networks.
- [ ] Offer warnings or automatic blocking at the limit.
- [ ] Define reset times, timezone behavior, and expected enforcement overshoot.

### 14. Network profiles

- [ ] Save combinations of app and domain-group blocking rules.
- [ ] Switch profiles automatically by Wi-Fi network or schedule.
- [ ] Define precedence among manual selection, schedules, hotspot rules, and other automatic changes.

### 15. Focus Sync

- [ ] Expose profile switching through Apple Shortcuts.
- [ ] Document how to connect profile changes to Focus automations.
- [ ] Verify supported automation behavior on target macOS versions.

### 16. Rule insights

- [ ] Count how often a domain rule actually determined a connection's outcome in a rolling 30-day window.
- [ ] Show when the rule last determined an outcome within that window.
- [ ] Exclude IP and CIDR rules from counters.
- [ ] Distinguish the deciding rule from other rules that also matched.

### 17. Rule cleanup

- [ ] Find rules for uninstalled apps.
- [ ] Find rules already covered by broader rules or Tracker Shield.
- [ ] Explain each finding and let the user control deletion.
- [ ] Never treat lack of recent use alone as proof that a rule is removable.

### 18. Smart search

- [ ] Search network activity by destination country, hostname, or company.
- [ ] Support queries such as `company:google`.
- [ ] Combine filters and support minus-prefixed exclusions.
- [ ] Define company attribution sources and preserve unknown or ambiguous ownership.

## Foundation decisions and validation

The proposed foundation is a Network Extension content filter, a shared rule engine, and a local history store. Interface counters can continue to serve the existing overall-speed display. These are architectural proposals until validated and recorded in an ADR.

- [ ] Confirm minimum macOS version, distribution channel, signing identity, provisioning, and required entitlements.
- [ ] Prototype installation, user approval, activation, upgrade, and removal of the extension.
- [ ] Verify app identity, helper attribution, and identity persistence across app updates; do not use a process ID as a durable app identity.
- [ ] Verify periodic flow statistics, counter semantics, and live upload/download rates for long-lived connections.
- [ ] Verify blocking of active TCP and UDP flows and restoration of connectivity after unblocking.
- [ ] Test VPNs, Private Relay, encrypted DNS, IPv4/IPv6, sleep/wake, and network transitions.
- [ ] Define deterministic rule precedence and record the rule responsible for every filtering decision.
- [ ] Validate permitted communication and storage between the filter extension and containing app.
- [ ] Define behavior when the app, extension, rule store, or reporting store is unavailable.
- [ ] Separate protection state, traffic collection state, and display-paused state.
- [ ] Define accounting boundaries to avoid double-counting VPN and physical-interface traffic.
- [ ] Define connection records with app identity, destination address, optional hostname, timestamps, byte counts, decision, deciding rule, and attribution provenance.
- [ ] Plan database migrations, retention, aggregation, privacy controls, and storage limits for up to two years of history.
- [ ] Record the validated architecture and any changes to existing interface-history semantics in ADRs.

## Reference material

- [Apple: Filtering Network Traffic](https://developer.apple.com/documentation/networkextension/filtering-network-traffic)
- [Apple: NEFilterDataProvider](https://developer.apple.com/documentation/networkextension/nefilterdataprovider)
- [Apple: Network Extensions entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.networkextension)
- [Apple: Remote hostname availability](https://developer.apple.com/documentation/networkextension/nefiltersocketflow/remotehostname)
- [Apple: Get ready for iCloud Private Relay](https://developer.apple.com/videos/play/wwdc2021/10096/)

## Progress log

| Date | Update | Evidence |
| --- | --- | --- |
| 2026-11-04 | Captured the 18-feature roadmap, proposed phases, and foundation validation checklist. Implementation has not started. | Initial roadmap discussion |

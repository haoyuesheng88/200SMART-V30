# Four-Bag Pulse Dust Collector Case

## Purpose

Import a ready-made four-bag pulse cleaning example into `MAIN (OB1)` of STEP 7-Micro/WIN SMART and keep a clear input-to-output loop for demo, verification, and later customization.

## Input Addresses

| Address | Meaning |
| --- | --- |
| `I0.0` | Enable |
| `I0.1` | Reset |
| `I0.2` | RunPermit |
| `I0.3` | CleanRequest |
| `I0.4` | DpHigh |
| `I0.5` | DpLow |
| `I0.6` | ContinuousMode |
| `I0.7` | ManualPulse, rising-edge trigger |

## Output Addresses

| Address | Meaning |
| --- | --- |
| `Q0.0` | Pulse valve for bag 1 |
| `Q0.1` | Pulse valve for bag 2 |
| `Q0.2` | Pulse valve for bag 3 |
| `Q0.3` | Pulse valve for bag 4 |
| `Q0.4` | Running status |
| `Q0.5` | Alarm |
| `Q0.6` | Latched auto-clean request |
| `Q0.7` | RunPermit mirror |

## Default Parameters

| Address | Default | Unit | Meaning |
| --- | --- | --- | --- |
| `VB100` | `4` | count | Bag count, clamped to `1..4` |
| `VW102` | `20` | 10 ms | Generic pulse width, default 200 ms |
| `VW104` | `500` | 10 ms | Valve-to-valve delay, default 5 s |
| `VW106` | `18000` | 100 ms | Continuous-cycle pause, default 30 min |
| `VB108` | `1` | index | Target bag for manual pulse |
| `V3.0` | `1` | Bool | Enable per-bag pulse width override |
| `VW120` | `0` | 10 ms | Bag 1 pulse width, `0` means use `VW102` |
| `VW122` | `0` | 10 ms | Bag 2 pulse width, `0` means use `VW102` |
| `VW124` | `0` | 10 ms | Bag 3 pulse width, `0` means use `VW102` |
| `VW126` | `0` | 10 ms | Bag 4 pulse width, `0` means use `VW102` |

## Key State Registers

| Address | Meaning |
| --- | --- |
| `VB110` | Step code: `0` idle, `10` pulsing, `20` inter-valve delay, `30` cycle pause, `40` manual pulse |
| `VB111` | Current bag number |
| `V1.0` | Latched auto-clean request |
| `V1.1` | Internal cycle-complete flag |
| `V1.2` | Alarm for parameter or manual-selection error |
| `V1.4` | Manual-pulse rising edge |
| `VW128` | Actual pulse width used by the current step |

## Logic Summary

1. First scan writes the default parameters into `VB100`, `VW102`, `VW104`, `VW106`, and related registers.
2. The program mirrors `I0.0` through `I0.7` into `V0.0` through `V0.7`.
3. `CleanRequest`, `DpHigh`, or `ContinuousMode` latch the automatic clean request.
4. When `Enable` and `RunPermit` are true, the sequence starts from bag 1 and pulses `Q0.0` through `Q0.3` in order.
5. Each pulse width comes from `VW128`; if `VW120..VW126` are zero, the program falls back to `VW102`.
6. After each pulse, the program waits `VW104`. After one full cycle, it decides whether to idle or wait `VW106` before restarting.
7. A rising edge on `I0.7` triggers a manual pulse. `VB108` selects the bag. Out-of-range values raise the alarm.

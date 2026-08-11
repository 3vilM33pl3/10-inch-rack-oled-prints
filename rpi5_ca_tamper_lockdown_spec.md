# RPi 5 CA — Tamper / Move-Detection Lockdown (software spec)

**Status:** design spec only. The daemon is a follow-up task; this document defines
the wiring, detection algorithm, lockdown actions and recovery so it can be built
without re-deriving the design. Companion hardware: `rpi5_ca_case.scad` (the
enclosure with the rigid gyro pocket + accessible mux bay).

## Goal

This Pi 5 is the homelab **Certificate Authority**. Physical movement of the unit
must be treated as a compromise event (someone is removing/relocating the CA), so
the system **seals its key material and stops issuing** the moment it is moved —
ATM-style — and refuses to resume without an explicit out-of-band operator unlock.

## Threat model (what this does and does not defend)

- **Defends:** opportunistic physical removal/relocation of the running unit; a
  grab-and-go attacker; accidental relocation while keys are unsealed.
- **Does not defend:** an attacker who cuts power instantly (mitigated separately by
  keeping keys sealed at rest — see "Key state"), decapping chips, or bus probing.
  The gyro raises the cost and guarantees an auditable lockdown, it is not an HSM.

## Hardware wiring

```
Pi 5 I2C1 (GPIO2 SDA / GPIO3 SCL, 3V3, GND)
   └── TCA9548A multiplexer  @ 0x70        (accessible mux bay, headers up)
          └── channel 0 ── MPU-6050 gyro/accel @ 0x68   (rigidly bonded in the tray pocket)
```

- The MPU-6050 lives behind the multiplexer even though one sensor does not strictly
  need a mux: it keeps the CA's sole tamper sensor on an isolated, known channel and
  leaves channels 1–7 free for future I2C devices without re-cabling. `MPU AD0` low → `0x68`.
- **Rigid mount is mandatory.** The `component_pocket` in the tray bonds the MPU-6050
  PCB to the shell (edge capture + Ø6 post through the board's Ø3 hole + adhesive). A
  loose sensor makes the noise floor unusable and produces false lockdowns.
- Pull-ups: the Pi's internal 1.8kΩ I2C pull-ups are usually sufficient for this short
  bus; if the breakouts already carry pull-ups, do not stack more than ~2 in parallel.
- `MPU INT` may optionally be wired to a spare GPIO for the MPU's own
  motion-interrupt (hardware wake), but the polling loop below is the primary path.

Enable the bus: `dtparam=i2c_arm=on`; expect `0x70` on `i2cdetect -y 1`, and `0x68`
once channel 0 is selected on the mux.

## Detection algorithm

State machine: `CALIBRATING → ARMED → (TRIP) → LOCKED → (operator unlock) → ARMED`.

1. **Calibration (boot / after unlock).** With the unit known-still, sample ~2 s at
   100 Hz. Record the resting gravity vector `g0 = mean(accel)` and gyro bias
   `w0 = mean(gyro)`, plus the per-axis noise σ. Persist `g0` so an unexpected reboot
   can compare current orientation against the last-known-good pose.
2. **Armed loop (≈50–100 Hz).** Each sample compute:
   - `a_dev = | |accel| − |g0| |`         (linear shock / lift)
   - `tilt  = angle(accel, g0)`           (orientation change vs the resting pose)
   - `w_mag = |gyro − w0|`                (rotation rate)
3. **Trip condition (any, sustained past debounce):**
   - `a_dev > A_THRESH` (default ~0.15 g), OR
   - `w_mag > W_THRESH` (default ~15 °/s), OR
   - `tilt  > TILT_THRESH` (default ~5°) held for `TILT_HOLD` (default 1 s) — catches a
     slow deliberate lift that stays under the shock threshold.
   Debounce: require `N_TRIP` consecutive violating samples (default 3) to reject
   single-sample spikes; a brief bump under threshold does not trip.
4. **Trip → LOCKED** fires the lockdown actions once, latches, and stops disarming
   itself. Only an operator unlock leaves `LOCKED`.

Thresholds live in a config file and are tuned per install (a rack shelf vs a desk
have different ambient vibration). Log the running `a_dev / w_mag / tilt` at debug to
pick thresholds. **Fail safe:** if the sensor read fails (I2C error, sensor absent)
for more than `SENSOR_TIMEOUT`, treat it as a tamper and lock — a cut sensor wire
must not be a bypass.

## Key state & lockdown actions

**Key state (at rest):** CA private keys stay **sealed** whenever not actively
signing — e.g. the signing key in a SoftHSM token on a LUKS volume that is mounted
only for the duration of an issuance, or wrapped and only unwrapped in memory. This is
what makes move-detection meaningful: lockdown seals fast and a power-cut leaves keys
sealed anyway.

**On TRIP (LOCKED), in order:**
1. `systemctl stop <ca-service>` (step-ca / OpenSSL CA / whatever issues) — stop
   signing first.
2. Seal key material: log out of / unload the SoftHSM/PKCS#11 token, then unmount and
   `cryptsetup luksClose` the key volume (and `sync`).
3. Drive the OLED to a full-screen **`LOCKED — TAMPER`** banner with a timestamp and
   the trip reason (`shock` / `rotation` / `tilt` / `sensor-loss`).
4. Emit an alert: syslog at `crit`, plus an optional webhook / matrix / email to the
   operator (best-effort, non-blocking; lockdown must not wait on the network).
5. Latch: write a `tamper.locked` flag file so a reboot comes up `LOCKED`, not `ARMED`.

Lockdown must be **idempotent and fast** — target < 500 ms from trip to keys sealed.
Never require the network to complete the seal.

## Recovery (operator unlock)

Recovery is deliberately manual and multi-factor, matching the CA's value:

1. Operator authenticates locally (console login — the front USB keyboard) with a
   passphrase **and** a **Yubikey** touch (the resident front-bay Yubikey; e.g.
   PAM `pam_yubico` / FIDO2). Remote unlock is disallowed by default.
2. On success: clear `tamper.locked`, re-run calibration at the new resting pose,
   re-open the LUKS volume / re-load the token, `systemctl start <ca-service>`, and
   return the OLED to its normal status screen.
3. Every lock and unlock is appended to a tamper audit log (who, when, trip reason).

## Delivery outline (for the follow-up implementation task)

- **Language/libs:** Python 3.11+, `smbus2` for I2C. A ~40-line MPU-6050 driver
  (wake `PWR_MGMT_1`, set `ACCEL_CONFIG`/`GYRO_CONFIG` ranges, burst-read
  `ACCEL_XOUT..GYRO_ZOUT`), a mux helper that writes the channel bitmask to `0x70`,
  and the state machine above. Ruff-formatted, type hints, `pytest` for the threshold
  math with recorded sample fixtures.
- **Service:** `tamper-lockdownd.service` — `Type=notify`, `Restart=always`,
  hardened unit (`ProtectSystem=strict`, `NoNewPrivileges`, minimal `ReadWritePaths`
  for the flag/log and the crypto control paths), started before the CA service and
  ordered so the CA service refuses to start while `tamper.locked` exists.
- **Config:** `/etc/ca-tamper/config.toml` — mux addr/channel, MPU addr, the four
  thresholds + debounce counts, `SENSOR_TIMEOUT`, alert webhook, service names,
  LUKS/token identifiers.
- **Calibration/recovery CLI:** `ca-tamper calibrate` / `ca-tamper unlock` /
  `ca-tamper status`, the unlock path gated behind the passphrase + Yubikey check.

## Open items

- Confirm the exact CA stack in use (step-ca vs OpenSSL vs other) to fix the service
  names and the seal/unseal commands.
- Decide whether to also wire `MPU INT` to a GPIO for a hardware low-power motion wake.
- Bench-tune the four thresholds in the chosen final location before arming in anger.

# Public Release Checklist

This repository is being prepared for publication under the LogiMentor GitHub
organization.

## Done

- Add Apache-2.0 license text.
- Add SPDX license identifiers to source, simulation, and CI files.
- Replace the legacy README text with a `lm_util` README.
- Add GitHub Actions CI using GHDL and VUnit.
- Make the VUnit runner independent from the current working directory.
- Declare Python test dependencies in `requirements.txt`.
- Rename historical package constants to the `C_LM_*` prefix.
- Remove the legacy GitLab CI configuration.

## Before Publishing

- Confirm that Logimentor Srl owns the copyright for all files imported from
  the previous repository and that relicensing to Apache-2.0 is intended.
- Run the GitHub Actions workflow and confirm the fast GHDL/VUnit regression is
  green on the public branch.

## Verification Gaps

The following synthesizable modules currently have no direct VUnit testbench:

- `lm_util_ccd_sync_bus`
- `lm_util_clock_mux`
- `lm_util_lfsr`
- `lm_util_mux`
- `lm_util_mux_or`
- `lm_util_pri_arbiter`
- `lm_util_rr_arbiter`

Known disabled or incomplete VUnit configurations are documented in
`sim/scripts/run.py` and should be triaged before a tagged release.

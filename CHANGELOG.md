# Changelog

## Unreleased

### Breaking Changes

- CRC `match_o` is now a held level instead of a one-cycle idle-cleared pulse.
  It clears on reset, `init_i`, or the next checked data update. Designs that
  require a pulse should qualify or edge-detect it at the protocol boundary that
  marks the end of the CRC field.

### Changed

- CRC checkers compare against the computed residue for transmitted CRC fields
  that include `xorout`.
- The parallel CRC reflected-input mode now reflects bits within each byte
  rather than reversing the whole input word.
- CRC engines support 4- to 64-bit polynomials.

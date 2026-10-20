# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [9.0.0] - 2026-10-20

### Added
- `--from "Name <phone>"` command-line option to override the sender identity for a single transmission.
- `CALLERID` environment-variable override; the script now uses `CALLERID="${CALLERID:-Your Name <+15551234567>}"`.
- `truncate_str()` helper to cap coversheet names, subjects, priorities, and page-header names so text cannot cross columns or margins.
- `ps_escape()` now normalizes tabs and strips non-printable characters in addition to escaping PostScript metacharacters.
- Documentation for `SendFAX()` options, monitoring, and troubleshooting.

### Changed
- **Transmission header position:** stamped at `+0+28` pixels instead of `+0+20`, placing the ink about 4.9 mm from the top edge. This clears the typical 4–5 mm non-printable margin of office fax machines and multifunction printers while leaving the undercolor box above the reserved PDF content boundary.
- **Coversheet `SUBJECT:` position:** moved from `y=520` to `y=526`, balancing the 34pt gap below the page-count block against the 31pt gap above `MESSAGE:`.
- Page-header names are truncated to 28 characters; coversheet names to 34; subjects to 64; priority values to 28.
- Message wrapping reduced from 85 to 75 characters to match proportional 12pt Helvetica inside the 512pt message box, with a hard-wrap fallback for long unbroken tokens.

### Fixed
- Descender/ascender collisions under `FROM:`, `TO:`, and `PAGES:` caused by 10pt leading on 12pt text.
- Zero-leading confidentiality footer lines.
- Header text touching the coversheet's top border.

---

## [8.0.0] - 2026-10-20

### Added
- Reserved 74-pixel white header band on PDF pages: pages are rendered at 612x765pt and bottom-aligned onto a 1728x2156 canvas, so the transmission header never overwrites top-edge document content.
- Explicit ImageMagick header settings: `-density 204x196 -units PixelsPerInch -font Helvetica -pointsize 10`.

### Changed
- Coversheet fonts switched from Times to Helvetica/Helvetica-Bold for cleaner bilevel rendering at fax resolution.
- Coversheet body leading increased to 15pt; footer leading to 12pt.
- Coversheet top border lowered from `y=770/765` to `y=752/747`.

### Removed
- No-op Ghostscript flags on `-sDEVICE=tiffg4` (`-dDownScaleFactor`, `-dTextAlphaBits`, `-dGraphicsAlphaBits`, `-dNOINTERPOLATE`), which were verified to have no effect on this device.

---

## [7.0.0] - 2026-10-20

### Added
- `ps_escape()` for PostScript strings: UTF-8-to-ASCII transliteration via `iconv`, control-character stripping, and escaping of `\`, `(`, and `)`.
- Atomic call-file submission: files are staged in `/var/spool/asterisk/tmp` and renamed into the outgoing spool on the same filesystem.
- Per-run private temporary directory with `trap` cleanup and PID-suffixed names.
- Phone-number normalization (spaces, dashes, dots, parentheses stripped; 7–15 digits validated; leading `+` removed from the dial string).
- Final TIFF page-count verification before submission.
- Early permission, dependency, and fax-module checks, including `res_fax_spandsp.so`.
- `--` end-of-options handling; `-h/--help` exits 0.

### Fixed
- Cover-sheet crashes on unbalanced parentheses and blank rendering of UTF-8 punctuation.
- ImageMagick `%`-escape expansion in header text.
- TIFF polarity flipped to `BlackIsZero`; now forced to `min-is-white` for TIFF-F compatibility.
- PDF filenames containing commas breaking the Asterisk `Data:` line.
- Silent fallback that could send a single-page fax when ImageMagick was unavailable.
- Blank message lines collapsing in the coversheet.
- Cross-filesystem `mv` into the spool racing with Asterisk's inotify watcher.

### Changed
- Header stamping consolidated into a single `stamp_header()` function.
- Message-line handling uses `mapfile` instead of per-line `sed` subshells.
- Background TIFF cleanup extended from 15 to 60 minutes.

---

## [6.0.0] - 2026-10-20

### Changed
- Script renamed to `sendfax.sh`.
- Caller ID made configurable rather than fixed in the script.

---

## [5.0.0] - 2026-01-26

### Added
- `--cover`, `--nocover`, and `--help` options.
- Improved PDF rasterization settings.
- Retry count increased to 3.

---

## [4.0.0] - 2025-09-17

### Added
- Recipient `"Name <phone>"` parsing.
- Recipient phone number and priority on the coversheet.
- Word-wrapped coversheet messages with an 18-line cap and `...more`.

---

## [3.0.0] - 2025-09-15

### Added
- Per-page `FROM / TO / DATE / PAGE` headers via ImageMagick, without a coversheet.

---

## [2.0.0] - 2025-09-15

### Added
- PostScript coversheet generation.
- Per-page header stamping.

---

## [1.0.0] - 2025-09-15

### Added
- Initial PDF-to-G4-TIFF conversion and Asterisk call-file submission.

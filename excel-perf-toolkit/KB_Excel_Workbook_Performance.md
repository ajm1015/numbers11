# KB: Excel Workbook Performance — Diagnosis and Remediation

**Category:** Endpoint Performance / Application Support
**Applies to:** Excel 2016+, Microsoft 365 — workbooks on network shares (SMB/CIFS)

---

## Symptoms

- Workbooks take 30+ seconds to open from network shares
- Saving hangs or takes disproportionately long relative to file size
- Excel becomes unresponsive during recalculation
- High network I/O when opening files that appear small
- "Not Responding" during open, even after endpoint performance tuning

## Root Cause Categories

| Category | What It Is | Why It Hurts |
|----------|-----------|-------------|
| Phantom ranges | Used range extends far beyond actual data (e.g., formatting on row 1,048,576) | Excel loads/saves the entire used range, not just data rows. Inflates memory and I/O. |
| External links | Formulas or named ranges referencing other workbooks on network shares | Every external link triggers an SMB round-trip on open and recalc. Stale links retry and timeout. |
| Volatile functions | `INDIRECT()`, `OFFSET()`, `NOW()`, `TODAY()`, `RAND()`, `CELL()`, `INFO()` | Force full workbook recalculation on every cell edit. Cost scales with sheet size. |
| Excessive unique formats | Thousands of unique font/fill/border/number format combinations | Each unique combo creates an XF record in styles.xml. Excel performance degrades above ~500 unique formats. |
| Broken named ranges | Named ranges pointing to `#REF!` or deleted external sources | Excel attempts to resolve these on open. Dead external refs trigger network timeouts. |
| Residual formatting | Empty sheets with formatting, data validation, or conditional formatting on massive ranges | Inflates the used range and file size with zero functional value. |
| Embedded objects | OLE objects, images, charts pasted as pictures | Can inflate file size by 10-100x. Stored uncompressed inside the .xlsx zip. |
| VBA with auto-execute | Macros that run on open, reference external resources, or perform heavy computation | Adds load time. External references in VBA have the same SMB penalty as formula-based links. |

## Diagnostic Workflow

### Phase 1: Triage — Identify Worst Offenders

Run the share scanner to build a prioritized hit list:

```powershell
.\Scan-ExcelShares.ps1 -SharePaths "\\server01\share","\\server02\dept" -MinSizeMB 1
```

Output: CSV sorted by file size descending. Start remediation from the top.

**Triage heuristics:**

- Files > 20 MB are almost certainly bloated unless they contain large datasets
- Files > 5 MB that users report as "slow" are strong candidates
- Files last modified years ago but still opened daily accumulate the most cruft

### Phase 2: Diagnosis — Analyze Individual Workbooks

Run the workbook analyzer against each candidate:

```bash
python analyze_workbook.py "\\server01\share\workbook.xlsx" --json report.json
```

The analyzer checks all root cause categories above and produces a severity-rated findings report. Critical findings are the ones impacting performance. Warnings indicate potential issues.

**Reading the report:**

- **Phantom range ratio > 5x** = highest impact. A sheet declaring 1M rows but containing 500 rows of data is loading 2000x more than needed.
- **External links > 0** = each one is a network call. Even one stale link to an offline server can add 30+ seconds (SMB timeout).
- **Volatile function count > 50** = meaningful recalc overhead. Scales with total cell count in the workbook.
- **Unique styles > 2000** = styles.xml is bloated, degrading open/save performance.

### Phase 3: Remediation

#### Phantom Ranges

**Manual fix (per workbook):**

1. Go to the last row of actual data
2. Select the row below it through the end of the sheet (Ctrl+Shift+End)
3. Right-click → Delete → Entire Row
4. Repeat for columns
5. Save, close, reopen — verify the used range matches the data range

**Scripted fix (batch):** Use a VBA macro or Python script to reset used ranges. Caution: this can break workbooks with intentional sparse layouts. Always back up first.

#### External Links

**Identify:** Analyzer lists all external references with cell locations.

**Fix options:**

1. **Break links:** Data tab → Edit Links → Break Link. Converts formulas to static values. Use when the external source is stale or no longer needed.
2. **Localize:** Copy the referenced data into the workbook as a static table. Replace formulas with local references.
3. **Consolidate:** If multiple workbooks reference the same source, consider a Power Query connection that refreshes on demand rather than on every open.

**Named ranges:** Formulas tab → Name Manager → Delete any named range showing `#REF!` or pointing to external sources no longer in use.

#### Volatile Functions

| Volatile Function | Common Replacement |
|---|---|
| `INDIRECT("A" & ROW())` | Direct cell reference `A1`, `A2`, etc. or `INDEX()` |
| `OFFSET(ref, rows, cols, h, w)` | `INDEX(range, row, col)` — non-volatile equivalent |
| `NOW()` / `TODAY()` | Single cell with the date, referenced by other cells. Or a VBA `Workbook_Open` macro that writes the timestamp once. |
| `RAND()` / `RANDBETWEEN()` | Paste as values after generation if randomness isn't needed on every edit |

**Key insight:** `INDEX()` is the non-volatile replacement for both `OFFSET()` and `INDIRECT()` in most use cases.

#### Excessive Unique Formats

**Manual fix:**

1. Home tab → Cell Styles → check for hundreds of custom styles
2. Select all (Ctrl+A) → apply a single consistent format
3. Use "Clear Formats" on non-data areas

**Scripted fix:** Third-party tools like XLStylesTool (free, Microsoft) can remove unused styles from the styles.xml inside the .xlsx without opening in Excel.

**Prevention:** Avoid copy-pasting from web pages or other documents. Each paste can import dozens of unique format combinations. Use "Paste Values" or "Paste Special → Values and Number Formats."

#### Residual Formatting on Empty Sheets

1. If the sheet is truly unused: delete it
2. If the sheet has a purpose but no data yet: select all cells beyond the data area → Home → Clear → Clear All
3. Save, close, reopen to confirm the used range has shrunk

#### Embedded Objects

1. Review → check for OLE objects, embedded files, or pasted images
2. Replace embedded images with linked images where possible
3. Compress images: select image → Format → Compress Pictures → select target resolution

#### VBA Macros

1. Open VBA editor (Alt+F11)
2. Check for `Auto_Open`, `Workbook_Open`, or `Workbook_BeforeClose` macros
3. Review for external file references, web calls, or heavy loops
4. Remove or optimize as needed. Convert auto-execute macros to on-demand where possible.

## Prevention Guidance for End Users

Distribute to workbook owners / power users:

- **Paste values, not formulas,** when pulling data from other files
- **Delete unused sheets** instead of clearing them
- **Avoid formatting entire columns/rows** (selecting column A and applying bold formats 1M+ cells)
- **Use Tables (Ctrl+T)** — they auto-manage the used range and structured references
- **Break external links** before archiving workbooks
- **Compress images** before inserting (or use linked images)
- **Avoid INDIRECT/OFFSET** — use INDEX for lookups

## Tools

| Tool | Purpose | Location |
|------|---------|----------|
| `Scan-ExcelShares.ps1` | Scan network shares, build triage CSV | IT Tools repo |
| `analyze_workbook.py` | Deep workbook analysis with severity-rated findings | IT Tools repo |
| XLStylesTool | Remove unused styles from .xlsx (Microsoft free tool) | [Download from Microsoft](https://microsoft.github.io/CSS-Exchange/Diagnostics/) |

## Limitations

- `analyze_workbook.py` supports `.xlsx` and `.xlsm` only. Legacy `.xls` files require conversion first (File → Save As → .xlsx) or use of `xlrd` library.
- `.xlsb` (binary workbook) requires `pyxlsb` — not currently supported by the analyzer.
- Very large workbooks (>50 MB) automatically use quick-scan mode, which may not inspect every cell.
- The analyzer reads formulas as stored in the file. If a workbook was last saved with "manual calculation" mode, some formula cells may show cached values instead of formula strings.

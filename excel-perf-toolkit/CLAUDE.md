# Excel Performance Diagnostic Toolkit

IT support toolkit for diagnosing and remediating slow Excel workbooks on network shares (SMB/CIFS).

## Components

- `Scan-ExcelShares.ps1` — PowerShell share scanner. Recurses UNC paths, exports triage CSV sorted by file size. Params: -SharePaths (mandatory), -OutputPath, -MinSizeMB (default 1).
- `analyze_workbook.py` — Python workbook analyzer. Inspects .xlsx/.xlsm for phantom ranges, volatile functions, external links, style bloat, broken named ranges, residual formatting, VBA. Depends on openpyxl. Exit 0=clean, 1=critical findings.
- `generate_test_workbook.py` — Generates a deliberately bloated .xlsx with all pathologies for testing.
- `KB_Excel_Workbook_Performance.md` — Remediation playbook / KB article.

## Code Rules

- Production minimal: shortest possible, no logging frameworks, no overengineering
- PowerShell: $ErrorActionPreference = 'Stop', structured exit codes
- Python: stdlib + openpyxl only, no unnecessary dependencies
- All scripts must be idempotent and portable (no hardcoded paths)

## Test Workflow

```bash
pip install openpyxl
python generate_test_workbook.py
python analyze_workbook.py test_bloated.xlsx
```

Expected: 2 critical, 6 warning, 0 info. Clean Sheet should have zero findings.

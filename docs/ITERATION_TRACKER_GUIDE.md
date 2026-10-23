# Half-car iteration tracker

Open **Half_Car_Iteration_Tracker.xlsx** in desktop Excel. It is a macro-free offline log; no server or account is needed. It records results, but does not run MATLAB or import data automatically.

## First run

1. Open **Start Here** for the workflow. RUN-001 contains the current example inputs and is marked **Template / not run**; its outputs are deliberately blank.
2. In **Run Index**, record the run name, time and timezone, parent run, code version, loading condition, what changed, and the hypothesis. Use a new ID for every iteration; don't overwrite completed records.
3. Fill the matching ID's **Vehicle Inputs** and **Road and Solver** rows. Blue cells accept data; grey cells calculate. Read header comments for SI units and spring-to-wheel conversions. The example mass convention is deliberately **Unconfirmed**.
4. In **Bumps**, enter one row per active bump, numbered from 1. Enter the gap after each bump except the final one. Zero means touching; a blank gap between bumps means missing information. A single bump needs one row and no gap.
5. Run MATLAB. Copy the eight **Value** metrics into **Outputs** in the displayed order and SI units. Copy the reported convergence result and first contact-warning time. The sheet converts metres to mm and radians to degrees automatically. Whole-run RMS should use a recorded, consistent duration.
6. Save the dashboard and raw results into a folder named after the run ID. Enter paths or shared URLs in **Run Index**. Use **Graph Gallery** if you prefer to paste screenshots directly into Excel.
7. Select two IDs on **Compare**. Review inputs and validity flags, then compare the output metrics and open the original time histories. Record the trade-off and next action in Run Index.

## Preserving graphs and data

A suggested layout, when the workbook is kept at the same level as `runs`:

```text
Half_Car_Iteration_Tracker.xlsx
runs/
  RUN-001/
    dashboard.png
    results.mat
    notes.txt
  RUN-002/
    dashboard.png
    results.mat
```

The dashboard image path can then be `runs/RUN-001/dashboard.png`. To share relative links, share the workbook **and** the run folders together. Absolute local paths only work on machines with those paths. Accessible shared URLs are another option. HYPERLINK behavior depends on the spreadsheet application's file-access settings.

The workbook's two comparison charts show summary acceleration and suspension travel. They do not reconstruct the original time histories; preserve the images or raw data for that purpose. Open Excel and allow its normal formula calculation so the comparison updates.

## Important interpretation rules

- Blank = unknown, not zero or PASS. No example output values have been invented.
- Negative entered minimum tire loads produce a contact violation flag. Missing load information remains **Not entered / incomplete**.
- **No negative predicted** is an estimated screen, not proof of physical validation.
- Numerical convergence PASS and physical validation are separate fields.
- Do not compare whole-run RMS without checking the simulation duration and interval definition.
- Keep the chosen one-side or axle-equivalent convention consistent for all vehicle properties.
- Record the actual parameter edits as well as the code commit; a commit cannot describe uncommitted settings.

## Capacity and editing

There are 200 prepared run IDs and 2000 bump rows. Filter or sort whole Excel tables so IDs stay attached to their values. The same ID identifies a record even if different sheets are sorted differently. Do not rename a run ID in just one sheet. The workbook is editable and is not a concurrent database; save backups.

Dropdowns and numerical validation help catch common mistakes, but pasted data can bypass Excel validation. Review every record, especially bump count, dimensions and gaps. Grey cells contain formulas; avoid overwriting them.

The template can be regenerated with `python tools/create_iteration_tracker.py` (requires XlsxWriter). **Regeneration overwrites the template**, so preserve completed workbooks under separate names. The MATLAB physics and simulation files are unchanged by this tracker update.

## Checks performed

The workbook package, sheet/table structure, consistent run IDs, blank engineering outputs, template status, and chart references were checked with openpyxl. Targeted formula checks passed for contact flags, SI conversions, static-load calculation, and the INDEX/MATCH component used to find reordered IDs. Representative formulas were parsed. The third-party evaluator does not handle COUNTIFS nonblank criteria correctly, so those guards were syntax-checked rather than claimed as evaluated. The Excel GUI, recalculation engine, and local-file hyperlink access were not executed in this environment.

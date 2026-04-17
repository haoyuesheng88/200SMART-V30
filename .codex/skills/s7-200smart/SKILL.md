---
name: s7-200smart
description: Use when working with Siemens S7-200 SMART or STEP 7-Micro/WIN SMART, especially STEP 7-Micro/WIN SMART V3, to automate AWL or STL POU import, compile or verify output-window results, and create or validate 200SMART PLC programs such as pulse bag dust collector logic. Trigger on requests mentioning 200smart, MicroWIN SMART, STEP 7-Micro/WIN SMART V3, zidong shuru, daoru, bianyi, yanzheng, budai chuchenqi, maichong chuchen, sige budai, or maichong fa shunxu penchui.
---

# S7-200 SMART

Use this skill for STEP 7-Micro/WIN SMART tasks that need a reliable input-to-output loop: prepare AWL or STL, import it into the open 200SMART software, run compile, and read the software output window.

## Core Workflow

1. Check for a running process named `MWSmart` or `MWSmartV3`.
2. If generating code, prefer an importable ASCII AWL file with an `ORGANIZATION_BLOCK OB1` wrapper unless the user asks for a subroutine. Keep it LAD-friendly: one `NETWORK` should contain one rung or action. Split multiple independent `LD ... output`, `MOV`, and `TON` sequences into separate networks.
3. If the process is `MWSmartV3`, prefer the verified ribbon import flow: open the File tab, open the Import dropdown, choose `POU`, paste the full AWL path into the import dialog, and submit.
4. If the process is `MWSmart`, the legacy right-click `MAIN (OB1)` import flow is still acceptable.
5. Read the output-window listbox after import. Treat import as successful only when the output includes the expected success line.
6. Run compile from the V3 PLC ribbon Compile button or the equivalent compile command in older versions. Treat compile validation as successful only when the output includes a zero-error summary.
7. Also inspect the LAD view after import. Compile can report zero errors while the editor still displays an invalid network if a network is too complex for LAD display. If that happens, split the AWL into smaller networks and reimport.
8. Do not save or overwrite the `.smart` project unless the user explicitly asks. If a save prompt appears during validation, choose No or cancel unless saving is part of the task.

## Bundled Case

Use the bundled default four-bag pulse dust collector case when the user asks for a ready-made example:

- AWL case: `assets/bag-pulse-dust-collector-4bags-ob1.awl`
- I/O and parameter reference: `references/bag-pulse-dust-collector-4bags.md`

Load the reference file only when the user asks about addresses, timing parameters, or control logic details.

## Reusable Script

Use `scripts/import_and_compile_200smart_v3.ps1` when the user asks to automatically import an AWL file into STEP 7-Micro/WIN SMART V3 and verify it. Example:

```powershell
& "C:\Users\QF100\.codex\skills\s7-200smart\scripts\import_and_compile_200smart_v3.ps1" `
  -UseBundledBagPulse4 `
  -ScreenshotPath "C:\Users\QF100\Documents\New project\mwsmart_v3_compile_result.png"
```

Use `scripts/import_and_compile_200smart.ps1` for the older V2.x layout. Example:

```powershell
& "C:\Users\QF100\.codex\skills\s7-200smart\scripts\import_and_compile_200smart.ps1" `
  -AwlPath "C:\Users\QF100\Documents\New project\BagPulseDustCollector_200SMART_OB1.awl" `
  -ScreenshotPath "C:\Users\QF100\Documents\New project\mwsmart_compile_result.png"
```

The V3 script uses screen offsets from a verified STEP 7-Micro/WIN SMART V3 session. If the V3 UI layout changes, inspect a screenshot and adjust:

- `FileTabOffsetX/FileTabOffsetY`: the File tab click point.
- `ImportSplitOffsetX/ImportSplitOffsetY`: the Import split button.
- `ImportPouOffsetX/ImportPouOffsetY`: the `POU` menu item inside the import dropdown.
- `PlcTabOffsetX/PlcTabOffsetY`: the PLC tab click point.
- `CompileButtonOffsetX/CompileButtonOffsetY`: the Compile button in the PLC ribbon.

The V2 script uses screen offsets from a known STEP 7-Micro/WIN SMART V2.8 layout. If that UI changes, inspect a screenshot and adjust:

- `MainNodeOffsetX/MainNodeOffsetY`: the project-tree `MAIN (OB1)` right-click point.
- `ImportMenuOffsetX/ImportMenuOffsetY`: the context-menu Import click point.
- `CompileButtonOffsetX/CompileButtonOffsetY`: the Compile button click point on the toolbar or ribbon.

## Notes From Verified Session

- Verified application: `C:\Program Files (x86)\Siemens\STEP 7-MicroWIN SMART\MWSmartV3.exe`, process name `MWSmartV3`, window title `Project 1 - STEP 7-Micro/WIN SMART V3`.
- Verified V3 import path: File tab -> Import -> `POU`.
- Verified V3 compile path: PLC tab -> Compile.
- Verified V3 output after import: one success line in the output window.
- Verified V3 compile output ended with a zero-error, zero-warning summary.
- The bundled four-bag pulse dust collector case imported cleanly into `MAIN (OB1)` and compiled with block size `902` bytes and zero errors.
- Importer accepted AWL without `TITLE = ...` network title lines; title lines caused import errors in this environment.
- For LAD display, split complex STL into one-rung-per-network form. A 72-network version of the bag dust collector program imported cleanly and produced no visible invalid-network issues in the verified sessions.

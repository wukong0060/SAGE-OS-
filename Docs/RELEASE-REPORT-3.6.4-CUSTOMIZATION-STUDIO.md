# SAGE OS 3.6.4 — Customization Studio

**Package:** source-only ZIP archive  
**Archive entries:** 1,571  
**Archive size:** approximately 56 MiB  
**SHA-256:** `f5bc445c1505f2c86cf395eb9a503f262be5436b94536bac876bd532eb14f10c`  
**ZIP CRC verification:** passed

## Delivered

- SAGE Control Center Customization Studio page and navigation.
- Four curated, data-only theme packs: Crimson, Void, Monochrome and Fluent.
- Strict JSON Schema 2020-12 format and PowerShell allowlist validation.
- Windows 10/11 native appearance, transparency, Explorer preferences, taskbar search and bundled wallpaper support.
- Windows 11-only taskbar alignment/widgets are skipped on Windows 10.
- Fifteen-minute preview tokens, explicit approval, atomic snapshots, post-apply verification, partial restore, conflict preservation and safe restore retry.
- Self-contained snapshots retain validated theme definitions, allowing restore after an imported theme file is removed.
- Theme pack JSON import/export, native Windows Settings handoffs, and existing SAGE Desktop/Modern Flyouts start/stop controls.

## Validation

- 9/9 Python validators passed.
- 119 Customization Studio static checks passed.
- AME validator: YAML `.yml` 805, JSON 185, XML/XAML 43, active tasks 140.
- Broad source parsing: YAML/YML 807, JSON 185, XML/XAML 43 and project/resource XML 2; zero errors.
- JSON Schema 2020-12 validation passed for all 4 built-in theme packs.
- ZIP CRC and SHA-256 verification passed.

## Platform and implementation limits

The WinUI project API baseline is Windows 10 build 19041; the playbook's supported Windows 10 build is 19045 (Windows 10 22H2), plus listed Windows 11 builds. Accent-color application, lock-screen deployment, sound, pointer and icon packs remain manual/native Settings steps. SAGE does not restart Explorer automatically. This is not a complete custom shell replacement; an advanced drag-and-drop theme editor, dynamic widgets and full icon/cursor/sound installation remain future work.

## Native validation not performed

The authoring environment has no Windows PowerShell 5.1, PowerShell 7 or .NET SDK. The Windows 11 client smoke test is wired into GitHub Actions but has not been executed in this session. No WinUI x64/ARM64 build, Windows 10 GUI test, or encrypted APBX build is claimed. `finalApbxBuiltHere` remains `false`.

## Source ancestry

This 3.6.4 branch was built from the only source archive mounted in the active workspace: the SAGE OS 3.6.3 AME-ready source ZIP. The separate 3.6.7 source archive mentioned earlier was not available in this workspace. This package does not claim to be merged with or contain those separately generated 3.6.5–3.6.7 changes. Rebase the Customization Studio files into the current 3.6.7 source tree when that archive is available.

# SQL Backups

This folder stores SQL scripts used for this project in execution order.

## Files

1. `001_full_reset_schema_and_rls.sql`
   - Full reset + schema + functions + triggers + initial RLS + seed services.
   - Destructive: drops and recreates clinic tables.
2. `002_verify_public_routines.sql`
   - Validation queries for required public routines.
3. `003_daily_tally_staff_rls_fix.sql`
   - Grants staff/admin RLS access to `daily_tally` so staff workflow updates do not fail.

## Usage

- Run from Supabase SQL Editor.
- Apply in numeric order.
- Keep new changes as new files (e.g., `004_...sql`) instead of editing old files.


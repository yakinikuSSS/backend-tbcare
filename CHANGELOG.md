# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- **Assessment History Writer**: New `IAssessmentHistoryWriter` interface and `SupabaseAssessmentHistoryWriter` implementation to save assessment results directly to Supabase `tbcare_plus.assessment_histories` table via the PostgREST REST API.
- **`AssessmentHistory` model** (`Models/AssessmentHistory.cs`) mapped to the `tbcare_plus.assessment_histories` table, tracked by EF Core.
- **`GET /api/v1/assessment/history-sessions`** endpoint to list assessment sessions grouped by `assessmentTypeId` and timestamp, returning a session key, risk level, and TB type for each session.
- **`GET /api/v1/assessment/history-sessions/{sessionKey}`** endpoint to retrieve the full detail of a specific assessment session, decoded from a Base64URL session key.
- **`GET /api/v1/assessment/history/{id}`** endpoint to retrieve individual assessment history records with full symptom and score breakdown.
- **Schema GRANT permissions** in `tbcare_plus_full_setup.sql` to allow `anon`, `authenticated`, and `service_role` roles to access the `tbcare_plus` schema via PostgREST.

### Changed
- **`AssessmentController.SubmitAssessment`** (`POST /api/v1/assessment/submit`) now fully calculates and saves results server-side using EF Core (`AppDbContext`) rather than delegating to the client or calling Supabase directly.
- **Quick assessment save-blocking logic**: When `assessmentTypeId == 1` (quick check), the server checks if the user already has a `full_assessment` entry (type `2`). If so, the quick assessment result is **not** saved to the database, but the calculated result is still returned. Full assessments can always be saved.
- **`AppDbContext`** updated to include `DbSet<AssessmentHistory>` and map the `tbcare_plus.assessment_histories` table via EF Core.
- **`Program.cs`** updated to register `IAssessmentHistoryWriter` → `SupabaseAssessmentHistoryWriter` as a scoped service.

### Fixed
- **Double-entry bug**: Removed redundant direct Supabase insert via `IAssessmentHistoryWriter` in `SubmitAssessment` — assessment history is now saved exactly once using EF Core.
- **Permission denied error** (`403 Forbidden`): Added `GRANT USAGE ON SCHEMA tbcare_plus` and `GRANT ALL ON ALL TABLES` for required Supabase roles in `tbcare_plus_full_setup.sql`.

### Removed
- `schema.sql` — replaced by the comprehensive `tbcare_plus_full_setup.sql` schema file.

### Added
- Bypassed Supabase email confirmation by including `email_confirm: true` in user metadata upon registration in `AuthController.cs`.
- Improved error handling in `AuthController.cs` by implementing `ParseSupabaseError` to dynamically check and return human-readable error descriptions from various Supabase error response shapes.
- New `Profile` model (`Models/Profile.cs`) mapped to the `profiles` table for local user profile storage synced with Supabase Auth.
- `GET /api/v1/auth/me` endpoint in `AuthController` to retrieve the current authenticated user's profile (nickname, email) from the local `profiles` table.
- Auto-sync logic in `AuthController.Login` to create or update a local `profiles` record whenever a user logs in, pulling `display_name` from Supabase user metadata.

### Changed
- `AssessmentController` now only serves assessment configuration endpoints (`GET /config`, `GET /full-config`); submission/diagnosis logic has been removed and moved to client-side calculation.

### Fixed
- Verified and aligned integration compatibility with mobile client's client-side saturation calculation.
- `AppDbContext` updated to remove `DbSet` references for `AssessmentSession`, `AssessmentAnswer`, and `AssessmentResult`; added `DbSet<Profile>` for the profiles table.
- `Program.cs` cleaned up: removed `IDiagnosisService`/`DiagnosisService` service registration.
- `schema.sql` updated to remove `assessment_sessions`, `assessment_answers`, and `assessment_results` table definitions; added `profiles` table definition.

### Removed
- `AssessmentSession` model (`Models/AssessmentSession.cs`) — assessment sessions are no longer tracked server-side.
- `AssessmentAnswer` model (`Models/AssessmentAnswer.cs`) — individual answers are no longer stored server-side.
- `AssessmentResult` model (`Models/AssessmentResult.cs`) — diagnosis results are now calculated client-side.
- `IDiagnosisService` interface (`Interfaces/IDiagnosisService.cs`) — server-side diagnosis is no longer used.
- `DiagnosisService` implementation (`Service/DiagnosisService.cs`) — replaced by client-side saturation formula calculation.

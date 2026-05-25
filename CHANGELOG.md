# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Bypassed Supabase email confirmation by including `email_confirm: true` in user metadata upon registration in `AuthController.cs`.
- Improved error handling in `AuthController.cs` by implementing `ParseSupabaseError` to dynamically check and return human-readable error descriptions from various Supabase error response shapes.
- New `Profile` model (`Models/Profile.cs`) mapped to the `profiles` table for local user profile storage synced with Supabase Auth.
- `GET /api/v1/auth/me` endpoint in `AuthController` to retrieve the current authenticated user's profile (nickname, email) from the local `profiles` table.
- Auto-sync logic in `AuthController.Login` to create or update a local `profiles` record whenever a user logs in, pulling `display_name` from Supabase user metadata.

### Changed
- `AssessmentController` now only serves assessment configuration endpoints (`GET /config`, `GET /full-config`); submission/diagnosis logic has been removed and moved to client-side calculation.
- `AppDbContext` updated to remove `DbSet` references for `AssessmentSession`, `AssessmentAnswer`, and `AssessmentResult`; added `DbSet<Profile>` for the profiles table.
- `Program.cs` cleaned up: removed `IDiagnosisService`/`DiagnosisService` service registration.
- `schema.sql` updated to remove `assessment_sessions`, `assessment_answers`, and `assessment_results` table definitions; added `profiles` table definition.

### Removed
- `AssessmentSession` model (`Models/AssessmentSession.cs`) — assessment sessions are no longer tracked server-side.
- `AssessmentAnswer` model (`Models/AssessmentAnswer.cs`) — individual answers are no longer stored server-side.
- `AssessmentResult` model (`Models/AssessmentResult.cs`) — diagnosis results are now calculated client-side.
- `IDiagnosisService` interface (`Interfaces/IDiagnosisService.cs`) — server-side diagnosis is no longer used.
- `DiagnosisService` implementation (`Service/DiagnosisService.cs`) — replaced by client-side saturation formula calculation.

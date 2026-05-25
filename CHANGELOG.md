# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Bypassed Supabase email confirmation by including `email_confirm: true` in user metadata upon registration in `AuthController.cs`.
- Improved error handling in `AuthController.cs` by implementing `ParseSupabaseError` to dynamically check and return human-readable error descriptions from various Supabase error response shapes.

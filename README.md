# TBCare+ API

ASP.NET Core backend for the TBCare+ tuberculosis early-detection expert system. Provides REST APIs for authentication, symptom assessment, risk calculation, and assessment history.

## Tech Stack

- **Runtime**: .NET 10
- **Framework**: ASP.NET Core Web API
- **Database**: PostgreSQL (via Entity Framework Core + Npgsql)
- **Auth**: Supabase JWT — symmetric HS256 (JWT secret) or asymmetric RS256 (JWKS via Authority); refresh tokens enable silent session renewal
- **API Docs**: Swagger / OpenAPI (Bearer auth) served at the root — **Development only**
- **CORS**: Configurable allowed origins via `Cors:AllowedOrigins`
- **Deploy**: Azure App Service. Honors `X-Forwarded-Proto`/`-For` and enforces HTTPS redirection behind the App Service reverse proxy in non-Development environments

## Endpoints

### Auth

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login, returns Supabase JWT + refresh token |
| POST | `/api/v1/auth/refresh` | Exchange a refresh token for a new access token (silent session renewal) |
| GET | `/api/v1/auth/me` | Get current user profile |
| PUT | `/api/v1/auth/me` | Update user profile |
| POST | `/api/v1/auth/change-password` | Change password |

### Assessment

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/assessment/quick-check-config` | Quick check question config |
| GET | `/api/v1/assessment/full-assessment-config` | Full assessment question config |
| POST | `/api/v1/assessment/submit` | Submit assessment answers |
| GET | `/api/v1/assessment/history` | List individual assessment records |
| GET | `/api/v1/assessment/history-sessions` | List grouped history sessions |
| GET | `/api/v1/assessment/history-sessions/{key}` | Session detail with insights |
| GET | `/api/v1/assessment/history/{id}` | Single assessment details |

### Configuration / Reference Data

CRUD endpoints backing the expert-system knowledge base and the assessment config served to clients. Read (`GET`) endpoints are public; create/update/delete require a valid JWT.

| Method | Path | Description |
|--------|------|-------------|
| GET / POST / PUT / DELETE | `/api/v1/assessment-types` | Assessment types (quick check, full) |
| GET (`by-type/{id}`) / POST / PUT / DELETE | `/api/v1/assessment-questions` | Questions per assessment type |
| GET / POST / PUT / DELETE | `/api/v1/symptoms` | Symptom catalog |
| GET / POST / PUT / DELETE | `/api/v1/tb-types` | TB types for cross-type scoring |
| GET / POST / PUT / DELETE | `/api/v1/risk-levels` | Risk level thresholds |
| GET | `/api/v1/risk-rules` | Symptom-to-TB-type certainty rules |

## Getting Started

### Prerequisites

- .NET 10 SDK
- PostgreSQL (or Supabase project)

### Configuration

Copy `.env.example` to `.env` in `TBCareApp/` and fill in your values:

```bash
cp .env.example .env
```

The template documents every variable and where to find each value in the Supabase dashboard. In short:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-key
SUPABASE_JWT_SECRET=your-jwt-secret
DATABASE_URL=Host=your-pooler.supabase.com;Port=5432;Database=postgres;Username=postgres.xxx;Password=your-password;SSL Mode=Require;Trust Server Certificate=true
# Optional
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
```

Alternatively, configure `appsettings.json` directly.

> **The `.env` file is loaded only in Development.** In Production (Azure App Service),
> set the same keys as **Configuration → Application settings** instead. `SUPABASE_JWT_SECRET`
> is **required** there — the app throws at startup if it's missing.

### Run

```bash
cd TBCareApp
dotnet run
```

The API starts at `http://localhost:5181` with Swagger UI at the root.

## Health Probes

Unauthenticated endpoints for cloud load balancers and platform health checks (e.g. the Azure App Service **Health check** path):

| Method | Path | Description |
|--------|------|-------------|
| GET | `/healthz` | Liveness — returns `200` if the process is running |
| GET | `/readyz` | Readiness — returns `200` only if the database is reachable |

## Project Structure

```
TBCareApp/
├── Controllers/    # API controllers
├── Data/           # AppDbContext + init.sql (schema/seed)
├── DTOs/           # Request/response models
├── Interfaces/     # Service interfaces
├── Models/         # Domain entities (Profile, Symptom, TbType, RiskRule, ...)
├── Service/        # Business logic, Supabase history writer
└── Program.cs      # App entry point, DI, JWT auth, CORS, Swagger
```

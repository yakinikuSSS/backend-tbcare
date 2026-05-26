using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using TBCarePlus.API.Data;
using TBCarePlus.API.Interfaces;
using TBCarePlus.API.Services;

var builder = WebApplication.CreateBuilder(args);

// ── Load .env file (development only) ─────────────────────────────
if (builder.Environment.IsDevelopment())
{
    var envPath = Path.Combine(builder.Environment.ContentRootPath, ".env");
    if (File.Exists(envPath))
    {
        foreach (var line in File.ReadAllLines(envPath))
        {
            var trimmed = line.Trim();
            if (string.IsNullOrEmpty(trimmed) || trimmed.StartsWith('#')) continue;

            var eq = trimmed.IndexOf('=');
            if (eq <= 0) continue;

            var key = trimmed[..eq].Trim();
            var val = trimmed[(eq + 1)..].Trim().TrimEnd('\r');

            if (val.Length >= 2 && ((val[0] == '\'' && val[^1] == '\'') || (val[0] == '"' && val[^1] == '"')))
                val = val[1..^1];

            Environment.SetEnvironmentVariable(key, val);
        }
        Console.WriteLine("Loaded .env file.");
    }
    else
    {
        Console.WriteLine(".env file not found at: " + envPath);
    }
}

// ── Override config from environment variables ────────────────────
var dbUrl = Environment.GetEnvironmentVariable("DATABASE_URL");
if (!string.IsNullOrEmpty(dbUrl))
{
    builder.Configuration["ConnectionStrings:DefaultConnection"] = dbUrl;
    Console.WriteLine("Using DATABASE_URL from environment.");
}

var supabaseUrl = Environment.GetEnvironmentVariable("SUPABASE_URL");
if (!string.IsNullOrEmpty(supabaseUrl))
    builder.Configuration["Supabase:Url"] = supabaseUrl.TrimEnd('/');

var supabaseKey = Environment.GetEnvironmentVariable("SUPABASE_KEY");
if (!string.IsNullOrEmpty(supabaseKey))
    builder.Configuration["Supabase:Key"] = supabaseKey;

var supabaseServiceRoleKey = Environment.GetEnvironmentVariable("SUPABASE_SERVICE_ROLE_KEY");
if (!string.IsNullOrEmpty(supabaseServiceRoleKey))
    builder.Configuration["Supabase:ServiceRoleKey"] = supabaseServiceRoleKey;

var supabaseJwtSecret = Environment.GetEnvironmentVariable("SUPABASE_JWT_SECRET");
if (!string.IsNullOrEmpty(supabaseJwtSecret))
    builder.Configuration["Supabase:JwtSecret"] = supabaseJwtSecret;

// ── Database ───────────────────────────────────────────────────────
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(
        builder.Configuration.GetConnectionString("DefaultConnection"),
        npgsql =>
        {
            npgsql.MigrationsHistoryTable("__EFMigrationsHistory", "tbcare_plus");
            npgsql.EnableRetryOnFailure(maxRetryCount: 3);
        }));

// ── JWT Authentication ──────────────────────────────────────────────
var jwtSecret = builder.Configuration["Supabase:JwtSecret"];
byte[]? signingKeyBytes = null;

if (!string.IsNullOrEmpty(jwtSecret))
{
    try
    {
        signingKeyBytes = Convert.FromBase64String(jwtSecret);
        if (signingKeyBytes.Length < 16)
            signingKeyBytes = Encoding.UTF8.GetBytes(jwtSecret);
    }
    catch
    {
        signingKeyBytes = Encoding.UTF8.GetBytes(jwtSecret);
    }
}

if (signingKeyBytes is null)
{
    if (builder.Environment.IsDevelopment())
    {
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("WARNING: Supabase:JwtSecret is not configured. Authentication will not be enforced.");
        Console.ResetColor();
    }
    else
    {
        throw new InvalidOperationException("Missing configuration key 'Supabase:JwtSecret'.");
    }
}

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var supabaseUrl = builder.Configuration["Supabase:Url"];

        // Supabase may sign JWTs either symmetrically (HS256, using JWT secret) or asymmetrically (RS256 with kid via JWKS).
        // Always set Authority so JwtBearer can fetch JWKS when tokens contain `kid`.
        if (!string.IsNullOrEmpty(supabaseUrl))
            options.Authority = $"{supabaseUrl}/auth/v1";

        if (builder.Environment.IsDevelopment())
            options.RequireHttpsMetadata = false;

        options.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = ctx =>
            {
                ctx.HttpContext.RequestServices
                    .GetRequiredService<ILoggerFactory>()
                    .CreateLogger("JwtBearer")
                    .LogWarning(ctx.Exception, "JWT authentication failed: {Message}", ctx.Exception.Message);
                return Task.CompletedTask;
            },
        };

        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = signingKeyBytes is not null || !string.IsNullOrEmpty(supabaseUrl),
            // If HS256 is used, this symmetric key will validate.
            // If RS256+JWKS is used, JwtBearer will use keys from the Authority metadata instead.
            IssuerSigningKey         = signingKeyBytes is not null ? new SymmetricSecurityKey(signingKeyBytes) : null,
            ValidateIssuer           = false,
            ValidateAudience         = false,
            ValidateLifetime         = true,
            ClockSkew                = TimeSpan.Zero,
            NameClaimType            = "sub",
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddHttpClient();

// ── Service Registrations ──────────────────────────────────────────
builder.Services.AddScoped<ITbTypeService,    TbTypeService>();
builder.Services.AddScoped<ISymptomService,   SymptomService>();
builder.Services.AddScoped<IAssessmentService, AssessmentService>();
builder.Services.AddScoped<IRiskLevelService, RiskLevelService>();
builder.Services.AddScoped<IAssessmentHistoryWriter, SupabaseAssessmentHistoryWriter>();

// ── CORS ────────────────────────────────────────────────────────────
var allowedOrigins = builder.Configuration
    .GetSection("Cors:AllowedOrigins")
    .Get<string[]>() ?? ["*"];

builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy =>
    {
        if (allowedOrigins is ["*"])
            policy.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
        else
            policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod();
    }));

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "TBCare+ API",
        Version = "v1",
        Description = "Tuberculosis early-detection expert system API.",
    });

    var securityScheme = new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Description = "Enter: Bearer {your Supabase JWT}",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        Reference = new OpenApiReference
        {
            Id = JwtBearerDefaults.AuthenticationScheme,
            Type = ReferenceType.SecurityScheme,
        },
    };
    c.AddSecurityDefinition(securityScheme.Reference.Id, securityScheme);
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        { securityScheme, Array.Empty<string>() },
    });

    var xmlFile = $"{System.Reflection.Assembly.GetExecutingAssembly().GetName().Name}.xml";
    var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
    if (File.Exists(xmlPath)) c.IncludeXmlComments(xmlPath);
});

// ── Railway: listen on PORT if set ─────────────────────────────────
var railwayPort = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrEmpty(railwayPort))
{
    builder.WebHost.UseUrls($"http://+:{railwayPort}");
    Console.WriteLine($"Railway detected. Listening on port {railwayPort}.");
}

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(c =>
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "TBCare+ API v1");
        c.RoutePrefix = string.Empty;
    });
}

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();

using (var scope = app.Services.CreateScope())
{
    var context = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await context.Database.MigrateAsync();
}

await app.RunAsync();

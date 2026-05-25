using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using TBCarePlus.API.DTOs;

namespace TBCarePlus.API.Controllers;

[ApiController]
[Route("api/v1/auth")]
public class AuthController : ControllerBase
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _config;

    public AuthController(IHttpClientFactory httpClientFactory, IConfiguration config)
    {
        _httpClientFactory = httpClientFactory;
        _config = config;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] AuthRegisterRequest request)
    {
        var supabaseUrl = _config["Supabase:Url"];
        var supabaseKey = _config["Supabase:Key"];

        if (string.IsNullOrEmpty(supabaseUrl) || string.IsNullOrEmpty(supabaseKey))
            return StatusCode(500, ApiResponse<object>.Fail("Supabase configuration is missing."));

        using var http = _httpClientFactory.CreateClient();

        var signupPayload = new
        {
            email = request.Email,
            password = request.Password,
            options = new
            {
                data = new
                {
                    full_name = request.FullName ?? "",
                    email_confirm = true
                }
            }
        };

        var requestBody = new StringContent(
            JsonSerializer.Serialize(signupPayload), Encoding.UTF8, "application/json");

        var httpRequest = new HttpRequestMessage(HttpMethod.Post, $"{supabaseUrl}/auth/v1/signup")
        {
            Content = requestBody
        };
        httpRequest.Headers.Add("apikey", supabaseKey);

        var response = await http.SendAsync(httpRequest);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            var msg = ParseSupabaseError(responseBody, "Registration failed.");
            return BadRequest(ApiResponse<object>.Fail(msg));
        }

        var authResponse = BuildAuthResponse(responseBody);

        return Created(string.Empty, ApiResponse<AuthResponseDto>.Ok(authResponse, "Registration successful."));
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] AuthLoginRequest request)
    {
        var supabaseUrl = _config["Supabase:Url"];
        var supabaseKey = _config["Supabase:Key"];

        if (string.IsNullOrEmpty(supabaseUrl) || string.IsNullOrEmpty(supabaseKey))
            return StatusCode(500, ApiResponse<object>.Fail("Supabase configuration is missing."));

        using var http = _httpClientFactory.CreateClient();

        var loginPayload = new { email = request.Email, password = request.Password };

        var requestBody = new StringContent(
            JsonSerializer.Serialize(loginPayload), Encoding.UTF8, "application/json");

        var httpRequest = new HttpRequestMessage(HttpMethod.Post,
            $"{supabaseUrl}/auth/v1/token?grant_type=password")
        {
            Content = requestBody
        };
        httpRequest.Headers.Add("apikey", supabaseKey);

        var response = await http.SendAsync(httpRequest);
        var responseBody = await response.Content.ReadAsStringAsync();

        if (!response.IsSuccessStatusCode)
        {
            var msg = ParseSupabaseError(responseBody, "Login failed.");
            return Unauthorized(ApiResponse<object>.Fail(msg));
        }

        var authResponse = BuildAuthResponse(responseBody);

        return Ok(ApiResponse<AuthResponseDto>.Ok(authResponse, "Login successful."));
    }

    /// <summary>
    /// Parses a Supabase error response body into a human-readable message.
    /// Supabase uses different error shapes depending on the endpoint:
    ///   OAuth token errors:  { "error": "...", "error_description": "..." }
    ///   Auth REST errors:    { "code": 400, "error_code": "...", "msg": "..." }
    ///   GoTrue v2 errors:    { "message": "..." }
    /// </summary>
    private static string ParseSupabaseError(string responseBody, string fallback)
    {
        try
        {
            using var doc = JsonDocument.Parse(responseBody);
            var root = doc.RootElement;

            // OAuth token endpoint format
            if (root.TryGetProperty("error_description", out var ed) && ed.ValueKind == JsonValueKind.String)
                return ed.GetString()!;

            // GoTrue v2 / newer format
            if (root.TryGetProperty("message", out var message) && message.ValueKind == JsonValueKind.String)
                return message.GetString()!;

            // GoTrue v1 format
            if (root.TryGetProperty("msg", out var msg) && msg.ValueKind == JsonValueKind.String)
                return msg.GetString()!;

            // Generic error field
            if (root.TryGetProperty("error", out var err) && err.ValueKind == JsonValueKind.String)
                return err.GetString()!;
        }
        catch { /* JSON parse failed, fall through */ }

        return fallback;
    }

    private static AuthResponseDto BuildAuthResponse(string supabaseResponseJson)
    {
        using var doc = JsonDocument.Parse(supabaseResponseJson);
        var root = doc.RootElement;

        var user = root.GetProperty("user");
        var userId = user.GetProperty("id").GetString()!;
        var email = user.GetProperty("email").GetString();
        var createdAt = user.TryGetProperty("created_at", out var ca)
            ? ca.GetDateTime() : DateTime.UtcNow;
        var updatedAt = user.TryGetProperty("updated_at", out var ua)
            ? ua.GetDateTime() : DateTime.UtcNow;

        var metadata = user.TryGetProperty("user_metadata", out var um) ? um : default;
        var fullName = metadata.ValueKind != JsonValueKind.Undefined
            && metadata.TryGetProperty("full_name", out var fn) ? fn.GetString() : null;

        return new AuthResponseDto
        {
            AccessToken = root.GetProperty("access_token").GetString()!,
            RefreshToken = root.GetProperty("refresh_token").GetString()!,
            ExpiresIn = root.GetProperty("expires_in").GetInt32(),
            User = new UserDto
            {
                Id = userId,
                Email = email,
                FullName = fullName,
                Role = user.TryGetProperty("role", out var r) ? r.GetString() : null,
                IsActive = true,
                CreatedAt = createdAt,
                UpdatedAt = updatedAt,
            },
        };
    }
}

public class AuthRegisterRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string? FullName { get; set; }
}

public class AuthLoginRequest
{
    public string Email { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
}

public class AuthResponseDto
{
    public string AccessToken { get; set; } = string.Empty;
    public string RefreshToken { get; set; } = string.Empty;
    public int ExpiresIn { get; set; }
    public UserDto User { get; set; } = null!;
}

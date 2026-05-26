using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using TBCarePlus.API.Interfaces;
using TBCarePlus.API.Models;

namespace TBCarePlus.API.Services;

public class SupabaseAssessmentHistoryWriter : IAssessmentHistoryWriter
{
    private readonly IHttpClientFactory _httpClientFactory;
    private readonly IConfiguration _config;
    private const string DefaultSchema = "tbcare_plus";

    public SupabaseAssessmentHistoryWriter(IHttpClientFactory httpClientFactory, IConfiguration config)
    {
        _httpClientFactory = httpClientFactory;
        _config = config;
    }

    public async Task<IReadOnlyList<long>> InsertAsync(
        IEnumerable<AssessmentHistory> histories,
        string? userBearerToken,
        CancellationToken cancellationToken = default)
    {
        var supabaseUrl = _config["Supabase:Url"]?.TrimEnd('/');
        var supabaseKey = _config["Supabase:Key"];
        var serviceRoleKey = _config["Supabase:ServiceRoleKey"];
        var schema = _config["Supabase:DbSchema"];

        if (string.IsNullOrWhiteSpace(supabaseUrl))
            throw new InvalidOperationException("Supabase:Url is not configured.");

        var apiKey = !string.IsNullOrWhiteSpace(serviceRoleKey) ? serviceRoleKey : supabaseKey;
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new InvalidOperationException("Supabase API key is not configured. Set SUPABASE_KEY (or SUPABASE_SERVICE_ROLE_KEY).");

        var bearer = !string.IsNullOrWhiteSpace(serviceRoleKey) ? serviceRoleKey : userBearerToken;
        if (string.IsNullOrWhiteSpace(bearer))
            throw new InvalidOperationException("No bearer token available for Supabase insert.");

        var payload = histories.Select(ToSupabasePayload).ToList();

        using var http = _httpClientFactory.CreateClient();
        var req = new HttpRequestMessage(HttpMethod.Post, $"{supabaseUrl}/rest/v1/assessment_histories?select=id");
        req.Headers.Add("apikey", apiKey);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", bearer);
        // Supabase PostgREST defaults to `public` schema; our tables live under `tbcare_plus`.
        var targetSchema = string.IsNullOrWhiteSpace(schema) ? DefaultSchema : schema.Trim();
        req.Headers.TryAddWithoutValidation("Accept-Profile", targetSchema);
        req.Headers.TryAddWithoutValidation("Content-Profile", targetSchema);
        req.Headers.TryAddWithoutValidation("Prefer", "return=representation");
        req.Content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");

        var res = await http.SendAsync(req, cancellationToken);
        var body = await res.Content.ReadAsStringAsync(cancellationToken);

        if (!res.IsSuccessStatusCode)
            throw new InvalidOperationException($"Supabase insert failed ({(int)res.StatusCode}): {body}");

        return TryParseReturnedIds(body);
    }

    private static IReadOnlyList<long> TryParseReturnedIds(string body)
    {
        try
        {
            using var doc = JsonDocument.Parse(body);
            if (doc.RootElement.ValueKind != JsonValueKind.Array)
                return Array.Empty<long>();

            var ids = new List<long>();
            foreach (var item in doc.RootElement.EnumerateArray())
            {
                if (item.TryGetProperty("id", out var idEl) && idEl.ValueKind == JsonValueKind.Number && idEl.TryGetInt64(out var id))
                    ids.Add(id);
            }
            return ids;
        }
        catch
        {
            return Array.Empty<long>();
        }
    }

    private static object ToSupabasePayload(AssessmentHistory h)
    {
        var selectedSymptoms = ParseJsonOrDefault(h.SelectedSymptoms, JsonValueKind.Array, "[]");
        var scoreBreakdown = ParseJsonOrDefault(h.ScoreBreakdown, JsonValueKind.Object, "{}");

        return new Dictionary<string, object?>
        {
            ["user_id"] = h.UserId,
            ["assessment_type_id"] = h.AssessmentTypeId,
            ["primary_tb_type_id"] = h.PrimaryTbTypeId,
            ["risk_level_id"] = h.RiskLevelId,
            ["total_score"] = h.TotalScore,
            ["selected_symptoms"] = selectedSymptoms,
            ["score_breakdown"] = scoreBreakdown,
            ["result_note"] = h.ResultNote,
            ["created_at"] = h.CreatedAt == default ? DateTime.UtcNow : h.CreatedAt,
        };
    }

    private static JsonElement ParseJsonOrDefault(string? json, JsonValueKind expectedKind, string fallback)
    {
        try
        {
            using var doc = JsonDocument.Parse(string.IsNullOrWhiteSpace(json) ? fallback : json);
            if (doc.RootElement.ValueKind == expectedKind)
                return doc.RootElement.Clone();
        }
        catch { /* fall through */ }

        using var fb = JsonDocument.Parse(fallback);
        return fb.RootElement.Clone();
    }
}

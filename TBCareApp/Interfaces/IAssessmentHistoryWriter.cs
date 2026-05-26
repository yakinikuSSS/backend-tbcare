using TBCarePlus.API.Models;

namespace TBCarePlus.API.Interfaces;

public interface IAssessmentHistoryWriter
{
    Task<IReadOnlyList<long>> InsertAsync(
        IEnumerable<AssessmentHistory> histories,
        string? userBearerToken,
        CancellationToken cancellationToken = default);
}


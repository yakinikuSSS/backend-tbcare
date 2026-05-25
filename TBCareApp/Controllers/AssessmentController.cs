using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TBCarePlus.API.Data;
using TBCarePlus.API.DTOs;

namespace TBCarePlus.API.Controllers;

[ApiController]
[Route("api/v1/assessment")]
[Authorize]
public class AssessmentController : ControllerBase
{
    private readonly AppDbContext _db;

    public AssessmentController(AppDbContext db)
    {
        _db = db;
    }

    [AllowAnonymous]
    [HttpGet("quick-check-config")]
    public async Task<IActionResult> GetQuickCheckConfig()
    {
        const int quickCheckTypeId = 1;

        var assessmentType = await _db.AssessmentTypes.FindAsync(quickCheckTypeId);

        var questions = await _db.AssessmentQuestions
            .Include(q => q.Symptom)
            .Where(q => q.AssessmentTypeId == quickCheckTypeId)
            .OrderBy(q => q.SortOrder)
            .Select(q => new QuickCheckQuestionDto
            {
                QuestionId = q.Id,
                SymptomId = q.SymptomId,
                SymptomCode = q.Symptom.Code,
                SymptomName = q.Symptom.Name,
                SymptomDescription = q.Symptom.Description,
                QuestionText = q.QuestionText,
                SortOrder = q.SortOrder,
                IsRequired = q.IsRequired,
                Weight = _db.RiskRules
                    .Where(r => r.AssessmentTypeId == quickCheckTypeId
                             && r.SymptomId == q.SymptomId
                             && r.IsActive)
                    .Select(r => r.Weight)
                    .FirstOrDefault(),
                TbTypeId = q.Symptom.TbTypeId,
                TbTypeName = q.Symptom.TbType.Name,
            })
            .ToListAsync();

        var distinctTbTypeIds = questions.Select(q => q.TbTypeId).Distinct().ToList();

        var riskLevels = await _db.RiskLevels
            .Where(rl => distinctTbTypeIds.Contains(rl.TbTypeId))
            .Select(rl => new RiskLevelDto
            {
                Id = rl.Id,
                TbTypeId = rl.TbTypeId,
                Code = rl.Code,
                Title = rl.Title,
                MinScore = rl.MinScore,
                MaxScore = rl.MaxScore,
                Description = rl.Description,
                Recommendation = rl.Recommendation,
            })
            .ToListAsync();

        return Ok(ApiResponse<QuickCheckConfigDto>.Ok(new QuickCheckConfigDto
        {
            Questions = questions,
            RiskLevels = riskLevels,
            ScoringMethod = assessmentType?.ScoringMethod ?? "soft_saturation_cf",
            SaturationK = assessmentType?.SaturationK ?? 0.35,
        }));
    }

    [AllowAnonymous]
    [HttpGet("full-assessment-config")]
    public async Task<IActionResult> GetFullAssessmentConfig()
    {
        const int fullAssessmentTypeId = 2;

        var assessmentType = await _db.AssessmentTypes.FindAsync(fullAssessmentTypeId);

        var questions = await _db.AssessmentQuestions
            .Include(q => q.Symptom)
            .Where(q => q.AssessmentTypeId == fullAssessmentTypeId)
            .OrderBy(q => q.SortOrder)
            .Select(q => new QuickCheckQuestionDto
            {
                QuestionId = q.Id,
                SymptomId = q.SymptomId,
                SymptomCode = q.Symptom.Code,
                SymptomName = q.Symptom.Name,
                SymptomDescription = q.Symptom.Description,
                QuestionText = q.QuestionText,
                SortOrder = q.SortOrder,
                IsRequired = q.IsRequired,
                Weight = _db.RiskRules
                    .Where(r => r.AssessmentTypeId == fullAssessmentTypeId
                             && r.SymptomId == q.SymptomId
                             && r.IsActive)
                    .Select(r => r.Weight)
                    .FirstOrDefault(),
                TbTypeId = q.Symptom.TbTypeId,
                TbTypeName = q.Symptom.TbType.Name,
            })
            .ToListAsync();

        var distinctTbTypeIds = questions.Select(q => q.TbTypeId).Distinct().ToList();

        var riskLevels = await _db.RiskLevels
            .Where(rl => distinctTbTypeIds.Contains(rl.TbTypeId))
            .Select(rl => new RiskLevelDto
            {
                Id = rl.Id,
                TbTypeId = rl.TbTypeId,
                Code = rl.Code,
                Title = rl.Title,
                MinScore = rl.MinScore,
                MaxScore = rl.MaxScore,
                Description = rl.Description,
                Recommendation = rl.Recommendation,
            })
            .ToListAsync();

        return Ok(ApiResponse<QuickCheckConfigDto>.Ok(new QuickCheckConfigDto
        {
            Questions = questions,
            RiskLevels = riskLevels,
            ScoringMethod = assessmentType?.ScoringMethod ?? "soft_saturation_cf",
            SaturationK = assessmentType?.SaturationK ?? 0.35,
        }));
    }
}

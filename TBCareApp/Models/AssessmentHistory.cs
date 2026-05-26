using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TBCarePlus.API.Models;

[Table("assessment_histories", Schema = "tbcare_plus")]
public class AssessmentHistory
{
    [Key]
    public long Id { get; set; }

    public Guid UserId { get; set; }

    public int AssessmentTypeId { get; set; }
    public int PrimaryTbTypeId { get; set; }
    public int RiskLevelId { get; set; }

    [Column(TypeName = "numeric")]
    public decimal TotalScore { get; set; } = 0;

    [Column(TypeName = "jsonb")]
    public string SelectedSymptoms { get; set; } = "[]";

    [Column(TypeName = "jsonb")]
    public string ScoreBreakdown { get; set; } = "{}";

    public string? ResultNote { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey("AssessmentTypeId")]
    public virtual AssessmentType AssessmentType { get; set; } = null!;

    [ForeignKey("PrimaryTbTypeId")]
    public virtual TbType PrimaryTbType { get; set; } = null!;

    [ForeignKey("RiskLevelId")]
    public virtual RiskLevel RiskLevel { get; set; } = null!;
}


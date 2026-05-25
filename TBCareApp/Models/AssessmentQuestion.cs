using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace TBCarePlus.API.Models;

[Table("assessment_questions", Schema = "tbcare_plus")]
public class AssessmentQuestion
{
    [Key]
    public int Id { get; set; }

    public int AssessmentTypeId { get; set; }
    public int SymptomId { get; set; }

    [Required]
    public string QuestionText { get; set; } = string.Empty;

    public int SortOrder { get; set; }
    public bool IsRequired { get; set; } = true;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    [ForeignKey(nameof(AssessmentTypeId))]
    public AssessmentType AssessmentType { get; set; } = null!;

    [ForeignKey(nameof(SymptomId))]
    public Symptom Symptom { get; set; } = null!;
}

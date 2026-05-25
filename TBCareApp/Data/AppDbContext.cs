using Microsoft.EntityFrameworkCore;
using TBCarePlus.API.Models;

namespace TBCarePlus.API.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<TbType> TbTypes => Set<TbType>();
    public DbSet<Symptom> Symptoms => Set<Symptom>();
    public DbSet<AssessmentType> AssessmentTypes => Set<AssessmentType>();
    public DbSet<AssessmentQuestion> AssessmentQuestions => Set<AssessmentQuestion>();
    public DbSet<RiskRule> RiskRules => Set<RiskRule>();
    public DbSet<RiskLevel> RiskLevels => Set<RiskLevel>();
    public DbSet<Profile> Profiles => Set<Profile>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.HasDefaultSchema("tbcare_plus");

        modelBuilder.Entity<TbType>(entity =>
        {
            entity.ToTable("tb_types");
            entity.HasIndex(e => e.Code).IsUnique();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("now()");
        });

        modelBuilder.Entity<Symptom>(entity =>
        {
            entity.ToTable("symptoms");
            entity.HasIndex(e => e.Code).IsUnique();
            entity.HasIndex(e => e.TbTypeId).HasDatabaseName("idx_symptoms_tb_type_id");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("now()");
            entity.HasOne(e => e.TbType).WithMany(t => t.Symptoms).HasForeignKey(e => e.TbTypeId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<AssessmentType>(entity =>
        {
            entity.ToTable("assessment_types");
            entity.HasIndex(e => e.Code).IsUnique();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("now()");
        });

        modelBuilder.Entity<AssessmentQuestion>(entity =>
        {
            entity.ToTable("assessment_questions");
            entity.HasIndex(e => e.AssessmentTypeId).HasDatabaseName("idx_assessment_questions_assessment_type_id");
            entity.HasIndex(e => new { e.AssessmentTypeId, e.SymptomId }).IsUnique();
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("now()");
            entity.HasOne(e => e.AssessmentType).WithMany(at => at.AssessmentQuestions).HasForeignKey(e => e.AssessmentTypeId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Symptom).WithMany(s => s.AssessmentQuestions).HasForeignKey(e => e.SymptomId).OnDelete(DeleteBehavior.Restrict);
        });

        modelBuilder.Entity<RiskRule>(entity =>
        {
            entity.ToTable("risk_rules");
            entity.HasIndex(e => e.AssessmentTypeId).HasDatabaseName("idx_risk_rules_assessment_type_id");
            entity.HasIndex(e => e.SymptomId).HasDatabaseName("idx_risk_rules_symptom_id");
            entity.HasIndex(e => e.TbTypeId).HasDatabaseName("idx_risk_rules_tb_type_id");
            entity.HasIndex(e => new { e.AssessmentTypeId, e.SymptomId, e.TbTypeId }).IsUnique();
            entity.Property(e => e.Weight).HasColumnType("numeric(3,1)");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("now()");
            entity.HasOne(e => e.AssessmentType).WithMany(at => at.RiskRules).HasForeignKey(e => e.AssessmentTypeId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.Symptom).WithMany(s => s.RiskRules).HasForeignKey(e => e.SymptomId).OnDelete(DeleteBehavior.Cascade);
            entity.HasOne(e => e.TbType).WithMany(t => t.RiskRules).HasForeignKey(e => e.TbTypeId).OnDelete(DeleteBehavior.Cascade);
        });

        modelBuilder.Entity<RiskLevel>(entity =>
        {
            entity.ToTable("risk_levels");
            entity.HasIndex(e => new { e.TbTypeId, e.Code }).IsUnique();
            entity.HasIndex(e => e.TbTypeId).HasDatabaseName("idx_risk_levels_tb_type_id");
            entity.Property(e => e.CreatedAt).HasDefaultValueSql("now()");
            entity.Property(e => e.UpdatedAt).HasDefaultValueSql("now()");
            entity.HasOne(e => e.TbType).WithMany(t => t.RiskLevels).HasForeignKey(e => e.TbTypeId).OnDelete(DeleteBehavior.Cascade);
        });

        // ── Global snake_case naming convention ─────────────────────
        foreach (var entity in modelBuilder.Model.GetEntityTypes())
        {
            foreach (var property in entity.GetProperties())
            {
                if (property.GetColumnName() == property.Name)
                {
                    var snakeCase = ToSnakeCase(property.Name);
                    property.SetColumnName(snakeCase);
                }
            }

            var pk = entity.FindPrimaryKey();
            if (pk is not null)
            {
                var pkName = pk.GetName();
                if (pkName == $"PK_{entity.ClrType.Name}")
                {
                    pk.SetName($"PK_{ToSnakeCase(entity.ClrType.Name)}");
                }
            }
        }
    }

    private static string ToSnakeCase(string input)
    {
        if (string.IsNullOrEmpty(input)) return input;
        return string.Concat(
            input.Select((c, i) =>
                i > 0 && char.IsUpper(c)
                    ? "_" + char.ToLowerInvariant(c)
                    : char.ToLowerInvariant(c).ToString()
            )
        );
    }
}

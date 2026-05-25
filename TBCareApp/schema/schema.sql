-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE tbcare_plus.__EFMigrationsHistory (
  MigrationId character varying NOT NULL,
  ProductVersion character varying NOT NULL,
  CONSTRAINT __EFMigrationsHistory_pkey PRIMARY KEY (MigrationId)
);
CREATE TABLE tbcare_plus.assessment_histories (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  user_id uuid NOT NULL,
  assessment_type_id bigint NOT NULL,
  primary_tb_type_id bigint NOT NULL,
  risk_level_id bigint NOT NULL,
  total_score numeric NOT NULL DEFAULT 0,
  selected_symptoms jsonb NOT NULL DEFAULT '[]'::jsonb,
  score_breakdown jsonb NOT NULL DEFAULT '{}'::jsonb,
  result_note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT assessment_histories_pkey PRIMARY KEY (id),
  CONSTRAINT assessment_histories_assessment_type_id_fkey FOREIGN KEY (assessment_type_id) REFERENCES tbcare_plus.assessment_types(id),
  CONSTRAINT assessment_histories_primary_tb_type_id_fkey FOREIGN KEY (primary_tb_type_id) REFERENCES tbcare_plus.tb_types(id),
  CONSTRAINT assessment_histories_risk_level_id_fkey FOREIGN KEY (risk_level_id) REFERENCES tbcare_plus.risk_levels(id),
  CONSTRAINT assessment_histories_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE tbcare_plus.assessment_questions (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  assessment_type_id bigint NOT NULL,
  symptom_id bigint NOT NULL,
  question_text text NOT NULL,
  sort_order integer NOT NULL DEFAULT 0,
  is_required boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT assessment_questions_pkey PRIMARY KEY (id),
  CONSTRAINT assessment_questions_assessment_type_id_fkey FOREIGN KEY (assessment_type_id) REFERENCES tbcare_plus.assessment_types(id),
  CONSTRAINT assessment_questions_symptom_id_fkey FOREIGN KEY (symptom_id) REFERENCES tbcare_plus.symptoms(id)
);
CREATE TABLE tbcare_plus.assessment_types (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  scoring_method text NOT NULL DEFAULT 'soft_saturation_cf'::text,
  saturation_k numeric NOT NULL DEFAULT 0.35,
  result_unit text NOT NULL DEFAULT 'percentage'::text,
  CONSTRAINT assessment_types_pkey PRIMARY KEY (id)
);
CREATE TABLE tbcare_plus.profiles (
  id uuid NOT NULL,
  nickname character varying NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE tbcare_plus.risk_levels (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  code text NOT NULL,
  tb_type_id bigint NOT NULL,
  title text NOT NULL,
  min_score numeric NOT NULL CHECK (min_score >= 0::numeric),
  max_score numeric NOT NULL,
  description text,
  recommendation text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT risk_levels_pkey PRIMARY KEY (id),
  CONSTRAINT risk_levels_tb_type_id_fkey FOREIGN KEY (tb_type_id) REFERENCES tbcare_plus.tb_types(id)
);
CREATE TABLE tbcare_plus.risk_rules (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  assessment_type_id bigint NOT NULL,
  symptom_id bigint NOT NULL,
  tb_type_id bigint NOT NULL,
  weight numeric NOT NULL DEFAULT 1.0 CHECK (weight >= '-1.0'::numeric AND weight <= 1.0),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT risk_rules_pkey PRIMARY KEY (id),
  CONSTRAINT risk_rules_assessment_type_id_fkey FOREIGN KEY (assessment_type_id) REFERENCES tbcare_plus.assessment_types(id),
  CONSTRAINT risk_rules_symptom_id_fkey FOREIGN KEY (symptom_id) REFERENCES tbcare_plus.symptoms(id),
  CONSTRAINT risk_rules_tb_type_id_fkey FOREIGN KEY (tb_type_id) REFERENCES tbcare_plus.tb_types(id)
);
CREATE TABLE tbcare_plus.symptoms (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  tb_type_id bigint NOT NULL,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT symptoms_pkey PRIMARY KEY (id),
  CONSTRAINT symptoms_tb_type_id_fkey FOREIGN KEY (tb_type_id) REFERENCES tbcare_plus.tb_types(id)
);
CREATE TABLE tbcare_plus.tb_types (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  description text,
  body_area text,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT tb_types_pkey PRIMARY KEY (id)
);
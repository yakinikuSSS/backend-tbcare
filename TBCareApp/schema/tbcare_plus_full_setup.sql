create schema if not exists tbcare_plus;

create table if not exists tbcare_plus.tb_types (
  id bigint generated always as identity primary key,
  code text not null unique,
  name text not null,
  description text,
  body_area text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists tbcare_plus.symptoms (
  id bigint generated always as identity primary key,
  tb_type_id bigint not null references tbcare_plus.tb_types(id) on delete restrict,
  code text not null unique,
  name text not null,
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists tbcare_plus.assessment_types (
  id bigint generated always as identity primary key,
  code text not null unique,
  name text not null,
  description text,
  scoring_method text not null default 'soft_saturation_cf',
  saturation_k numeric(4, 2) not null default 0.35,
  result_unit text not null default 'percentage',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists tbcare_plus.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nickname text,
  profile_picture text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists tbcare_plus.assessment_questions (
  id bigint generated always as identity primary key,
  assessment_type_id bigint not null references tbcare_plus.assessment_types(id) on delete cascade,
  symptom_id bigint not null references tbcare_plus.symptoms(id) on delete restrict,
  question_text text not null,
  sort_order integer not null default 0,
  is_required boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_type_id, symptom_id)
);

create table if not exists tbcare_plus.risk_rules (
  id bigint generated always as identity primary key,
  assessment_type_id bigint not null references tbcare_plus.assessment_types(id) on delete cascade,
  symptom_id bigint not null references tbcare_plus.symptoms(id) on delete cascade,
  tb_type_id bigint not null references tbcare_plus.tb_types(id) on delete cascade,
  weight numeric(3, 1) not null default 1.0 check (weight between -1.0 and 1.0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_type_id, symptom_id, tb_type_id)
);

create table if not exists tbcare_plus.risk_levels (
  id bigint generated always as identity primary key,
  code text not null,
  tb_type_id bigint not null references tbcare_plus.tb_types(id) on delete cascade,
  title text not null,
  min_score numeric(5, 2) not null check (min_score >= 0),
  max_score numeric(5, 2) not null check (max_score >= min_score),
  description text,
  recommendation text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tb_type_id, code)
);

create table if not exists tbcare_plus.assessment_histories (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  assessment_type_id bigint not null references tbcare_plus.assessment_types(id) on delete restrict,
  primary_tb_type_id bigint not null references tbcare_plus.tb_types(id) on delete restrict,
  risk_level_id bigint not null references tbcare_plus.risk_levels(id) on delete restrict,
  total_score numeric(5, 2) not null default 0,
  selected_symptoms jsonb not null default '[]'::jsonb,
  score_breakdown jsonb not null default '{}'::jsonb,
  result_note text,
  created_at timestamptz not null default now()
);

create index if not exists idx_symptoms_tb_type_id on tbcare_plus.symptoms (tb_type_id);
create index if not exists idx_profiles_nickname on tbcare_plus.profiles (nickname);
create index if not exists idx_assessment_questions_assessment_type_id on tbcare_plus.assessment_questions (assessment_type_id);
create index if not exists idx_risk_rules_assessment_type_id on tbcare_plus.risk_rules (assessment_type_id);
create index if not exists idx_risk_rules_symptom_id on tbcare_plus.risk_rules (symptom_id);
create index if not exists idx_risk_rules_tb_type_id on tbcare_plus.risk_rules (tb_type_id);
create index if not exists idx_risk_levels_tb_type_id on tbcare_plus.risk_levels (tb_type_id);
create index if not exists idx_assessment_histories_user_id on tbcare_plus.assessment_histories (user_id);
create index if not exists idx_assessment_histories_created_at on tbcare_plus.assessment_histories (created_at desc);
create index if not exists idx_assessment_histories_assessment_type_id on tbcare_plus.assessment_histories (assessment_type_id);
create index if not exists idx_assessment_histories_risk_level_id on tbcare_plus.assessment_histories (risk_level_id);

insert into tbcare_plus.tb_types (code, name, description, body_area, is_active, sort_order)
values
  ('pulmonary_tb', 'TBC Paru', 'TBC yang menyerang paru-paru dan umumnya berkaitan dengan batuk lama, dahak, sesak napas, atau nyeri dada.', 'paru-paru', true, 1),
  ('lymph_node_tb', 'TBC Kelenjar', 'TBC yang menyerang kelenjar getah bening, biasanya ditandai dengan benjolan pada area seperti leher, ketiak, atau sela paha.', 'kelenjar getah bening', true, 2),
  ('breast_tb', 'TBC Payudara', 'TBC yang menyerang jaringan payudara dan dapat menimbulkan benjolan, nyeri, atau tanda radang di area payudara.', 'payudara', true, 3),
  ('spinal_tb', 'TBC Tulang Belakang', 'TBC yang menyerang tulang belakang dan dapat berkaitan dengan nyeri, kaku, atau gangguan gerak pada punggung.', 'tulang belakang', true, 4)
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  body_area = excluded.body_area,
  is_active = excluded.is_active,
  sort_order = excluded.sort_order,
  updated_at = now();

insert into tbcare_plus.assessment_types (code, name, description, scoring_method, saturation_k, result_unit)
values
  ('quick_assessment', 'Quick Assessment', 'Pemeriksaan singkat untuk menilai indikasi awal risiko TBC berdasarkan gejala utama.', 'soft_saturation_cf', 0.35, 'percentage'),
  ('full_assessment', 'Full Assessment', 'Pemeriksaan lengkap untuk menilai risiko TBC berdasarkan gejala umum dan gejala spesifik tiap tipe TBC.', 'soft_saturation_cf', 0.35, 'percentage')
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  scoring_method = excluded.scoring_method,
  saturation_k = excluded.saturation_k,
  result_unit = excluded.result_unit,
  updated_at = now();

insert into tbcare_plus.symptoms (code, name, description, tb_type_id, is_active)
values
  ('G01', 'Batuk terus-menerus dan berdahak selama tiga minggu/lebih', 'Batuk berdahak yang berlangsung lama dan tidak membaik dalam tiga minggu atau lebih.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G02', 'Dahak bercampur darah/batuk darah', 'Dahak terlihat bercampur darah atau keluar darah saat batuk.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G03', 'Demam yang berlangsung lama', 'Demam berulang atau menetap dalam waktu lama tanpa penyebab yang jelas.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G04', 'Sesak nafas dan nyeri dada', 'Napas terasa berat atau pendek, disertai rasa nyeri atau tidak nyaman di dada.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G05', 'Penurunan nafsu makan', 'Keinginan makan menurun dibandingkan kondisi biasanya.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G06', 'Penurunan berat badan', 'Berat badan turun tanpa sedang menjalani program diet atau penyebab yang jelas.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G07', 'Rasa kurang enak badan/malaise, lemah', 'Tubuh terasa tidak fit, lemah, lesu, atau mudah lelah dalam aktivitas harian.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G08', 'Berkeringat di malam hari walaupun tidak melakukan apa-apa', 'Keringat berlebih muncul pada malam hari meskipun tidak sedang beraktivitas berat.', (select id from tbcare_plus.tb_types where code = 'pulmonary_tb'), true),
  ('G01a', 'Batuk terus-menerus dan berdahak selama tiga minggu/lebih', 'Gejala batuk lama yang dapat ikut dipertimbangkan pada penilaian TBC kelenjar.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G01b', 'Batuk terus-menerus dan berdahak selama tiga minggu/lebih', 'Gejala batuk lama yang dapat ikut dipertimbangkan pada penilaian TBC payudara.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G01c', 'Batuk terus-menerus dan berdahak selama tiga minggu/lebih', 'Gejala batuk lama yang dapat ikut dipertimbangkan pada penilaian TBC tulang belakang.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G03a', 'Demam yang berlangsung lama', 'Demam lama yang dapat menyertai keluhan pada TBC kelenjar.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G03b', 'Demam yang berlangsung lama', 'Demam lama yang dapat menyertai keluhan pada TBC payudara.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G03c', 'Demam yang berlangsung lama', 'Demam lama yang dapat menyertai keluhan pada TBC tulang belakang.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G05a', 'Penurunan nafsu makan', 'Nafsu makan menurun yang dapat muncul bersama gejala TBC kelenjar.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G05b', 'Penurunan nafsu makan', 'Nafsu makan menurun yang dapat muncul bersama gejala TBC payudara.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G05c', 'Penurunan nafsu makan', 'Nafsu makan menurun yang dapat muncul bersama gejala TBC tulang belakang.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G06a', 'Penurunan berat badan', 'Berat badan turun tanpa sebab jelas yang dapat berkaitan dengan TBC kelenjar.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G06b', 'Penurunan berat badan', 'Berat badan turun tanpa sebab jelas yang dapat berkaitan dengan TBC payudara.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G06c', 'Penurunan berat badan', 'Berat badan turun tanpa sebab jelas yang dapat berkaitan dengan TBC tulang belakang.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G07a', 'Rasa kurang enak badan/malaise, lemah', 'Rasa lemah atau tidak fit yang dapat menyertai TBC kelenjar.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G07b', 'Rasa kurang enak badan/malaise, lemah', 'Rasa lemah atau tidak fit yang dapat menyertai TBC payudara.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G07c', 'Rasa kurang enak badan/malaise, lemah', 'Rasa lemah atau tidak fit yang dapat menyertai TBC tulang belakang.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G08a', 'Berkeringat di malam hari walaupun tidak melakukan apa-apa', 'Keringat malam yang dapat muncul bersama keluhan TBC kelenjar.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G08b', 'Berkeringat di malam hari walaupun tidak melakukan apa-apa', 'Keringat malam yang dapat muncul bersama keluhan TBC payudara.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G08c', 'Berkeringat di malam hari walaupun tidak melakukan apa-apa', 'Keringat malam yang dapat muncul bersama keluhan TBC tulang belakang.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G09', 'Munculnya benjolan pada kelenjar (leher, ketiak, sela paha)', 'Terdapat benjolan di area kelenjar seperti leher, ketiak, atau sela paha.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G10', 'Ada tanda-tanda radang di sekitar benjolan kelenjar', 'Area sekitar benjolan tampak meradang, misalnya kemerahan, hangat, nyeri, atau bengkak.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G11', 'Benjolan kelenjar mudah digerakkan', 'Benjolan terasa dapat bergeser saat disentuh atau ditekan perlahan.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G12', 'Benjolan kelenjar terasa kenyal', 'Benjolan memiliki tekstur kenyal saat diraba.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G13', 'Pembesaran benjolan kelenjar yang memburuk', 'Ukuran benjolan bertambah besar atau keluhan terasa semakin berat dari waktu ke waktu.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G14', 'Benjolan pecah dan mengeluarkan nanah', 'Benjolan terbuka atau pecah dan mengeluarkan cairan seperti nanah.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G15', 'Luka pada kulit akibat pecahnya benjolan kelenjar', 'Muncul luka di kulit setelah benjolan pecah atau mengeluarkan cairan.', (select id from tbcare_plus.tb_types where code = 'lymph_node_tb'), true),
  ('G16', 'Timbulnya benjolan di payudara', 'Terdapat benjolan pada area payudara yang sebelumnya tidak ada.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G17', 'Rasa nyeri di bagian payudara', 'Payudara terasa nyeri, sakit, atau tidak nyaman.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G18', 'Radang di sekitar benjolan payudara', 'Area sekitar benjolan payudara tampak meradang, seperti kemerahan, bengkak, hangat, atau nyeri.', (select id from tbcare_plus.tb_types where code = 'breast_tb'), true),
  ('G19', 'Nyeri atau kaku pada punggung', 'Punggung terasa nyeri, kaku, atau sulit digerakkan dengan nyaman.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G20', 'Enggan menggerakkan punggung', 'Menghindari gerakan punggung karena terasa nyeri, kaku, atau tidak nyaman.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G21', 'Menolak membungkuk / mengangkat barang', 'Kesulitan atau enggan membungkuk dan mengangkat barang karena keluhan pada punggung.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G22', 'Nyeri punggung berkurang saat istirahat', 'Nyeri punggung terasa lebih ringan ketika beristirahat.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true),
  ('G23', 'Benjolan di tulang belakang', 'Terdapat benjolan atau perubahan bentuk yang terasa atau terlihat di area tulang belakang.', (select id from tbcare_plus.tb_types where code = 'spinal_tb'), true)
on conflict (code) do update set
  name = excluded.name,
  description = excluded.description,
  tb_type_id = excluded.tb_type_id,
  is_active = excluded.is_active,
  updated_at = now();

insert into tbcare_plus.assessment_questions (assessment_type_id, symptom_id, question_text, sort_order, is_required)
select at.id, s.id, v.question_text, v.sort_order, true
from (
  values
    ('quick_assessment', 'G01', 'Batuk terus-menerus dan berdahak selama tiga minggu atau lebih', 1),
    ('quick_assessment', 'G02', 'Dahak bercampur darah atau batuk darah', 2),
    ('quick_assessment', 'G03', 'Demam yang berlangsung lama', 3),
    ('quick_assessment', 'G04', 'Sesak nafas dan nyeri dada', 4),
    ('quick_assessment', 'G05', 'Penurunan nafsu makan', 5),
    ('quick_assessment', 'G06', 'Penurunan berat badan', 6),
    ('quick_assessment', 'G07', 'Rasa kurang enak badan, malaise, atau lemah', 7),
    ('quick_assessment', 'G08', 'Berkeringat di malam hari walaupun tidak melakukan aktivitas berat', 8),
    ('full_assessment', 'G01', 'Batuk terus-menerus dan berdahak selama tiga minggu atau lebih', 1),
    ('full_assessment', 'G02', 'Dahak bercampur darah atau batuk darah', 2),
    ('full_assessment', 'G03', 'Demam yang berlangsung lama', 3),
    ('full_assessment', 'G04', 'Sesak nafas dan nyeri dada', 4),
    ('full_assessment', 'G05', 'Penurunan nafsu makan', 5),
    ('full_assessment', 'G06', 'Penurunan berat badan', 6),
    ('full_assessment', 'G07', 'Rasa kurang enak badan, malaise, atau lemah', 7),
    ('full_assessment', 'G08', 'Berkeringat di malam hari walaupun tidak melakukan aktivitas berat', 8),
    ('full_assessment', 'G01a', 'Batuk terus-menerus dan berdahak selama tiga minggu atau lebih', 9),
    ('full_assessment', 'G01b', 'Batuk terus-menerus dan berdahak selama tiga minggu atau lebih', 10),
    ('full_assessment', 'G01c', 'Batuk terus-menerus dan berdahak selama tiga minggu atau lebih', 11),
    ('full_assessment', 'G03a', 'Demam yang berlangsung lama', 12),
    ('full_assessment', 'G03b', 'Demam yang berlangsung lama', 13),
    ('full_assessment', 'G03c', 'Demam yang berlangsung lama', 14),
    ('full_assessment', 'G05a', 'Penurunan nafsu makan', 15),
    ('full_assessment', 'G05b', 'Penurunan nafsu makan', 16),
    ('full_assessment', 'G05c', 'Penurunan nafsu makan', 17),
    ('full_assessment', 'G06a', 'Penurunan berat badan', 18),
    ('full_assessment', 'G06b', 'Penurunan berat badan', 19),
    ('full_assessment', 'G06c', 'Penurunan berat badan', 20),
    ('full_assessment', 'G07a', 'Rasa kurang enak badan, malaise, atau lemah', 21),
    ('full_assessment', 'G07b', 'Rasa kurang enak badan, malaise, atau lemah', 22),
    ('full_assessment', 'G07c', 'Rasa kurang enak badan, malaise, atau lemah', 23),
    ('full_assessment', 'G08a', 'Berkeringat di malam hari walaupun tidak melakukan aktivitas berat', 24),
    ('full_assessment', 'G08b', 'Berkeringat di malam hari walaupun tidak melakukan aktivitas berat', 25),
    ('full_assessment', 'G08c', 'Berkeringat di malam hari walaupun tidak melakukan aktivitas berat', 26),
    ('full_assessment', 'G09', 'Munculnya benjolan pada bagian yang mengalami gangguan kelenjar seperti leher, sela paha, serta ketiak', 27),
    ('full_assessment', 'G10', 'Adanya tanda radang di daerah sekitar benjolan kelenjar', 28),
    ('full_assessment', 'G11', 'Benjolan kelenjar mudah digerakkan', 29),
    ('full_assessment', 'G12', 'Benjolan kelenjar terasa kenyal', 30),
    ('full_assessment', 'G13', 'Membesarnya benjolan kelenjar yang menyebabkan hari demi hari kondisinya semakin memburuk dan merusak tubuh', 31),
    ('full_assessment', 'G14', 'Benjolan kelenjar pecah dan mengeluarkan cairan seperti nanah yang kotor', 32),
    ('full_assessment', 'G15', 'Terdapat luka pada jaringan kulit atau kulit yang disebabkan pecahnya benjolan kelenjar getah bening', 33),
    ('full_assessment', 'G16', 'Timbulnya benjolan di payudara', 34),
    ('full_assessment', 'G17', 'Rasa nyeri di bagian payudara', 35),
    ('full_assessment', 'G18', 'Adanya tanda radang di sekitar benjolan yang timbul di payudara', 36),
    ('full_assessment', 'G19', 'Rasa nyeri atau sakit pada bagian punggung atau mengalami kekakuan punggung', 37),
    ('full_assessment', 'G20', 'Penderita enggan menggerakkan punggungnya', 38),
    ('full_assessment', 'G21', 'Penderita menolak untuk membungkuk atau mengangkat barang dari lantai karena akan menekuk lututnya agar punggung tetap lurus', 39),
    ('full_assessment', 'G22', 'Rasa nyeri atau sakit pada punggung berkurang ketika penderita beristirahat', 40),
    ('full_assessment', 'G23', 'Timbulnya benjolan di bagian punggung atau tulang belakang', 41)
) as v(assessment_type_code, symptom_code, question_text, sort_order)
join tbcare_plus.assessment_types at on at.code = v.assessment_type_code
join tbcare_plus.symptoms s on s.code = v.symptom_code
on conflict (assessment_type_id, symptom_id) do update set
  question_text = excluded.question_text,
  sort_order = excluded.sort_order,
  is_required = excluded.is_required,
  updated_at = now();

insert into tbcare_plus.risk_rules (assessment_type_id, tb_type_id, symptom_id, weight, is_active)
select at.id, s.tb_type_id, s.id, v.weight, true
from (
  values
    ('G01', 0.8), ('G02', 0.6), ('G03', 0.6), ('G04', 0.6), ('G05', 0.8), ('G06', 0.8), ('G07', 0.8), ('G08', 0.6),
    ('G01a', 0.4), ('G01b', 0.4), ('G01c', -0.6), ('G03a', 0.4), ('G03b', 0.6), ('G03c', -0.4),
    ('G05a', 0.6), ('G05b', 0.4), ('G05c', 0.6), ('G06a', 0.6), ('G06b', 0.4), ('G06c', 0.8),
    ('G07a', 1.0), ('G07b', 1.0), ('G07c', 1.0), ('G08a', -0.4), ('G08b', -0.4), ('G08c', 0.4),
    ('G09', 1.0), ('G10', 0.8), ('G11', 0.8), ('G12', 0.8), ('G13', 1.0), ('G14', 0.8), ('G15', 1.0),
    ('G16', 1.0), ('G17', 0.8), ('G18', 0.8),
    ('G19', 1.0), ('G20', 1.0), ('G21', 1.0), ('G22', 1.0), ('G23', 0.6)
) as v(symptom_code, weight)
join tbcare_plus.symptoms s on s.code = v.symptom_code
cross join tbcare_plus.assessment_types at
where at.code = 'full_assessment'
on conflict (assessment_type_id, symptom_id, tb_type_id) do update set
  weight = excluded.weight,
  is_active = excluded.is_active,
  updated_at = now();

insert into tbcare_plus.risk_levels (code, tb_type_id, title, min_score, max_score, description, recommendation)
select v.code, t.id, v.title, v.min_score, v.max_score, v.description, v.recommendation
from (
  values
    ('pulmonary_tb', 'low', 'Low Risk', 0.00, 58.00, 'Persentase hasil berada pada rentang risiko rendah berdasarkan perhitungan certainty factor.', 'Pantau kondisi kesehatan dan lakukan pemeriksaan ulang jika gejala menetap atau memburuk.'),
    ('pulmonary_tb', 'medium', 'Medium Risk', 58.01, 73.00, 'Persentase hasil berada pada rentang risiko sedang berdasarkan perhitungan certainty factor.', 'Disarankan berkonsultasi dengan tenaga kesehatan, terutama jika batuk, demam, atau berat badan turun berlangsung lama.'),
    ('pulmonary_tb', 'high', 'High Risk', 73.01, 100.00, 'Persentase hasil berada pada rentang risiko tinggi berdasarkan perhitungan certainty factor.', 'Segera lakukan pemeriksaan ke fasilitas kesehatan untuk evaluasi lebih lanjut.'),
    ('lymph_node_tb', 'low', 'Low Risk', 0.00, 58.00, 'Persentase hasil berada pada rentang risiko rendah berdasarkan perhitungan certainty factor.', 'Pantau benjolan atau keluhan lain, dan periksa jika ukuran membesar atau muncul tanda radang.'),
    ('lymph_node_tb', 'medium', 'Medium Risk', 58.01, 73.00, 'Persentase hasil berada pada rentang risiko sedang berdasarkan perhitungan certainty factor.', 'Disarankan berkonsultasi dengan tenaga kesehatan jika benjolan menetap, membesar, atau terasa nyeri.'),
    ('lymph_node_tb', 'high', 'High Risk', 73.01, 100.00, 'Persentase hasil berada pada rentang risiko tinggi berdasarkan perhitungan certainty factor.', 'Segera lakukan pemeriksaan medis, terutama jika benjolan pecah, bernanah, atau terus membesar.'),
    ('breast_tb', 'low', 'Low Risk', 0.00, 58.00, 'Persentase hasil berada pada rentang risiko rendah berdasarkan perhitungan certainty factor.', 'Pantau perubahan pada payudara dan lakukan pemeriksaan jika keluhan menetap.'),
    ('breast_tb', 'medium', 'Medium Risk', 58.01, 73.00, 'Persentase hasil berada pada rentang risiko sedang berdasarkan perhitungan certainty factor.', 'Disarankan berkonsultasi dengan tenaga kesehatan jika terdapat benjolan, nyeri, atau tanda radang.'),
    ('breast_tb', 'high', 'High Risk', 73.01, 100.00, 'Persentase hasil berada pada rentang risiko tinggi berdasarkan perhitungan certainty factor.', 'Segera lakukan pemeriksaan medis untuk evaluasi benjolan atau radang pada payudara.'),
    ('spinal_tb', 'low', 'Low Risk', 0.00, 58.00, 'Persentase hasil berada pada rentang risiko rendah berdasarkan perhitungan certainty factor.', 'Pantau nyeri atau kaku pada punggung dan periksa jika keluhan tidak membaik.'),
    ('spinal_tb', 'medium', 'Medium Risk', 58.01, 73.00, 'Persentase hasil berada pada rentang risiko sedang berdasarkan perhitungan certainty factor.', 'Disarankan berkonsultasi dengan tenaga kesehatan jika nyeri punggung menetap atau mengganggu aktivitas.'),
    ('spinal_tb', 'high', 'High Risk', 73.01, 100.00, 'Persentase hasil berada pada rentang risiko tinggi berdasarkan perhitungan certainty factor.', 'Segera lakukan pemeriksaan medis, terutama jika nyeri berat, kaku, atau ada benjolan di tulang belakang.')
) as v(tb_type_code, code, title, min_score, max_score, description, recommendation)
join tbcare_plus.tb_types t on t.code = v.tb_type_code
on conflict (tb_type_id, code) do update set
  title = excluded.title,
  min_score = excluded.min_score,
  max_score = excluded.max_score,
  description = excluded.description,
  recommendation = excluded.recommendation,
  updated_at = now();

-- Grant PostgREST / API roles access to the schema and its tables
grant usage on schema tbcare_plus to anon, authenticated, service_role;
grant all privileges on all tables in schema tbcare_plus to anon, authenticated, service_role;
grant all privileges on all sequences in schema tbcare_plus to anon, authenticated, service_role;
alter default privileges in schema tbcare_plus grant all on tables to anon, authenticated, service_role;
alter default privileges in schema tbcare_plus grant all on sequences to anon, authenticated, service_role;

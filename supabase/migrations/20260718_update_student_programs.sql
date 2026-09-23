update public.students
set program = 'Arquitectura de plataformas y servicios de tecnologías de la información'
where lower(program) in (
  'computacion e informatica',
  'computación e informatica',
  'computación e informática'
);

update public.students
set program = 'Enfermería técnica'
where lower(program) in (
  'enfermeria tecnica',
  'enfermeria técnica',
  'enfermería tecnica',
  'enfermería técnica'
);

update public.students
set program = 'Mecatrónica automotriz'
where lower(program) in (
  'mecanica automotriz',
  'mecánica automotriz',
  'mecatronica automotriz',
  'mecatrónica automotriz'
);

update public.students
set program = 'Acuicultura y procesamiento pesquero'
where lower(program) in (
  'acuicultura',
  'acuicultura y procesamiento pesquero'
);

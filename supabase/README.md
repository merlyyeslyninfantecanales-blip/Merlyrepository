# PracticApp con Supabase

## 1. Crear la base

1. Entra a tu proyecto de Supabase.
2. Abre **SQL Editor**.
3. Copia y ejecuta el contenido de `schema.sql`.

Esto crea las tablas principales:

- `profiles`
- `students`
- `companies`
- `practices`
- `attendance_records`
- `evaluations`
- `tracking_records`
- `vacancies`
- `certificates`

Tambien crea el bucket privado `practicapp-documents` para PDFs.

## 2. Obtener las claves

En Supabase abre **Project Settings > API** o el panel **Connect** y copia:

- Project URL
- Publishable key o Anon public key

No uses la `service_role` dentro de Flutter.

## 3. Ejecutar Flutter con Supabase

```powershell
flutter run `
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co `
  --dart-define=SUPABASE_KEY=TU_PUBLISHABLE_KEY
```

Si no envias esas variables, la app sigue pudiendo abrir sin inicializar Supabase.

## 4. Nota sobre Windows

`supabase_flutter` usa plugins. En Windows, Flutter puede pedir activar
**Developer Mode** para crear enlaces simbolicos.

Ruta rapida:

```powershell
start ms-settings:developers
```

Activa **Developer Mode** y vuelve a ejecutar:

```powershell
flutter pub get
```

## 5. Siguiente paso de migracion

El proyecto ya tiene:

- dependencia `supabase_flutter`,
- inicializacion segura por `--dart-define`,
- esquema SQL,
- servicio inicial `SupabaseDatabaseService`.

El siguiente trabajo es reemplazar por modulos el uso de `LocalDataService`,
empezando por `companies`, `students` y `practices`.

## Estado de migracion

Ya conectado a Supabase:

- Login real con `profiles` + Supabase Auth.
- Carga inicial de `students`, `companies` y `practices`.
- Carga inicial de asistencias, evaluaciones, seguimientos y vacantes.
- Crear/editar/eliminar estudiantes.
- Crear/editar/eliminar empresas.
- Crear/editar/eliminar practicas.
- Registrar y editar asistencias.
- Crear/editar evaluaciones.
- Crear/editar seguimientos.
- Registrar certificados al cerrar practicas.
- Sincronizar perfiles del menu Usuarios con `profiles`.
- Subir PDFs opcionales de evaluaciones y seguimientos al bucket `practicapp-documents`.
- Subir PDFs de certificados al bucket `practicapp-documents`.
- Crear/editar/eliminar usuarios reales de Supabase Auth mediante Edge Function `admin-users`.

Pendiente de migrar:

- Acciones visuales completas de vacantes si se reactiva su formulario propio.
- Configurar y desplegar `admin-users` con `SERVICE_ROLE_KEY` en Supabase.

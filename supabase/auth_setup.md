# Usuarios reales con Supabase Auth

La app ya puede iniciar sesión contra Supabase Auth.

## Crear un usuario

1. En Supabase abre **Authentication > Users**.
2. Crea un usuario con email y contraseña.
3. Copia su `User UID`.

## Vincularlo con PracticApp

Luego abre **Table Editor > profiles** y crea un registro:

| Campo | Valor |
| --- | --- |
| `auth_user_id` | UID del usuario de Authentication |
| `role` | `supervisor`, `encargado` o `estudiante` |
| `full_name` | Nombre visible del usuario |
| `email` | El mismo email del usuario Auth |
| `avatar` | Iniciales, por ejemplo `CM` |
| `company_id` | Solo para encargados |
| `student_id` | Solo para estudiantes |

## Login en la app

Si Supabase está configurado, puedes iniciar sesión escribiendo el correo real
y la contraseña creada en Supabase.

Si la lista desplegable aparece vacía, no es un error: por seguridad, Supabase
puede impedir listar perfiles antes de iniciar sesión. Escribe el correo manualmente.
## Usuarios de prueba recomendados

Puedes crear estos usuarios en **Authentication > Users**:

| Rol | Email sugerido | Nombre |
| --- | --- | --- |
| Supervisor | `supervisor@practicapp.pe` | Supervisor PracticApp |
| Encargado | `luis.ramirez@techsolutions.pe` | Luis Ramirez |
| Estudiante | `juan.perez@student.edu.pe` | Juan Perez Lopez |

Luego copia el UID del usuario estudiante y encargado, abre `sample_profiles.sql`
y reemplaza:

- `AUTH_UID_ESTUDIANTE`
- `AUTH_UID_ENCARGADO`

Despues ejecuta ese SQL en Supabase.

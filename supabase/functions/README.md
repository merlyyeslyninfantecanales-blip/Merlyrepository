# Edge Functions de PracticApp

## Funcion `admin-users`

Esta funcion permite que un supervisor cree, actualice y elimine usuarios reales
de Supabase Auth desde la app.

La app NO debe guardar la `service_role`. Esa clave vive solo como secreto en
Supabase Edge Functions.

## Variables necesarias

Supabase ya expone normalmente:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

Debes agregar:

- `SERVICE_ROLE_KEY`

Desde terminal, con Supabase CLI:

```powershell
supabase secrets set SERVICE_ROLE_KEY=TU_SERVICE_ROLE_KEY
```

No compartas esa clave ni la pongas en Flutter.

## Desplegar

Desde la carpeta del proyecto Supabase:

```powershell
supabase functions deploy admin-users
```

## Requisito

El usuario que llama la funcion debe:

1. estar autenticado en Supabase Auth,
2. tener un registro en `profiles`,
3. tener `role = 'supervisor'`.

Si no cumple eso, la funcion responde como no autorizada.

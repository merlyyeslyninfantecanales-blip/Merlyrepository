import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

type UserRole = "supervisor" | "encargado" | "estudiante";

type AdminUserRequest = {
  action: "create" | "update" | "delete";
  profileId?: string;
  authUserId?: string;
  name?: string;
  email?: string;
  password?: string;
  role?: UserRole;
  companyId?: string | null;
  studentId?: string | null;
  avatar?: string | null;
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function initials(name: string) {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  if (parts.length === 0) return "US";
  if (parts.length === 1) return parts[0].slice(0, 1).toUpperCase();
  return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
}

async function findAuthUserByEmail(admin: ReturnType<typeof createClient>, email: string) {
  let page = 1;
  while (page <= 20) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 100,
    });
    if (error) throw error;
    const found = data.users.find(
      (user) => user.email?.toLowerCase() === email.toLowerCase(),
    );
    if (found) return found;
    if (data.users.length < 100) return null;
    page++;
  }
  return null;
}

async function requireSupervisor(req: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const authHeader = req.headers.get("Authorization") ?? "";
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: auth, error: authError } = await userClient.auth.getUser();
  if (authError || !auth.user) {
    throw new Error("No autorizado.");
  }

  const { data: profileByAuthId } = await userClient
    .from("profiles")
    .select("role")
    .eq("auth_user_id", auth.user.id)
    .maybeSingle();

  const profile = profileByAuthId ??
    (await userClient
      .from("profiles")
      .select("role")
      .eq("email", auth.user.email)
      .maybeSingle()).data;

  if (profile?.role !== "supervisor") {
    throw new Error("Solo un supervisor puede administrar usuarios.");
  }

  return auth.user;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ error: "Metodo no permitido." }, 405);
  }

  try {
    await requireSupervisor(req);

    const body = (await req.json()) as AdminUserRequest;
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey =
      Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    if (body.action === "create") {
      if (!body.email || !body.password || !body.name || !body.role) {
        return json({ error: "Faltan datos para crear el usuario." }, 400);
      }

      let authUser = await findAuthUserByEmail(admin, body.email);
      if (authUser) {
        const { data: updated, error: updateExistingError } =
          await admin.auth.admin.updateUserById(authUser.id, {
            password: body.password,
            user_metadata: {
              full_name: body.name,
              role: body.role,
            },
          });
        if (updateExistingError || !updated.user) {
          return json({
            error: updateExistingError?.message ??
              "No se pudo actualizar el usuario existente.",
          }, 400);
        }
        authUser = updated.user;
      } else {
        const { data: created, error: createError } =
          await admin.auth.admin.createUser({
            email: body.email,
            password: body.password,
            email_confirm: true,
            user_metadata: {
              full_name: body.name,
              role: body.role,
            },
          });

        if (createError || !created.user) {
          return json({
            error: createError?.message ?? "No se creo usuario.",
          }, 400);
        }
        authUser = created.user;
      }

      const { data: profile, error: profileError } = await admin
        .from("profiles")
        .upsert(
          {
            auth_user_id: authUser.id,
            role: body.role,
            full_name: body.name,
            email: body.email,
            avatar: body.avatar ?? initials(body.name),
            company_id: body.companyId ?? null,
            student_id: body.studentId ?? null,
          },
          { onConflict: "email" },
        )
        .select()
        .single();

      if (profileError) {
        return json({ error: profileError.message }, 400);
      }

      return json({ profile });
    }

    if (body.action === "update") {
      if (!body.profileId || !body.email || !body.name || !body.role) {
        return json({ error: "Faltan datos para actualizar el usuario." }, 400);
      }

      let authUserId = body.authUserId;
      if (!authUserId) {
        const { data: currentProfile } = await admin
          .from("profiles")
          .select("auth_user_id")
          .eq("id", body.profileId)
          .single();
        authUserId = currentProfile?.auth_user_id ?? undefined;
      }

      if (authUserId) {
        const attributes: Record<string, unknown> = {
          email: body.email,
          user_metadata: {
            full_name: body.name,
            role: body.role,
          },
        };
        if (body.password && body.password.trim().length > 0) {
          attributes.password = body.password;
        }
        const { error: updateAuthError } =
          await admin.auth.admin.updateUserById(authUserId, attributes);
        if (updateAuthError) {
          return json({ error: updateAuthError.message }, 400);
        }
      }

      const { data: profile, error: profileError } = await admin
        .from("profiles")
        .update({
          auth_user_id: authUserId ?? null,
          role: body.role,
          full_name: body.name,
          email: body.email,
          avatar: body.avatar ?? initials(body.name),
          company_id: body.companyId ?? null,
          student_id: body.studentId ?? null,
        })
        .eq("id", body.profileId)
        .select()
        .single();

      if (profileError) {
        return json({ error: profileError.message }, 400);
      }

      return json({ profile });
    }

    if (body.action === "delete") {
      if (!body.profileId && !body.email) {
        return json({ error: "Falta perfil a eliminar." }, 400);
      }

      const query = admin
        .from("profiles")
        .select("id, auth_user_id")
        .limit(1);
      const { data: profiles, error: lookupError } = body.profileId
        ? await query.eq("id", body.profileId)
        : await query.eq("email", body.email);

      if (lookupError) return json({ error: lookupError.message }, 400);
      const profile = profiles?.[0];
      if (!profile) return json({ ok: true });

      await admin.from("profiles").delete().eq("id", profile.id);
      if (profile.auth_user_id) {
        const { error: deleteAuthError } =
          await admin.auth.admin.deleteUser(profile.auth_user_id);
        if (deleteAuthError) {
          return json({ error: deleteAuthError.message }, 400);
        }
      }

      return json({ ok: true });
    }

    return json({ error: "Accion no soportada." }, 400);
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 401);
  }
});

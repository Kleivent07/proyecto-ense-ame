import express from "express";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";
import dotenv from "dotenv";
import { createClient } from "@supabase/supabase-js";

dotenv.config();

const app = express();
app.use(express.json());

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_KEY = process.env.SUPABASE_KEY; // debe ser service_role o anon key según tu seguridad
const ZOOM_JWT_TOKEN = process.env.ZOOM_JWT_TOKEN; // o token de Server-to-Server OAuth
const SDK_APP_KEY = process.env.ZOOM_SDK_APP_KEY; // set en .env
const SDK_APP_SECRET = process.env.ZOOM_SDK_APP_SECRET; // set en .env

if (!SUPABASE_URL || !SUPABASE_KEY) {
  console.error("Faltan variables de entorno SUPABASE_URL o SUPABASE_KEY");
  process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

const PORT = process.env.PORT ? Number(process.env.PORT) : 3000;

/**
 * Helper: obtiene usuario Supabase a partir del access_token (Bearer token)
 * Usamos la ruta /auth/v1/user de Supabase para validar el token.
 */
async function getUserFromSupabaseToken(accessToken) {
  try {
    const resp = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
      method: "GET",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        apikey: SUPABASE_KEY,
      },
    });
    if (!resp.ok) {
      return null;
    }
    const user = await resp.json();
    if (user && user.id) return user;
    return null;
  } catch (err) {
    console.error("Error validando token supabase:", err);
    return null;
  }
}

// Requiere: npm install jsonwebtoken node-fetch @supabase/supabase-js dotenv
// Helper: valida token de supabase
async function validateSupabaseToken(accessToken) {
  if (!accessToken) return null;
  const res = await fetch(`${SUPABASE_URL}/auth/v1/user`, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      apikey: SUPABASE_KEY,
    },
  });
  if (!res.ok) return null;
  return res.json(); // contiene datos del user
}

// RUTA: obtener usuarios de la app (usada por CrearReunionPage)
app.get("/app-users", async (req, res) => {
  try {
    // Opcional: podrías requerir auth aquí.
    const { data, error } = await supabase.from("usuarios").select("id,email,nombre,apellido");
    if (error) return res.status(500).json({ error: error.message });
    res.json({ users: data || [] });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Error interno" });
  }
});

// RUTA: crear reunión (ruta esperada por la app)
app.post("/create-zoom-meeting", async (req, res) => {
  try {
    // Validar token Supabase enviado por la app (Bearer <access_token>)
    const authHeader = req.headers.authorization || "";
    if (!authHeader.startsWith("Bearer ")) {
      return res.status(401).json({ error: "Falta Authorization Bearer token" });
    }
    const token = authHeader.split(" ")[1];
    const user = await getUserFromSupabaseToken(token);
    if (!user || !user.id) return res.status(401).json({ error: "Token inválido" });

    // Extraer datos del body (coinciden con lo que envía CrearReunionPage)
    const {
      topic,
      start_time,
      duration = 30,
      host_user_id,
      host_email,
      participant_user_ids,
      room_id,
    } = req.body;

    // Crear reunión en Zoom (usa ZOOM_JWT_TOKEN configurado)
    if (!ZOOM_JWT_TOKEN) {
      return res.status(500).json({ error: "ZOOM_JWT_TOKEN no configurado en .env" });
    }

    // Build Zoom body (tipo 2: scheduled meeting)
    const zoomBody = {
      topic: topic || "Reunión desde app",
      type: 2,
      start_time: start_time || undefined,
      duration: duration,
      timezone: "America/Santiago",
    };

    const zoomResp = await fetch("https://api.zoom.us/v2/users/me/meetings", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${ZOOM_JWT_TOKEN}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(zoomBody),
    });

    const zoomData = await zoomResp.json();
    if (!zoomData || !zoomData.id) {
      console.error("Zoom API error:", zoomData);
      return res.status(400).json({ error: "No se pudo crear la reunión en Zoom", zoomData });
    }

    // Guardar en Supabase (tabla zoom_meetings)
    const meetingRow = {
      zoom_id: zoomData.id?.toString(),
      room_id: room_id || null,
      topic: zoomData.topic || topic,
      agenda: zoomData.agenda || null,
      start_time: zoomData.start_time || start_time || null,
      duration: zoomData.duration || duration,
      timezone: zoomData.timezone || "America/Santiago",
      join_url: zoomData.join_url || null,
      start_url: zoomData.start_url || null,
      passcode: zoomData.password || null,
      status: zoomData.status || "scheduled",
      host_id: host_user_id || user.id,
      created_by: user.id,
      settings: zoomData.settings || {},
      participants: participant_user_ids || [],
    };

    const { data, error } = await supabase.from("zoom_meetings").insert([meetingRow]).select().single();

    if (error) {
      console.error("Error guardando reunión en Supabase:", error);
      return res.status(500).json({ error: "Error guardando en BD", details: error.message });
    }

    // Responder con datos útiles (para la app)
    res.json({
      message: "Reunión creada y guardada en Supabase",
      zoom: zoomData,
      db: data,
    });
  } catch (err) {
    console.error("Error creando reunión:", err);
    res.status(500).json({ error: "Error interno", details: String(err) });
  }
});

// RUTA: generar token SDK para Zoom (MobileRTC)
app.post("/sdk-token", async (req, res) => {
  try {
    const authHeader = req.headers["authorization"] || "";
    const accessToken = authHeader.replace(/^Bearer\s+/i, "");

    const user = await validateSupabaseToken(accessToken);
    if (!user) return res.status(401).json({ error: "Token inválido" });

    // Generar JWT (payload requerido por MobileRTC SDK)
    const iat = Math.floor(Date.now() / 1000);
    const tokenExp = iat + 60 * 60; // exp en 1 hora (ajusta según necesidad)
    const payload = {
      appKey: SDK_APP_KEY,
      iat: iat,
      exp: tokenExp,
      tokenExp: tokenExp,
    };

    const token = jwt.sign(payload, SDK_APP_SECRET, { algorithm: "HS256" });

    return res.json({ token });
  } catch (err) {
    console.error("sdk-token error", err);
    return res.status(500).json({ error: "internal_error" });
  }
});

// Mantener compatibilidad con ruta /create-meeting si quieres
app.post("/create-meeting", async (req, res) => {
  // redirige a la ruta nueva
  return app._router.handle(req, res, () => {}, "/create-zoom-meeting");
});

app.listen(PORT, () => {
  console.log(`Servidor funcionando en puerto ${PORT}`);
});

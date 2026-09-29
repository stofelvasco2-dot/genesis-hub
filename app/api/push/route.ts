import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";
import webpush from "web-push";
import { LOGO_URL } from "@/lib/branding";

// Envia notificação push de verdade (aparece mesmo com o app fechado) pra
// todos os navegadores/dispositivos que o usuário autorizou. Roda só aqui
// no servidor — a chave privada VAPID (que assina os envios) e a chave de
// serviço do Supabase (que lê push_subscriptions ignorando RLS) nunca são
// expostas ao navegador, igual ao /api/notify (e-mail) e /api/invite.
export async function POST(req: Request) {
  try {
    const { userId, title, message, taskId } = await req.json();

    const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
    const vapidPrivateKey = process.env.VAPID_PRIVATE_KEY;
    const vapidSubject = process.env.VAPID_SUBJECT || "mailto:contato@genesishub.com";
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (!vapidPublicKey || !vapidPrivateKey || !supabaseUrl || !supabaseServiceKey) {
      // Não derruba o app por causa de push: só loga e segue (mesmo padrão
      // do /api/notify quando o e-mail não está configurado).
      console.error("Push notification não configurado (faltam chaves VAPID ou do Supabase).");
      return NextResponse.json({ skipped: true }, { status: 200 });
    }

    if (!userId) {
      return NextResponse.json({ error: "userId não informado." }, { status: 400 });
    }

    webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const { data: subs, error: subsError } = await supabaseAdmin
      .from("push_subscriptions")
      .select("id, endpoint, p256dh, auth")
      .eq("user_id", userId);

    if (subsError) {
      console.error("Erro ao buscar inscrições de push:", subsError.message);
      return NextResponse.json({ error: subsError.message }, { status: 500 });
    }
    if (!subs || subs.length === 0) {
      return NextResponse.json({ sent: 0 });
    }

    const appUrl = process.env.NEXT_PUBLIC_APP_URL || "https://genesis-hub1.vercel.app";
    const targetUrl = taskId ? `${appUrl}/kanban?task=${taskId}` : `${appUrl}/kanban`;
    const payload = JSON.stringify({ title, message, url: targetUrl, icon: LOGO_URL });

    let sent = 0;
    for (const sub of subs) {
      try {
        await webpush.sendNotification(
          { endpoint: sub.endpoint, keys: { p256dh: sub.p256dh, auth: sub.auth } },
          payload
        );
        sent++;
      } catch (err: any) {
        // Inscrição expirada ou revogada pelo navegador — limpa do banco
        // pra não ficar tentando de novo pra sempre.
        if (err?.statusCode === 404 || err?.statusCode === 410) {
          await supabaseAdmin.from("push_subscriptions").delete().eq("id", sub.id);
        } else {
          console.error("Falha ao enviar push:", err?.message || err);
        }
      }
    }

    return NextResponse.json({ sent });
  } catch (error: any) {
    console.error("Erro no endpoint de push:", error);
    return NextResponse.json({ error: error.message || "Internal Server Error" }, { status: 500 });
  }
}

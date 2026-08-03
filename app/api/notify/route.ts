import { NextResponse } from "next/server";

// Envia e-mail de notificação via Resend. A RESEND_API_KEY nunca é exposta
// ao navegador — só existe aqui no servidor, igual à SUPABASE_SERVICE_ROLE_KEY
// usada em /api/invite.
export async function POST(req: Request) {
  try {
    const { to, title, message, taskId } = await req.json();

    const apiKey = process.env.RESEND_API_KEY;
    const fromEmail = process.env.RESEND_FROM_EMAIL;
    const appUrl = process.env.NEXT_PUBLIC_APP_URL || "https://genesis-hub1.vercel.app";

    if (!apiKey || !fromEmail) {
      // Não derruba o app por causa de e-mail: só loga e segue.
      console.error("RESEND_API_KEY ou RESEND_FROM_EMAIL não configurados.");
      return NextResponse.json({ skipped: true }, { status: 200 });
    }

    if (!to) {
      return NextResponse.json({ error: "Destinatário (to) não informado." }, { status: 400 });
    }

    const html = `
      <div style="font-family: -apple-system, Arial, sans-serif; max-width: 480px; margin: 0 auto; background:#0B1224; padding:32px; border-radius:16px; color:#E2E8F0;">
        <p style="color:#7AA2FF; font-size:12px; letter-spacing:1px; text-transform:uppercase; margin:0 0 12px;">Genesis Hub</p>
        <h2 style="color:#fff; font-size:20px; margin:0 0 16px;">${title}</h2>
        ${message ? `<p style="font-size:14px; color:#94A3B8; margin:0 0 24px; line-height:1.5;">${message}</p>` : ""}
        <a href="${appUrl}/kanban" style="display:inline-block; background:linear-gradient(135deg,#5B8DFF,#2F6FEE); color:#fff; text-decoration:none; padding:12px 20px; border-radius:8px; font-size:14px; font-weight:600;">
          Ver no Genesis Hub
        </a>
      </div>
    `;

    const resendRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to,
        subject: title,
        html,
      }),
    });

    if (!resendRes.ok) {
      const errText = await resendRes.text();
      console.error("Erro ao enviar e-mail via Resend:", errText);
      return NextResponse.json({ error: errText }, { status: 502 });
    }

    return NextResponse.json({ success: true });
  } catch (error: any) {
    console.error("Erro no endpoint de notificação:", error);
    return NextResponse.json({ error: error.message || "Internal Server Error" }, { status: 500 });
  }
}

import { NextResponse } from "next/server";
import { LOGO_URL } from "@/lib/branding";

// Envia e-mail de notificação via Resend. A RESEND_API_KEY nunca é exposta
// ao navegador — só existe aqui no servidor, igual à SUPABASE_SERVICE_ROLE_KEY
// usada em /api/invite.
export async function POST(req: Request) {
  try {
    const { to, title, message, taskId, recipientName } = await req.json();

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

    // Se veio o ID da demanda, o botão leva direto pra ela (mesmo deep-link
    // que o sino usa) em vez de só abrir o Kanban genérico.
    const targetUrl = taskId ? `${appUrl}/kanban?task=${taskId}` : `${appUrl}/kanban`;
    const firstName = recipientName ? String(recipientName).split(" ")[0] : null;

    // E-mail escuro, com a MESMA paleta da tela de login (#0b1430, azul
    // blue-600/blue-400). As duas metatags de color-scheme são essenciais:
    // sem elas, o Gmail (principalmente no app) "acha" que precisa inverter
    // as cores no modo escuro do celular, e faz isso pela metade — clareia
    // o fundo mas não ajusta a logo/texto, ficando ilegível. Com elas, o
    // Gmail entende que o e-mail já foi feito pra modo escuro e não mexe.
    // A estrutura em <table> (em vez de <div>) é o padrão da indústria pra
    // e-mail, porque clientes de e-mail (Gmail, Outlook, Apple Mail) cada
    // um respeita um pedaço diferente do CSS — tabela com bgcolor é o que
    // funciona de forma consistente em todos.
    const html = `<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<meta name="color-scheme" content="dark" />
<meta name="supported-color-schemes" content="dark" />
<title>${title}</title>
</head>
<body style="margin:0; padding:0; background-color:#0b1430;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#0b1430;">
    <tr>
      <td align="center" style="padding:40px 16px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px; background-color:#111a3d; border:1px solid rgba(255,255,255,0.08); border-radius:16px;">
          <tr>
            <td style="padding:32px; font-family:Arial,Helvetica,sans-serif;">
              <img src="${LOGO_URL}" alt="Genesis Hub" width="140" style="display:block; margin:0 0 24px; border:0;" />
              <p style="color:#60A5FA; font-size:11px; letter-spacing:1.5px; text-transform:uppercase; margin:0 0 10px;">Genesis Hub</p>
              ${firstName ? `<p style="color:#93C5FD; font-size:14px; margin:0 0 6px;">Olá, ${firstName}</p>` : ""}
              <h2 style="color:#ffffff; font-size:20px; margin:0 0 14px;">${title}</h2>
              ${message ? `<p style="color:#BFDBFE; font-size:14px; line-height:1.6; margin:0 0 26px;">${message}</p>` : ""}
              <table role="presentation" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="background-color:#2563EB; border-radius:8px;">
                    <a href="${targetUrl}" style="display:inline-block; padding:13px 22px; font-size:14px; font-weight:600; color:#ffffff; text-decoration:none;">
                      Ver demanda no Genesis Hub
                    </a>
                  </td>
                </tr>
              </table>
              <p style="color:#5b6b99; font-size:11px; margin:28px 0 0;">Você recebeu esse e-mail porque está envolvido(a) nessa demanda no Genesis Hub.</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

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
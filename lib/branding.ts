// URL da logo usada em todo o sistema (login, convite, sidebar, e-mails).
// Prioriza a variável de ambiente NEXT_PUBLIC_LOGO_URL — assim que o arquivo
// for subido pro Supabase Storage, basta trocar essa variável na Vercel
// (Settings → Environment Variables) e fazer um redeploy; não precisa mexer
// em nenhum desses arquivos de novo.
export const LOGO_URL =
  process.env.NEXT_PUBLIC_LOGO_URL || "https://i.ibb.co/zp9RSKP/logo-genesis.png";

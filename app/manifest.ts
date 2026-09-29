import { MetadataRoute } from "next";

// Ícone que aparece na tela de início quando o app é instalado (Android/
// iOS/Desktop) — pedido explicitamente pra ser essa imagem, separado da
// logo do resto do sistema (lib/branding.ts).
const APP_ICON_URL = "https://eyhprofxjtsvzsqpzrzn.supabase.co/storage/v1/object/public/public-assets/fivecon.png";

// Deixa o Genesis Hub "instalável" (tela de início no Android/Desktop, e
// obrigatório no iPhone pra notificação push funcionar). O Next.js serve
// isso automaticamente em /manifest.webmanifest e já injeta a tag <link>
// certa no <head> — não precisa adicionar nada manualmente no layout.
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Genesis Hub",
    short_name: "Genesis Hub",
    description: "Sistema de Gestão de Demandas para o setor de Marketing",
    start_url: "/",
    display: "standalone",
    background_color: "#0b1430",
    theme_color: "#0b1430",
    icons: [
      { src: APP_ICON_URL, sizes: "192x192", type: "image/png" },
      { src: APP_ICON_URL, sizes: "512x512", type: "image/png" },
    ],
  };
}

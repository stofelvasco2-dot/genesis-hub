import { MetadataRoute } from "next";
import { LOGO_URL } from "@/lib/branding";

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
      { src: LOGO_URL, sizes: "192x192", type: "image/png" },
      { src: LOGO_URL, sizes: "512x512", type: "image/png" },
    ],
  };
}

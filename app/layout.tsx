import type {Metadata} from 'next';
import './globals.css';
import { Geist } from "next/font/google";
import { cn } from "@/lib/utils";
import { StoreProvider } from '@/lib/store';
import { SidebarProvider } from '@/lib/sidebar-context';
import { Toaster } from '@/components/ui/sonner';

const geist = Geist({subsets:['latin'],variable:'--font-sans'});

export const metadata: Metadata = {
  title: 'Genesis Hub',
  description: 'Sistema de Gestão de Demandas para o setor de Marketing',
};

export default function RootLayout({children}: {children: React.ReactNode}) {
  return (
    <html lang="en" className={cn("font-sans", geist.variable)}>
      <body suppressHydrationWarning>
        <StoreProvider>
          <SidebarProvider>
            {children}
            <Toaster />
          </SidebarProvider>
        </StoreProvider>
      </body>
    </html>
  );
}
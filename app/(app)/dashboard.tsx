"use client";

import { useStore } from "@/lib/store";
import AdminDashboard from "@/components/dashboard/admin-dashboard";
import CollaboratorDashboard from "@/components/dashboard/collaborator-dashboard";

export default function DashboardPage() {
  const { currentUser } = useStore();

  const isGestorOrAdmin = currentUser?.role === "Admin" || currentUser?.role === "Gestor";

  return isGestorOrAdmin ? <AdminDashboard /> : <CollaboratorDashboard />;
}

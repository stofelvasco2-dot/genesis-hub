"use client";
import { supabase } from "./supabase";

function urlBase64ToUint8Array(base64String: string): Uint8Array {
  const padding = "=".repeat((4 - (base64String.length % 4)) % 4);
  const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/");
  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);
  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}

export function isPushSupported(): boolean {
  return typeof window !== "undefined" && "serviceWorker" in navigator && "PushManager" in window && "Notification" in window;
}

export type PushState = "unsupported" | "denied" | "subscribed" | "unsubscribed";

// Estado atual — usado só pra pintar o botão certo (ativo/inativo/bloqueado).
// Nunca pede permissão sozinho; isso só acontece em subscribeToPush, que
// precisa ser chamado a partir de um clique real da pessoa.
export async function getPushState(): Promise<PushState> {
  if (!isPushSupported()) return "unsupported";
  if (Notification.permission === "denied") return "denied";
  try {
    const registration = await navigator.serviceWorker.getRegistration();
    const sub = await registration?.pushManager.getSubscription();
    return sub ? "subscribed" : "unsubscribed";
  } catch {
    return "unsubscribed";
  }
}

// Pede permissão e inscreve o navegador atual pra receber push — grava a
// inscrição em push_subscriptions, associada ao usuário logado. Se a
// pessoa já tinha uma inscrição nesse mesmo navegador, reaproveita (upsert
// por endpoint, que é único por inscrição).
export async function subscribeToPush(userId: string): Promise<boolean> {
  if (!isPushSupported() || !supabase) return false;

  const vapidPublicKey = process.env.NEXT_PUBLIC_VAPID_PUBLIC_KEY;
  if (!vapidPublicKey) {
    console.error("NEXT_PUBLIC_VAPID_PUBLIC_KEY não configurada — push notification indisponível.");
    return false;
  }

  const permission = await Notification.requestPermission();
  if (permission !== "granted") return false;

  const registration = await navigator.serviceWorker.register("/sw.js");
  await navigator.serviceWorker.ready;

  const existing = await registration.pushManager.getSubscription();
  const subscription =
    existing ||
    (await registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(vapidPublicKey) as BufferSource,
    }));

  const json = subscription.toJSON();
  if (!json.endpoint || !json.keys?.p256dh || !json.keys?.auth) return false;

  const { error } = await supabase.from("push_subscriptions").upsert(
    [{ user_id: userId, endpoint: json.endpoint, p256dh: json.keys.p256dh, auth: json.keys.auth }],
    { onConflict: "endpoint" }
  );

  return !error;
}

// Remove a inscrição desse navegador — tanto do banco quanto do próprio
// navegador (pra não receber mais push nenhum aqui).
export async function unsubscribeFromPush(): Promise<void> {
  if (!isPushSupported() || !supabase) return;
  const registration = await navigator.serviceWorker.getRegistration();
  const sub = await registration?.pushManager.getSubscription();
  if (!sub) return;
  await supabase.from("push_subscriptions").delete().eq("endpoint", sub.endpoint);
  await sub.unsubscribe();
}

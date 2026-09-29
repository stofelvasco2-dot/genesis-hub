// Service Worker do Genesis Hub — só cuida de notificações push. Não faz
// cache de páginas, não intercepta requisições, não muda o comportamento
// normal do site. Ativa na hora (skipWaiting/clients.claim) pra não deixar
// versão antiga presa.

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("push", (event) => {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = { title: "Genesis Hub", message: event.data ? event.data.text() : "" };
  }

  const title = data.title || "Genesis Hub";
  const options = {
    body: data.message || "",
    data: { url: data.url || "/" },
    ...(data.icon ? { icon: data.icon, badge: data.icon } : {}),
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.url) || "/";

  event.waitUntil(
    self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((clientsArr) => {
      for (const client of clientsArr) {
        if (client.url.includes(url) && "focus" in client) {
          return client.focus();
        }
      }
      if (self.clients.openWindow) {
        return self.clients.openWindow(url);
      }
    })
  );
});

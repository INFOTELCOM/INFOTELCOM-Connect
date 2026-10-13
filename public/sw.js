const APP_BASE = new URL("/INFOTELCOM-Connect/", self.location.origin).href;
self.addEventListener('install', event => { event.waitUntil(self.skipWaiting()); });
self.addEventListener('activate', event => { event.waitUntil((async () => { await self.clients.claim(); })()); });
self.addEventListener('push', event => {
  let data = { title: 'INFOTELCOM Connect', body: 'Nouvelle activité dans votre espace de travail.', url: APP_BASE };
  try { if (event.data) data = { ...data, ...event.data.json() }; }
  catch { if (event.data) data.body = event.data.text(); }
  const target = (() => {
    try { return new URL(data.url || APP_BASE, self.registration.scope).href; }
    catch { return APP_BASE; }
  })();
  event.waitUntil(self.registration.showNotification(data.title || 'INFOTELCOM Connect', {
    body: data.body || 'Nouvelle activité',
    icon: new URL('favicon.ico', APP_BASE).href,
    badge: new URL('favicon.ico', APP_BASE).href,
    tag: data.tag || 'connect-notification',
    renotify: false,
    data: { url: target }
  }));
});
self.addEventListener('notificationclick', event => {
  event.notification.close();
  const target = (() => {
    try { return new URL(event.notification.data?.url || APP_BASE, self.registration.scope).href; }
    catch { return APP_BASE; }
  })();
  event.waitUntil((async () => {
    const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const existing = clients.find(client => client.url.startsWith(APP_BASE));
    if (existing) {
      await existing.navigate(target);
      return existing.focus();
    }
    return self.clients.openWindow(target);
  })());
});

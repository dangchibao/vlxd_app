/* The release build script generates the manifest from actual output files. */
importScripts('offline-manifest.js');

const cachePrefix = 'vlxd-offline-' + self.registration.scope + '-';
const cacheName = cachePrefix + self.vlxdOfflineManifest.version;
const appUrl = file => new URL(file, self.registration.scope).href;
const appFiles = self.vlxdOfflineManifest.files.map(appUrl);
const firebaseModules = ['app', 'auth', 'firestore-pipelines'].map(
  name => 'https://www.gstatic.com/firebasejs/13.1.0/firebase-' + name + '.js',
);
const staticFiles = new Set([...appFiles, ...firebaseModules]);

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(cacheName);
    // Fetch fresh assets. The active worker keeps serving its previous
    // complete version until this entire version has been cached.
    const resources = [...staticFiles].map(url =>
      new Request(url, { cache: 'reload', credentials: 'omit' }));
    await cache.addAll(resources);
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.filter(name => name.startsWith(cachePrefix) && name !== cacheName)
      .map(name => caches.delete(name)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  // Authentication, Firestore and other API requests always go to network.
  const target = event.request.mode === 'navigate' && url.href.startsWith(self.registration.scope)
    ? appUrl('index.html') : url.href;
  if (!staticFiles.has(target)) return;
  event.respondWith((async () => {
    const cache = await caches.open(cacheName);
    return await cache.match(target, { ignoreVary: true }) ?? fetch(event.request);
  })());
});

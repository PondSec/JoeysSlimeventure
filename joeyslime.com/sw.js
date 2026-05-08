const CACHE_PREFIX = 'joeyslime-legacy-';

self.addEventListener('install', (event) => {
	event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
	event.waitUntil(
		caches.keys()
			.then((keys) =>
				Promise.all(
					keys
						.filter((key) => key.startsWith(CACHE_PREFIX) || key.includes('slimeventure'))
						.map((key) => caches.delete(key))
				)
			)
			.then(() => self.clients.claim())
	);
});

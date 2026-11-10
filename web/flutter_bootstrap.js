{{flutter_js}}
{{flutter_build_config}}

async function start() {
  if ('serviceWorker' in navigator) {
    try {
      const registration = navigator.serviceWorker.register('offline-sw.js', {
        updateViaCache: 'none',
      }).then(() => navigator.serviceWorker.ready);
      await Promise.race([registration, new Promise(resolve => setTimeout(resolve, 6000))]);
    } catch (error) {
      console.warn('Không thể chuẩn bị bộ nhớ Web ngoại tuyến.', error);
    }
  }
  await _flutter.loader.load();
}

start();

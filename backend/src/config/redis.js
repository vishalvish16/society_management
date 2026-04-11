const Redis = require('ioredis');
const MockRedis = require('./mockRedis');

let redis;

if (process.env.NODE_ENV === 'test') {
  redis = new MockRedis();
  redis.isMock = true;
} else {
  const url = process.env.REDIS_URL || 'redis://localhost:6379';
  const isLocalhost = url.includes('localhost') || url.includes('127.0.0.1');

  // We'll use a container object to hold the active instance
  const container = {
    instance: new Redis(url, {
      maxRetriesPerRequest: 0, // Fail fast
      lazyConnect: true,
      showFriendlyErrorStack: true,
      retryStrategy: () => null // Never retry
    }),
    isMock: false
  };

  // Silence initialization errors for the lazy-connected real instance
  container.instance.on('error', () => {
    // This is expected if Redis is down
  });

  // Attempt connection
  container.instance.connect().catch(() => {
    if (isLocalhost && process.env.NODE_ENV !== 'production') {
      console.warn('⚠️  Real Redis not found. Falling back to In-Memory Mock Redis for development...');
      container.instance.disconnect(); // important to stop internal state
      container.instance = new MockRedis();
      container.isMock = true;
    }
  });

  // Export a proxy that delegates to whichever instance is currently in the container
  redis = new Proxy({}, {
    get(target, prop) {
      if (prop === 'isMock') return container.isMock;
      if (typeof container.instance[prop] === 'function') {
        return container.instance[prop].bind(container.instance);
      }
      return container.instance[prop];
    }
  });
}

module.exports = redis;

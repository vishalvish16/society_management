const EventEmitter = require('events');

/**
 * A lightweight, in-memory mock of ioredis for development
 * when a real Redis server is not available.
 */
class MockRedis extends EventEmitter {
  constructor() {
    super();
    this.store = new Map();
    this.ttls = new Map();
    
    // Simulate connection delay
    setTimeout(() => {
      this.emit('connect');
      console.log('Using in-memory Mock Redis (Dev only)');
    }, 100);
  }

  async get(key) {
    this._checkExpiry(key);
    return this.store.get(key) || null;
  }

  async set(key, value, mode, ttl) {
    this.store.set(key, String(value));
    if (mode === 'EX' && ttl) {
      this.ttls.set(key, Date.now() + ttl * 1000);
    }
    return 'OK';
  }

  async del(...keys) {
    keys.forEach(key => {
      this.store.delete(key);
      this.ttls.delete(key);
    });
    return keys.length;
  }

  async incr(key) {
    let val = parseInt(await this.get(key) || '0', 10);
    val += 1;
    await this.set(key, val);
    return val;
  }

  async expire(key, ttlSeconds) {
    if (this.store.has(key)) {
      this.ttls.set(key, Date.now() + ttlSeconds * 1000);
      return 1;
    }
    return 0;
  }

  async ping() {
    return 'PONG';
  }

  _checkExpiry(key) {
    if (this.ttls.has(key) && this.ttls.get(key) < Date.now()) {
      this.store.delete(key);
      this.ttls.delete(key);
    }
  }
}

module.exports = MockRedis;

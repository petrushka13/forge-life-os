'use strict';
class EvidenceQueue {
  constructor({events = [], persist, send, limit = 10000}) {
    this.events = events.slice(-limit); this.persist = persist; this.send = send; this.limit = limit;
    this.generation = 0; this.controller = null; this.running = false; this.writes = Promise.resolve(); this.dropped = 0;
  }
  save() {
    const generation = this.generation, snapshot = this.events.map(x => ({...x}));
    this.writes = this.writes.catch(() => {}).then(() => generation === this.generation ? this.persist(snapshot) : undefined);
    return this.writes;
  }
  async add(event) {
    this.events.push(event);
    if (this.events.length > this.limit) { this.dropped += this.events.length - this.limit; this.events = this.events.slice(-this.limit); }
    await this.save();
  }
  stop() { this.generation++; this.controller?.abort(); }
  async erase() { this.stop(); this.events = []; await this.save(); }
  async flush() {
    if (this.running) return;
    this.running = true; const generation = this.generation;
    this.controller = new AbortController();
    try {
      for (let i=0; i<5 && this.events.length && generation===this.generation; i++) {
        const event = this.events[0];
        if (!await this.send(event, this.controller.signal)) break;
        if (generation !== this.generation) break;
        if (this.events[0]?.id === event.id) { this.events.shift(); await this.save(); }
      }
    } catch { /* Offline retry keeps original immutable IDs. No payload logging. */ }
    finally { this.controller = null; this.running = false; }
  }
}
module.exports = {EvidenceQueue};

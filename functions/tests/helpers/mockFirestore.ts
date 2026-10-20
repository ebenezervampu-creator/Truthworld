/**
 * 🗄️ IN-MEMORY FIRESTORE TEST HARNESS
 *
 * Provides a high-fidelity, isolated, zero-dependency in-memory Firestore
 * implementation for testing database operations, queries, transactions,
 * and batch mutations without touching production or remote networks.
 */

export interface TestDocData {
  [key: string]: any;
}

class MemorySnapshot {
  constructor(
    public readonly id: string,
    private readonly _data: TestDocData | undefined,
    public readonly ref: MemoryDocumentRef
  ) {}

  get exists(): boolean {
    return this._data !== undefined;
  }

  data(): TestDocData | undefined {
    if (!this._data) return undefined;
    // Deep clone to prevent unintended reference mutation
    return JSON.parse(JSON.stringify(this._data));
  }

  get(field: string): any {
    return this._data ? this._data[field] : undefined;
  }
}

class MemoryQuerySnapshot {
  constructor(public readonly docs: MemorySnapshot[]) {}

  get empty(): boolean {
    return this.docs.length === 0;
  }

  get size(): number {
    return this.docs.length;
  }

  forEach(callback: (doc: MemorySnapshot) => void): void {
    this.docs.forEach(callback);
  }
}

export class MemoryDocumentRef {
  constructor(
    public readonly id: string,
    public readonly path: string,
    private readonly store: Map<string, TestDocData>,
    private readonly db: InMemoryFirestore
  ) {}

  collection(subCollectionName: string): MemoryCollectionRef {
    const subPath = `${this.path}/${subCollectionName}`;
    return new MemoryCollectionRef(subPath, this.store, this.db);
  }

  async get(): Promise<MemorySnapshot> {
    const data = this.store.get(this.path);
    return new MemorySnapshot(this.id, data, this);
  }

  async set(data: TestDocData, options?: { merge?: boolean }): Promise<void> {
    const existing = options?.merge ? (this.store.get(this.path) || {}) : undefined;
    const resolvedData = this.resolveFieldValues(data, existing);
    if (options?.merge) {
      this.store.set(this.path, { ...existing, ...resolvedData });
    } else {
      this.store.set(this.path, { ...resolvedData });
    }
  }

  async update(data: TestDocData): Promise<void> {
    const existing = this.store.get(this.path);
    if (!existing) {
      throw new Error(`NOT_FOUND: No document to update at ${this.path}`);
    }
    const resolvedData = this.resolveFieldValues(data, existing);
    this.store.set(this.path, { ...existing, ...resolvedData });
  }

  async create(data: TestDocData): Promise<void> {
    if (this.store.has(this.path)) {
      const err: any = new Error(`ALREADY_EXISTS: Document already exists at ${this.path}`);
      err.code = 6;
      throw err;
    }
    await this.set(data);
  }

  async delete(): Promise<void> {
    this.store.delete(this.path);
  }

  private resolveFieldValues(data: TestDocData, existingData?: TestDocData): TestDocData {
    const result: TestDocData = {};
    for (const [k, v] of Object.entries(data)) {
      if (v && typeof v === 'object' && v.__op === 'serverTimestamp') {
        result[k] = new Date().toISOString();
      } else if (v && typeof v === 'object' && v.__op === 'increment') {
        const cur = existingData ? (existingData[k] || 0) : 0;
        result[k] = cur + v.value;
      } else if (v && typeof v === 'object' && v.__op === 'arrayUnion') {
        const cur = Array.isArray(existingData?.[k]) ? existingData![k] : [];
        result[k] = Array.from(new Set([...cur, ...v.elements]));
      } else if (v && typeof v === 'object' && v.__op === 'delete') {
        // field deletion
      } else {
        result[k] = v;
      }
    }
    return result;
  }
}

export class MemoryCollectionRef {
  private _wheres: Array<{ field: string; op: string; val: any }> = [];
  private _orderBys: Array<{ field: string; dir: 'asc' | 'desc' }> = [];
  private _limit?: number;
  private _startAfterDoc?: MemorySnapshot;

  constructor(
    public readonly path: string,
    private readonly store: Map<string, TestDocData>,
    private readonly db: InMemoryFirestore
  ) {}

  doc(id?: string): MemoryDocumentRef {
    const docId = id || `doc_${Math.random().toString(36).substring(2, 10)}`;
    const docPath = `${this.path}/${docId}`;
    return new MemoryDocumentRef(docId, docPath, this.store, this.db);
  }

  async add(data: TestDocData): Promise<MemoryDocumentRef> {
    const docRef = this.doc();
    await docRef.set(data);
    return docRef;
  }

  where(field: string, op: string, val: any): MemoryCollectionRef {
    const clone = this.clone();
    clone._wheres.push({ field, op, val });
    return clone;
  }

  orderBy(field: string, dir: 'asc' | 'desc' = 'asc'): MemoryCollectionRef {
    const clone = this.clone();
    clone._orderBys.push({ field, dir });
    return clone;
  }

  limit(count: number): MemoryCollectionRef {
    const clone = this.clone();
    clone._limit = count;
    return clone;
  }

  startAfter(doc: MemorySnapshot): MemoryCollectionRef {
    const clone = this.clone();
    clone._startAfterDoc = doc;
    return clone;
  }

  async get(): Promise<MemoryQuerySnapshot> {
    // 1. Gather all documents directly under this collection path
    const docs: MemorySnapshot[] = [];
    const prefix = `${this.path}/`;

    for (const [key, data] of this.store.entries()) {
      if (key.startsWith(prefix)) {
        const remainder = key.slice(prefix.length);
        if (!remainder.includes('/')) {
          const docId = remainder;
          const ref = new MemoryDocumentRef(docId, key, this.store, this.db);
          docs.push(new MemorySnapshot(docId, data, ref));
        }
      }
    }

    // 2. Filter documents
    let filtered = docs.filter((doc) => {
      const d = doc.data() || {};
      for (const w of this._wheres) {
        const actual = d[w.field];
        if (w.op === '==') {
          if (actual !== w.val) return false;
        } else if (w.op === '!=') {
          if (actual === w.val) return false;
        } else if (w.op === '>') {
          if (!(actual > w.val)) return false;
        } else if (w.op === '>=') {
          if (actual instanceof Date || w.val instanceof Date) {
            const actualTime = actual instanceof Date ? actual.getTime() : new Date(actual).getTime();
            const valTime = w.val instanceof Date ? w.val.getTime() : new Date(w.val).getTime();
            if (!(actualTime >= valTime)) return false;
          } else if (!(actual >= w.val)) return false;
        } else if (w.op === '<') {
          if (!(actual < w.val)) return false;
        } else if (w.op === '<=') {
          if (!(actual <= w.val)) return false;
        } else if (w.op === 'in') {
          if (!Array.isArray(w.val) || !w.val.includes(actual)) return false;
        } else if (w.op === 'array-contains') {
          if (!Array.isArray(actual) || !actual.includes(w.val)) return false;
        }
      }
      return true;
    });

    // 3. Sort documents
    if (this._orderBys.length > 0) {
      filtered.sort((a, b) => {
        const dataA = a.data() || {};
        const dataB = b.data() || {};
        for (const ord of this._orderBys) {
          const valA = dataA[ord.field];
          const valB = dataB[ord.field];
          if (valA === valB) continue;
          if (valA === undefined) return 1;
          if (valB === undefined) return -1;
          const cmp = valA > valB ? 1 : -1;
          return ord.dir === 'desc' ? -cmp : cmp;
        }
        return 0;
      });
    }

    // 4. Handle pagination (startAfter)
    if (this._startAfterDoc) {
      const idx = filtered.findIndex((d) => d.id === this._startAfterDoc!.id);
      if (idx !== -1) {
        filtered = filtered.slice(idx + 1);
      }
    }

    // 5. Apply limit
    if (this._limit !== undefined && this._limit >= 0) {
      filtered = filtered.slice(0, this._limit);
    }

    return new MemoryQuerySnapshot(filtered);
  }

  private clone(): MemoryCollectionRef {
    const clone = new MemoryCollectionRef(this.path, this.store, this.db);
    clone._wheres = [...this._wheres];
    clone._orderBys = [...this._orderBys];
    clone._limit = this._limit;
    clone._startAfterDoc = this._startAfterDoc;
    return clone;
  }
}

export class InMemoryFirestore {
  private store = new Map<string, TestDocData>();

  collection(collectionName: string): MemoryCollectionRef {
    return new MemoryCollectionRef(collectionName, this.store, this);
  }

  collectionGroup(collectionName: string): MemoryCollectionRef {
    return this.collection(collectionName);
  }

  doc(docPath: string): MemoryDocumentRef {
    const parts = docPath.split('/');
    const docId = parts[parts.length - 1];
    return new MemoryDocumentRef(docId, docPath, this.store, this);
  }

  async runTransaction<T>(
    updateFunction: (transaction: {
      get: (ref: MemoryDocumentRef) => Promise<MemorySnapshot>;
      set: (ref: MemoryDocumentRef, data: TestDocData, options?: any) => void;
      update: (ref: MemoryDocumentRef, data: TestDocData) => void;
      delete: (ref: MemoryDocumentRef) => void;
    }) => Promise<T>
  ): Promise<T> {
    // Stage mutations so any throw rolls back completely
    const stagedMutations: Array<() => void> = [];

    const transaction = {
      get: async (ref: MemoryDocumentRef) => {
        return ref.get();
      },
      create: (ref: MemoryDocumentRef, data: TestDocData) => {
        stagedMutations.push(() => {
          ref.set(data);
        });
      },
      set: (ref: MemoryDocumentRef, data: TestDocData, options?: any) => {
        stagedMutations.push(() => {
          ref.set(data, options);
        });
      },
      update: (ref: MemoryDocumentRef, data: TestDocData) => {
        stagedMutations.push(() => {
          ref.update(data);
        });
      },
      delete: (ref: MemoryDocumentRef) => {
        stagedMutations.push(() => {
          ref.delete();
        });
      },
    };

    const result = await updateFunction(transaction);

    // Commit staged mutations atomically
    for (const mutate of stagedMutations) {
      mutate();
    }

    return result;
  }

  batch() {
    const operations: Array<() => Promise<void>> = [];
    return {
      set: (ref: MemoryDocumentRef, data: TestDocData, options?: any) => {
        operations.push(() => ref.set(data, options));
        return this;
      },
      update: (ref: MemoryDocumentRef, data: TestDocData) => {
        operations.push(() => ref.update(data));
        return this;
      },
      delete: (ref: MemoryDocumentRef) => {
        operations.push(() => ref.delete());
        return this;
      },
      commit: async () => {
        for (const op of operations) {
          await op();
        }
      },
    };
  }

  clear(): void {
    this.store.clear();
  }

  dump(): Record<string, TestDocData> {
    const out: Record<string, TestDocData> = {};
    for (const [k, v] of this.store.entries()) {
      out[k] = v;
    }
    return out;
  }
}

export const testFirestore = new InMemoryFirestore();

export const FieldValue = {
  serverTimestamp: () => ({ __op: 'serverTimestamp' }),
  increment: (n: number) => ({ __op: 'increment', value: n }),
  arrayUnion: (...elements: any[]) => ({ __op: 'arrayUnion', elements }),
  arrayRemove: (...elements: any[]) => ({ __op: 'arrayRemove', elements }),
  delete: () => ({ __op: 'delete' }),
};

export class Timestamp {
  constructor(public seconds: number, public nanoseconds: number) {}
  static now(): Timestamp {
    return new Timestamp(Math.floor(Date.now() / 1000), 0);
  }
  static fromDate(date: Date): Timestamp {
    return new Timestamp(Math.floor(date.getTime() / 1000), 0);
  }
  static fromMillis(millis: number): Timestamp {
    return new Timestamp(Math.floor(millis / 1000), (millis % 1000) * 1e6);
  }
  toDate(): Date {
    return new Date(this.seconds * 1000);
  }
  toMillis(): number {
    return this.seconds * 1000;
  }
}

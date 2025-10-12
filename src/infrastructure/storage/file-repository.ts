import fs from 'fs/promises';
import path from 'path';
import { randomUUID } from 'crypto';

const ROOT = 'storage/results';

export interface StoredFile {
  id: string;
  path: string;
  name: string;
  createdAt: string;
}

export async function ensureStorage(): Promise<void> {
  await fs.mkdir(ROOT, { recursive: true });
}

export async function putFile(buffer: Buffer, filename: string): Promise<StoredFile> {
  await ensureStorage();
  const id = randomUUID();
  const ext = path.extname(filename);
  const name = `${id}${ext || ''}`;
  const full = path.join(ROOT, name);
  await fs.writeFile(full, buffer);
  return { id, path: full, name, createdAt: new Date().toISOString() };
}

export async function getFileById(id: string): Promise<StoredFile> {
  const files = await fs.readdir(ROOT);
  const file = files.find((f) => f.startsWith(id));
  if (!file) throw new Error('File not found');
  const full = path.join(ROOT, file);
  return { id, path: full, name: file, createdAt: '' };
}

export async function listFiles(): Promise<StoredFile[]> {
  await ensureStorage();
  const files = await fs.readdir(ROOT);
  const results: StoredFile[] = [];
  for (const name of files) {
    const full = path.join(ROOT, name);
    const stat = await fs.stat(full);
    const id = name.split('.')[0] ?? name;
    results.push({ id, path: full, name, createdAt: stat.birthtime.toISOString() });
  }
  return results;
}

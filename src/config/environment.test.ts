import { describe, it, expect } from 'vitest';
import path from 'path';
import { resolvePythonPath } from './environment.js';

const CWD = path.join('/', 'proj');
const winVenv = path.join(CWD, '.venv', 'Scripts', 'python.exe');
const posixVenv = path.join(CWD, '.venv', 'bin', 'python');

describe('resolvePythonPath', () => {
  it('prioriza PYTHON_PATH cuando está definida', () => {
    expect(resolvePythonPath({ PYTHON_PATH: '/usr/bin/python3' }, CWD, () => true)).toBe(
      '/usr/bin/python3',
    );
  });

  it('usa el .venv de Windows del proyecto si existe', () => {
    expect(resolvePythonPath({}, CWD, (p) => p === winVenv)).toBe(winVenv);
  });

  it('usa el .venv POSIX del proyecto si existe', () => {
    expect(resolvePythonPath({}, CWD, (p) => p === posixVenv)).toBe(posixVenv);
  });

  it('en Windows cae a "python" del PATH si no hay variable ni .venv', () => {
    expect(resolvePythonPath({}, CWD, () => false, 'win32')).toBe('python');
  });

  it('en Linux/macOS cae a "python3" (las imágenes Debian/Ubuntu no traen "python")', () => {
    expect(resolvePythonPath({}, CWD, () => false, 'linux')).toBe('python3');
    expect(resolvePythonPath({}, CWD, () => false, 'darwin')).toBe('python3');
  });

  it('ignora PYTHON_PATH vacía', () => {
    expect(resolvePythonPath({ PYTHON_PATH: '' }, CWD, () => false, 'win32')).toBe('python');
  });
});

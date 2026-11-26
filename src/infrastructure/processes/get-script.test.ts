import { describe, it, expect } from 'vitest';
import { getScript } from './get-script.js';
import { environment } from '../../config/environment.js';
import { pathNames } from '../../shared/constants.js';

describe('getScript', () => {
  it('los scripts Python usan el intérprete resuelto (no "python" fijo)', () => {
    const cmd = getScript(pathNames.PY_SCRIPTS, 'main.py');
    expect(cmd.startsWith(JSON.stringify(environment.PYTHON_PATH) + ' ')).toBe(true);
    expect(cmd).toMatch(/main\.py$/);
  });

  it('los scripts de descarga también', () => {
    const cmd = getScript(pathNames.PY_DOWNLOAD_SCRIPTS, 'fallecidos.py');
    expect(cmd.startsWith(JSON.stringify(environment.PYTHON_PATH) + ' ')).toBe(true);
  });

  it('los scripts R usan Rscript', () => {
    expect(getScript(pathNames.R_SCRIPTS, 'clean_F.R')).toMatch(/^Rscript .*clean_F\.R$/);
  });

  it('un tipo desconocido devuelve cadena vacía', () => {
    expect(getScript('/otro/', 'x')).toBe('');
  });
});

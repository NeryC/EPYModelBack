import { describe, it, expect } from 'vitest';
import {
  ProjectionQuerySchema,
  ProjectionFormatSchema,
  validateProjectionQuery,
} from './dto.js';

describe('ProjectionFormatSchema (Equivalence Partitioning)', () => {
  it.each(['json', 'csv'])('accepts valid format %s', (format) => {
    expect(() => ProjectionFormatSchema.parse(format)).not.toThrow();
  });

  it.each(['xml', 'yaml', '', 'JSON', ' csv '])(
    'rejects invalid format %s',
    (format) => {
      expect(() => ProjectionFormatSchema.parse(format)).toThrow();
    },
  );
});

describe('ProjectionQuerySchema', () => {
  it('defaults format to "json" when omitted', () => {
    const result = ProjectionQuerySchema.parse({});
    expect(result.format).toBe('json');
  });

  it('accepts format = "csv"', () => {
    const result = ProjectionQuerySchema.parse({ format: 'csv' });
    expect(result.format).toBe('csv');
  });

  it('rejects invalid format strings', () => {
    expect(() => ProjectionQuerySchema.parse({ format: 'pdf' })).toThrow();
  });
});

describe('validateProjectionQuery helper', () => {
  it('returns the parsed query on success', () => {
    expect(validateProjectionQuery({ format: 'csv' })).toEqual({ format: 'csv' });
  });

  it('throws on invalid input', () => {
    expect(() => validateProjectionQuery({ format: 'docx' })).toThrow();
  });
});

/**
 * Infrastructure Layer - Projection Repository Implementation
 * 
 * This file implements the IProjectionRepository interface from the domain layer.
 * It handles file-based persistence for projections.
 */

import fs from 'fs/promises';
import { IProjectionRepository, Projection, ProjectionDataPoint } from '../../domain/projection.js';

// File paths for projection data
const PROJECTION_FILES = {
  R: {
    json: 'public/results/proyR.json',
    csv: 'public/results/proyR.csv',
  },
  H: {
    json: 'public/results/proyH.json',
    csv: 'public/results/proyH.csv',
  },
  U: {
    json: 'public/results/proyU.json',
    csv: 'public/results/proyU.csv',
  },
  F: {
    json: 'public/results/proyF.json',
    csv: 'public/results/proyF.csv',
  },
} as const;

type ProjectionType = keyof typeof PROJECTION_FILES;

/**
 * File-based implementation of IProjectionRepository
 */
export class FileProjectionRepository implements IProjectionRepository {
  /**
   * Read and parse a single projection file
   */
  private async readProjectionFile(
    type: ProjectionType,
    format: 'json' | 'csv',
  ): Promise<ProjectionDataPoint[] | string | null> {
    const filePath = PROJECTION_FILES[type][format];

    try {
      const fileContent = await fs.readFile(filePath, 'utf-8');

      if (format === 'json') {
        return JSON.parse(fileContent) as ProjectionDataPoint[];
      }

      return fileContent;
    } catch (error) {
      throw new Error(
        `Error reading ${type} projection file (${format}): ${
          error instanceof Error ? error.message : 'Unknown error'
        }`,
      );
    }
  }

  /**
   * Get all projections in the specified format
   */
  async findAll(format: 'json' | 'csv'): Promise<ProjectionDataPoint[] | string> {
    const projectionTypes: ProjectionType[] = ['R', 'H', 'U', 'F'];
    const readPromises = projectionTypes.map((type) =>
      this.readProjectionFile(type, format).then((content) => ({
        type,
        content,
      })),
    );

    const results = await Promise.all(readPromises);

    // Build projections object from results
    const projections = results.reduce(
      (acc, { type, content }) => {
        if (content !== null) {
          acc[type] = content;
        }
        return acc;
      },
      {} as Record<ProjectionType, ProjectionDataPoint[] | string>,
    );

    // If format is JSON, return as array structure
    // If format is CSV, return as string
    if (format === 'json') {
      return projections as unknown as ProjectionDataPoint[];
    }

    // For CSV, combine all projections into a single string
    return Object.values(projections).join('\n\n') as string;
  }

  /**
   * Find projection by ID
   * Note: Current implementation uses file-based storage, so this is not fully implemented
   */
  async findById(id: string): Promise<Projection | null> {
    // In a file-based system, we'd need to read all and filter
    // For now, return null as we don't have proper ID-based storage
    return null;
  }
}


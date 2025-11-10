/**
 * Infrastructure Layer - Simulation Repository Implementation
 * 
 * This file implements the ISimulationRepository interface from the domain layer.
 * It handles file-based persistence for simulations.
 */

import fs from 'fs/promises';
import path from 'path';
import { randomUUID } from 'crypto';
import {
  ISimulationRepository,
  Simulation,
  SimulationResults,
} from '../../domain/simulation.js';

const STORAGE_FILE = 'storage/results/simulation.json';
const LEGACY_FILE = 'public/results/simulation.json';

/**
 * File-based implementation of ISimulationRepository
 */
export class FileSimulationRepository implements ISimulationRepository {
  /**
   * Ensure storage directory exists
   */
  private async ensureStorage(): Promise<void> {
    const storageDir = path.dirname(STORAGE_FILE);
    await fs.mkdir(storageDir, { recursive: true });
  }

  /**
   * Save a simulation entity to file
   */
  async save(simulation: Simulation): Promise<void> {
    await this.ensureStorage();
    const data = JSON.stringify(simulation, null, 2);
    await fs.writeFile(STORAGE_FILE, data, 'utf-8');
  }

  /**
   * Find simulation by ID
   * Note: Current implementation uses file-based storage, so we search by ID in the file
   */
  async findById(id: string): Promise<Simulation | null> {
    try {
      const data = await this.getSimulationData();
      // In a file-based system, we'd need to read all and filter
      // For now, return null as we don't have multi-simulation storage
      return null;
    } catch {
      return null;
    }
  }

  /**
   * Get the most recent simulation
   */
  async findLatest(): Promise<Simulation | null> {
    try {
      const data = await this.getSimulationData();
      // Create a simulation entity from the data
      // This is a simplified version - in a real system, you'd have proper IDs
      return {
        id: randomUUID(),
        parameters: {
          Rt: [],
          UCI_threshold: 0,
          V_filtered: 0,
          lambda_I_to_H: 0,
        },
        results: data,
        createdAt: new Date(),
        updatedAt: new Date(),
      };
    } catch {
      return null;
    }
  }

  /**
   * Get simulation file path for download
   */
  async getSimulationFilePath(): Promise<{ filePath: string; fileName: string }> {
    // Try storage file first
    try {
      await fs.access(STORAGE_FILE);
      return {
        filePath: STORAGE_FILE,
        fileName: path.basename(STORAGE_FILE),
      };
    } catch {
      // Fallback to legacy file
      try {
        await fs.access(LEGACY_FILE);
        return {
          filePath: LEGACY_FILE,
          fileName: path.basename(LEGACY_FILE),
        };
      } catch {
        throw new Error('Simulation file not found');
      }
    }
  }

  /**
   * Get simulation data as JSON
   */
  async getSimulationData(): Promise<SimulationResults> {
    // Try storage file first
    try {
      const data = await fs.readFile(STORAGE_FILE, 'utf-8');
      return JSON.parse(data) as SimulationResults;
    } catch {
      // Fallback to legacy file
      try {
        const data = await fs.readFile(LEGACY_FILE, 'utf-8');
        return JSON.parse(data) as SimulationResults;
      } catch {
        throw new Error('Simulation data file not found or invalid JSON');
      }
    }
  }
}


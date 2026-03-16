import fs from "fs/promises";
import path from "path";
import {
  getFirstSimulation,
  getSimulation,
} from "../utils/Simulation/getFirstSimulation.js";
import { SimulationParams } from "../types/index.js";

export class SimulationService {
  private readonly SIMULATION_FILE_PATH = "storage/results/simulation.json";

  /**
   * Execute simulation with custom parameters
   */
  async executeSimulation(params: SimulationParams): Promise<any> {
    const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = params;

    try {
      const result = await getSimulation(
        Rt,
        UCI_threshold,
        V_filtered,
        lambda_I_to_H,
        false
      );

      return result;
    } catch (error) {
      throw new Error(
        `Simulation execution failed: ${
          error instanceof Error ? error.message : "Unknown error"
        }`
      );
    }
  }

  /**
   * Execute first simulation with default parameters
   */
  async executeFirstSimulation(): Promise<void> {
    try {
      getFirstSimulation();
    } catch (error) {
      throw new Error(
        `First simulation execution failed: ${
          error instanceof Error ? error.message : "Unknown error"
        }`
      );
    }
  }

  /**
   * Get simulation file for download
   */
  async getSimulationFile(): Promise<{ filePath: string; fileName: string }> {
    try {
      // Prefer private storage; fallback to legacy public path
      try {
        await fs.access(this.SIMULATION_FILE_PATH);
      } catch {
        const legacy = "public/results/simulation.json";
        await fs.access(legacy);
        return { filePath: legacy, fileName: path.basename(legacy) };
      }

      const fileName = path.basename(this.SIMULATION_FILE_PATH);

      return { filePath: this.SIMULATION_FILE_PATH, fileName };
    } catch (error) {
      throw new Error("Simulation file not found");
    }
  }

  /**
   * Get first simulation data as JSON
   */
  async getFirstSimulationData(): Promise<any> {
    try {
      // First try to get data from storage file
      try {
        const data = await fs.readFile(this.SIMULATION_FILE_PATH, 'utf-8');
        return JSON.parse(data);
      } catch {
        // Fallback to legacy public path
        const legacy = "public/results/simulation.json";
        const data = await fs.readFile(legacy, 'utf-8');
        return JSON.parse(data);
      }
    } catch (error) {
      throw new Error("Simulation data file not found or invalid JSON");
    }
  }

  /**
   * Execute first simulation and get file for download
   */
  async executeAndGetSimulationFile(): Promise<{
    filePath: string;
    fileName: string;
  }> {
    try {
      // Execute the simulation first
      await this.executeFirstSimulation();

      // Then get the file
      return await this.getSimulationFile();
    } catch (error) {
      throw new Error(
        `Failed to execute and get simulation file: ${
          error instanceof Error ? error.message : "Unknown error"
        }`
      );
    }
  }

  /**
   * Validate simulation parameters
   */
  validateSimulationParams(params: SimulationParams): void {
    const { Rt, UCI_threshold, V_filtered, lambda_I_to_H } = params;

    if (!Rt || !UCI_threshold || !V_filtered || !lambda_I_to_H) {
      throw new Error("All simulation parameters are required");
    }

    // Validate Rt is a valid JSON array
    try {
      const rtArray = JSON.parse(Rt);
      if (!Array.isArray(rtArray)) {
        throw new Error("Rt must be a valid JSON array");
      }
    } catch {
      throw new Error("Rt must be a valid JSON array");
    }

    // Validate numeric parameters
    const uciThreshold = Number(UCI_threshold);
    const vFiltered = Number(V_filtered);
    const lambdaItoH = Number(lambda_I_to_H);

    if (isNaN(uciThreshold) || uciThreshold <= 0) {
      throw new Error("UCI_threshold must be a positive number");
    }

    if (isNaN(vFiltered) || vFiltered <= 0) {
      throw new Error("V_filtered must be a positive number");
    }

    if (isNaN(lambdaItoH) || lambdaItoH <= 0 || lambdaItoH > 1) {
      throw new Error("lambda_I_to_H must be a number between 0 and 1");
    }
  }
}

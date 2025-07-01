import fs from "fs/promises";

// File paths for projection data
const PROJECTION_FILES = {
  R: {
    json: "public/results/proyR.json",
    csv: "public/results/proyR.csv",
  },
  H: {
    json: "public/results/proyH.json",
    csv: "public/results/proyH.csv",
  },
  U: {
    json: "public/results/proyU.json",
    csv: "public/results/proyU.csv",
  },
  F: {
    json: "public/results/proyF.json",
    csv: "public/results/proyF.csv",
  },
} as const;

type FormatType = "json" | "csv";
type ProjectionType = keyof typeof PROJECTION_FILES;

export class ProjectionService {
  /**
   * Read and parse a single projection file
   */
  private async readProjectionFile(
    type: ProjectionType,
    format: FormatType
  ): Promise<any> {
    const filePath = PROJECTION_FILES[type][format];

    try {
      const fileContent = await fs.readFile(filePath, "utf-8");

      if (format === "json") {
        return JSON.parse(fileContent);
      }

      return fileContent;
    } catch (error) {
      console.error(
        `Error reading ${type} projection file (${format}):`,
        error
      );
      return null;
    }
  }

  /**
   * Get all projections in the specified format
   */
  async getAllProjections(
    format: FormatType
  ): Promise<Record<ProjectionType, any>> {
    const projectionTypes: ProjectionType[] = ["R", "H", "U", "F"];
    const readPromises = projectionTypes.map((type) =>
      this.readProjectionFile(type, format).then((content) => ({
        type,
        content,
      }))
    );

    const results = await Promise.all(readPromises);

    // Build projections object from results
    return results.reduce((acc, { type, content }) => {
      acc[type] = content;
      return acc;
    }, {} as Record<ProjectionType, any>);
  }
}

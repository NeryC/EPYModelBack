import { validateData } from '../src/infrastructure/processes/steps.js';

// Valida los CSV crudos de public/data antes de correr el pipeline.
validateData();
console.log('Datos crudos válidos.');

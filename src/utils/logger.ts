import pino, { type LoggerOptions, type TransportSingleOptions } from 'pino';

const level = process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug');

const options: LoggerOptions = { level };

if (process.env.NODE_ENV !== 'production') {
  const transport: TransportSingleOptions = {
    target: 'pino-pretty',
    options: { colorize: true, singleLine: true },
  };
  options.transport = transport;
}

export const logger = pino(options);

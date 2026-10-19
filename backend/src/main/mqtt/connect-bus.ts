import { MqttMessageBus, type MqttBusOptions } from '../../infrastructure/mqtt/mqtt-message-bus.js';
import type { Logger } from '../../shared/logger.js';

/** Conecta ao broker; se falhar, loga uma linha legivel e encerra (sem stack trace). */
export async function connectBusOrExit(
  options: MqttBusOptions,
  logger: Logger,
): Promise<MqttMessageBus> {
  try {
    return await MqttMessageBus.connect(options, logger);
  } catch (err) {
    logger.error('falha ao conectar no broker mqtt (infra de dev no ar?)', {
      url: options.url,
      error: err instanceof AggregateError ? (err.errors[0] as Error).message : String(err),
    });
    process.exit(1);
  }
}

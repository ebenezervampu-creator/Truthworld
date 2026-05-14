/**
 * 📡 MESSAGING SERVICE (SHARED CORE)
 * 
 * Scalable, service-agnostic Event Bus using Google Cloud Pub/Sub.
 */

import { PubSub, Topic } from "@google-cloud/pubsub";
import { logger } from "./logger";

const pubsub = new PubSub();
const topicCache = new Map<string, Topic>();

export class MessagingService {
  /**
   * Publish a message to a topic autonomously.
   */
  static async publish(topicName: string, data: any, attributes: Record<string, string> = {}): Promise<string> {
    try {
      const topic = this.getOrInitializeTopic(topicName);
      const messageId = await topic.publishMessage({
        json: data,
        attributes,
      });
      
      logger.info(`[Messaging] Published to ${topicName}`, { messageId });
      return messageId;
    } catch (err) {
      logger.error(`[Messaging] Failed to publish to ${topicName}`, { err });
      throw err;
    }
  }

  private static getOrInitializeTopic(name: string): Topic {
    if (topicCache.has(name)) return topicCache.get(name)!;
    
    const topic = pubsub.topic(name);
    topicCache.set(name, topic);
    return topic;
  }

  /**
   * Helper to parse Pub/Sub push messages (Cloud Run style data).
   */
  static parseMessage<T>(body: any): T {
    const data = body.message?.data || body.data;
    if (!data) return body as T;
    
    const raw = Buffer.from(data, 'base64').toString('utf-8');
    return JSON.parse(raw) as T;
  }
}

import axios from "axios";
import * as crypto from "crypto";

export interface CashfreeCustomerDetails {
  customer_id: string;
  customer_name?: string;
  customer_email?: string;
  customer_phone?: string;
}

export interface CreateOrderParams {
  orderId: string;
  orderAmount: number;
  orderCurrency?: string;
  customerDetails: CashfreeCustomerDetails;
  orderNote?: string;
  orderMeta?: {
    return_url?: string;
    notify_url?: string;
    payment_methods?: string;
  };
  orderTags?: Record<string, string>;
}

export interface CashfreeOrderResponse {
  cf_order_id: string;
  order_id: string;
  order_status: "ACTIVE" | "PAID" | "EXPIRED" | "TERMINATED" | string;
  order_amount: number;
  order_currency: string;
  payment_session_id?: string;
  payments?: {
    url?: string;
  };
  order_note?: string;
  order_tags?: Record<string, string>;
}

export class CashfreeService {
  private static getEnvironment(): "SANDBOX" | "PRODUCTION" {
    if (process.env.CASHFREE_ENV) {
      return process.env.CASHFREE_ENV.toUpperCase() === "PRODUCTION"
        ? "PRODUCTION"
        : "SANDBOX";
    }
    const appId = this.getAppId().trim();
    if (appId && !appId.toUpperCase().startsWith("TEST")) {
      return "PRODUCTION";
    }
    return "SANDBOX";
  }

  private static getBaseUrl(): string {
    return this.getEnvironment() === "PRODUCTION"
      ? "https://api.cashfree.com/pg"
      : "https://sandbox.cashfree.com/pg";
  }

  private static getAppId(): string {
    return process.env.CASHFREE_APP_ID || "";
  }

  private static getSecretKey(): string {
    return process.env.CASHFREE_SECRET_KEY || "";
  }

  private static getHeaders() {
    return {
      "Content-Type": "application/json",
      "x-api-version": "2023-08-01",
      "x-client-id": this.getAppId(),
      "x-client-secret": this.getSecretKey(),
    };
  }

  public static cleanPhoneNumber(phone?: string): string {
    if (!phone) return "9999999999";
    const cleaned = String(phone).replace(/[^0-9]/g, "");
    if (cleaned.length >= 10) {
      return cleaned.slice(-10);
    }
    return "9999999999";
  }

  public static cleanEmail(email?: string): string {
    if (!email || typeof email !== "string") return "user@truthworld.tv";
    const trimmed = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(trimmed) ? trimmed : "user@truthworld.tv";
  }

  public static cleanCustomerId(customerId?: string): string {
    if (!customerId) return "cust_user";
    const cleaned = String(customerId).replace(/[^a-zA-Z0-9_-]/g, "").substring(0, 50);
    return cleaned.length > 0 ? cleaned : "cust_user";
  }

  /**
   * Creates a Cashfree PG Order and returns payment_session_id
   */
  public static async createOrder(params: CreateOrderParams): Promise<CashfreeOrderResponse> {
    const appId = this.getAppId();
    const secretKey = this.getSecretKey();

    if (!appId || !secretKey) {
      console.warn("[CashfreeService] Warning: CASHFREE_APP_ID or CASHFREE_SECRET_KEY not set. Using sandbox fallback headers.");
    }

    const payload = {
      order_id: params.orderId,
      order_amount: Math.round(params.orderAmount * 100) / 100,
      order_currency: params.orderCurrency || "INR",
      customer_details: {
        customer_id: this.cleanCustomerId(params.customerDetails.customer_id),
        customer_name: params.customerDetails.customer_name || "TruthWorld User",
        customer_email: this.cleanEmail(params.customerDetails.customer_email),
        customer_phone: this.cleanPhoneNumber(params.customerDetails.customer_phone),
      },
      order_meta: {
        return_url: params.orderMeta?.return_url || "https://www.truthworld.in/checkout?action=result&order_id={order_id}",
        notify_url: params.orderMeta?.notify_url,
      },
      order_note: params.orderNote || "TruthWorld Payment",
      order_tags: params.orderTags,
    };

    const response = await axios.post<CashfreeOrderResponse>(
      `${this.getBaseUrl()}/orders`,
      payload,
      { headers: this.getHeaders(), timeout: 15000 }
    );

    return response.data;
  }

  public static isConfigured(): boolean {
    const appId = this.getAppId().trim();
    const secretKey = this.getSecretKey().trim();
    return Boolean(appId && secretKey);
  }

  /**
   * Sanitizes tag dictionary to adhere to Cashfree's strict constraints
   * (maximum 10 tags, alphanumeric/hyphens/underscores, <= 50 chars per value).
   */
  public static sanitizeOrderTags(tags?: Record<string, any>): Record<string, string> {
    if (!tags) return {};
    const sanitized: Record<string, string> = {};
    let count = 0;
    for (const [key, val] of Object.entries(tags)) {
      if (count >= 10) break;
      const cleanKey = String(key).replace(/[^a-zA-Z0-9_]/g, "").substring(0, 40);
      if (!cleanKey) continue;
      const cleanVal = String(val ?? "").replace(/[^a-zA-Z0-9_\-\.\s]/g, "").substring(0, 50);
      sanitized[cleanKey] = cleanVal;
      count++;
    }
    return sanitized;
  }

  /**
   * Creates a Cashfree PG Payment Link returning a direct hosted checkout link_url
   */
  public static async createPaymentLink(params: {
    linkId: string;
    linkAmount: number;
    linkCurrency?: string;
    linkPurpose: string;
    customerDetails: CashfreeCustomerDetails;
    returnUrl?: string;
    notifyUrl?: string;
  }): Promise<{ link_id: string; link_url: string; link_status: string }> {
    const payload = {
      link_id: params.linkId,
      link_amount: Math.round(params.linkAmount * 100) / 100,
      link_currency: params.linkCurrency || "INR",
      link_purpose: params.linkPurpose,
      customer_details: {
        customer_phone: this.cleanPhoneNumber(params.customerDetails.customer_phone),
        customer_email: this.cleanEmail(params.customerDetails.customer_email),
        customer_name: params.customerDetails.customer_name || "TruthWorld User",
      },
      link_meta: {
        return_url: params.returnUrl || "https://www.truthworld.in/checkout?action=result&order_id={order_id}",
        notify_url: params.notifyUrl,
      },
      link_notify: {
        send_sms: false,
        send_email: false,
      },
    };

    const response = await axios.post(
      `${this.getBaseUrl()}/links`,
      payload,
      { headers: this.getHeaders(), timeout: 15000 }
    );

    return response.data;
  }

  /**
   * Authoritatively fetches link status from Cashfree PG
   */
  public static async getLink(linkId: string): Promise<any> {
    const response = await axios.get(
      `${this.getBaseUrl()}/links/${encodeURIComponent(linkId)}`,
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  /**
   * Authoritatively fetches order status directly from Cashfree PG
   */
  public static async getOrder(orderId: string): Promise<CashfreeOrderResponse> {
    const response = await axios.get<CashfreeOrderResponse>(
      `${this.getBaseUrl()}/orders/${encodeURIComponent(orderId)}`,
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  /**
   * Verifies Cashfree webhook signature
   */
  public static verifyWebhookSignature(
    signature: string,
    rawBody: string,
    timestamp: string
  ): boolean {
    const secret = this.getSecretKey();
    if (!secret) return false;

    try {
      const generatedSignature = crypto
        .createHmac("sha256", secret)
        .update(timestamp + rawBody)
        .digest("base64");

      return crypto.timingSafeEqual(
        Buffer.from(signature),
        Buffer.from(generatedSignature)
      );
    } catch {
      return false;
    }
  }

  public static get PublicEnvironment(): "SANDBOX" | "PRODUCTION" {
    return this.getEnvironment();
  }
}


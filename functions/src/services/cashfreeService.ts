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

export interface CreatePlanParams {
  planId: string;
  planName: string;
  planType?: "PERIODIC" | "ON_DEMAND";
  planCurrency?: string;
  planAmount: number;
  planMaxAmount?: number;
  planIntervalType?: "DAY" | "WEEK" | "MONTH" | "YEAR";
  planIntervals?: number;
  planMaxCycles?: number;
  planNote?: string;
}

export interface CashfreePlanResponse {
  plan_id: string;
  plan_name: string;
  plan_type: string;
  plan_currency: string;
  plan_amount: number;
  plan_max_amount?: number;
  plan_interval_type: string;
  plan_intervals: number;
  plan_max_cycles: number;
  plan_status?: string;
}

export interface CreateSubscriptionParams {
  subscriptionId: string;
  planId: string;
  customerDetails: CashfreeCustomerDetails;
  subscriptionExpiry?: string;
  firstChargeTime?: string;
  returnUrl?: string;
  notifyUrl?: string;
  authorizationAmount?: number;
  paymentMethods?: string[];
  subscriptionTags?: Record<string, string>;
  subscriptionNote?: string;
}

export interface CashfreeSubscriptionResponse {
  subscription_id: string;
  sub_reference_id?: string;
  cf_subscription_id?: string;
  plan_id: string;
  customer_name?: string;
  customer_email?: string;
  customer_phone?: string;
  subscription_status: "INITIALIZED" | "BANK_APPROVAL_PENDING" | "ACTIVE" | "ON_HOLD" | "CANCELLED" | "COMPLETED" | string;
  auth_link?: string;
  payment_session_id?: string;
  current_cycle?: number;
  next_charge_date?: string;
  subscription_tags?: Record<string, string>;
}

export class CashfreeService {
  /**
   * Cashfree strictly restricts 9 countries in compliance with international
   * sanctions and regulatory frameworks.
   */
  public static readonly RESTRICTED_COUNTRIES = new Set<string>([
    "AF", "BY", "CU", "IR", "IQ", "PK", "RU", "SD", "SY",
  ]);

  /**
   * 140+ currencies supported by Cashfree International Payment Gateway.
   */
  public static readonly SUPPORTED_CURRENCIES = new Set<string>([
    "INR", "USD", "EUR", "GBP", "AUD", "CAD", "SGD", "AED", "SAR", "QAR",
    "JPY", "CHF", "NZD", "ZAR", "BRL", "MYR", "THB", "SEK", "NOK", "DKK",
    "HKD", "PLN", "MXN", "PHP", "IDR", "VND", "KRW", "KWD", "BHD", "OMR",
    "ILS", "CLP", "COP", "PEN", "ARS", "EGP", "NGN", "KES", "GHS", "TRY",
    "CZK", "HUF", "RON", "BGN", "HRK", "ISK", "TWD", "BDT", "LKR", "NPR",
    "MAD", "DZD", "TND", "JOD", "LBP", "BAM", "RSD", "UAH", "KZT", "AZN",
    "GEL", "AMD", "MNT", "UZS", "BOB", "CRC", "DOP", "GTQ", "HNL", "NIO",
    "PAB", "PYG", "UYU", "TTD", "JMD", "BBD", "BSD", "BZD", "XCD", "FJD",
    "PGK", "WST", "TOP", "VUV", "SBD", "MUR", "SCR", "BWP", "NAD", "SZL",
    "LSL", "MZN", "AOA", "ZMW", "RWF", "UGX", "TZS", "ETB", "DJF", "MGA",
    "MWK", "GMD", "SLL", "LRD", "GNF", "CVE", "STN", "XOF", "XAF", "CDF",
    "KMF", "BIF", "BND", "KHR", "LAK", "MMK", "MOP", "MDL", "ALL", "MKD",
    "BMD", "KYD", "GIP", "FKP", "SHP", "AWG", "ANG", "SRD", "GYD", "HTG",
  ]);

  public static readonly ZERO_DECIMAL_CURRENCIES = new Set<string>([
    "JPY", "KRW", "VND", "IDR", "CLP", "PYG", "UGX", "RWF", "BIF", "DJF",
    "GNF", "KMF", "MGA", "VUV", "XAF", "XOF",
  ]);

  public static isRestrictedCountry(countryCode?: string): boolean {
    if (!countryCode) return false;
    const clean = countryCode.trim().toUpperCase();
    return this.RESTRICTED_COUNTRIES.has(clean);
  }

  public static isCountrySupported(countryCode?: string): boolean {
    if (!countryCode) return true;
    return !this.isRestrictedCountry(countryCode);
  }

  public static isCurrencySupported(currency?: string): boolean {
    if (!currency) return false;
    return this.SUPPORTED_CURRENCIES.has(currency.trim().toUpperCase());
  }

  public static isZeroDecimalCurrency(currency?: string): boolean {
    if (!currency) return false;
    return this.ZERO_DECIMAL_CURRENCIES.has(currency.trim().toUpperCase());
  }

  public static getMinimumAmount(currency?: string): number {
    const cur = (currency || "INR").trim().toUpperCase();
    if (cur === "INR") return 1.0;
    if (this.isZeroDecimalCurrency(cur)) return 50.0;
    return 0.50;
  }

  public static getCurrencySymbol(currency?: string): string {
    const cur = (currency || "INR").trim().toUpperCase();
    const symbols: Record<string, string> = {
      INR: "₹",
      USD: "$",
      EUR: "€",
      GBP: "£",
      CAD: "CA$",
      AUD: "A$",
      SGD: "S$",
      AED: "AED",
      SAR: "SAR",
      QAR: "QAR",
      JPY: "¥",
      CHF: "CHF",
      NZD: "NZ$",
      ZAR: "R",
      BRL: "R$",
      MYR: "RM",
      THB: "฿",
      SEK: "kr",
      NOK: "kr",
      DKK: "kr.",
      HKD: "HK$",
      PLN: "zł",
      MXN: "MX$",
      PHP: "₱",
      IDR: "Rp",
      VND: "₫",
      KRW: "₩",
    };
    return symbols[cur] || cur;
  }

  public static formatCurrencyAmount(amount: number, currency?: string): string {
    const cur = (currency || "INR").trim().toUpperCase();
    const sym = this.getCurrencySymbol(cur);
    if (this.isZeroDecimalCurrency(cur)) {
      return `${sym}${Math.round(amount)}`;
    }
    return `${sym}${amount.toFixed(2)}`;
  }

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

  public static cleanCustomerName(name?: string): string {
    if (!name || typeof name !== "string") return "TruthWorld User";
    const cleaned = name
      .replace(/[^\w\s.]/g, "")
      .replace(/\s+/g, " ")
      .trim()
      .substring(0, 100);
    return cleaned.length >= 2 ? cleaned : "TruthWorld User";
  }

  public static cleanOrderNote(note?: string): string {
    if (!note || typeof note !== "string") return "TruthWorld Payment";
    const cleaned = note
      .replace(/[^\w\s.,\-_/]/g, "")
      .replace(/\s+/g, " ")
      .trim()
      .substring(0, 200);
    return cleaned.length >= 3 ? cleaned : "TruthWorld Payment";
  }

  public static cleanPhoneNumber(phone?: string): string {
    if (!phone) return "9999999999";
    const cleaned = String(phone).replace(/[^0-9]/g, "");
    if (cleaned.length >= 10) {
      const last10 = cleaned.slice(-10);
      if (/^[6-9]\d{9}$/.test(last10)) {
        return last10;
      }
    }
    return "9999999999";
  }

  public static cleanEmail(email?: string): string {
    if (!email || typeof email !== "string") return "user@truthworld.tv";
    const trimmed = email.trim().toLowerCase();
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return (emailRegex.test(trimmed) ? trimmed : "user@truthworld.tv").substring(0, 100);
  }

  public static cleanCustomerId(customerId?: string): string {
    if (!customerId) return "cust_user";
    let cleaned = String(customerId).replace(/[^a-zA-Z0-9_-]/g, "").substring(0, 50);
    if (cleaned.length < 3) {
      cleaned = `cust_${cleaned}`;
    }
    return cleaned.length > 0 ? cleaned.substring(0, 50) : "cust_user";
  }

  /**
   * Creates a Cashfree PG Order and returns payment_session_id
   */
  public static async createOrder(params: CreateOrderParams): Promise<CashfreeOrderResponse> {
    const appId = this.getAppId();
    const secretKey = this.getSecretKey();

    if (!appId || !secretKey) {
      if (process.env.NODE_ENV === "production") {
        throw new Error("[CashfreeService] Missing CASHFREE_APP_ID or CASHFREE_SECRET_KEY in production");
      }
      console.warn("[CashfreeService] Warning: CASHFREE_APP_ID or CASHFREE_SECRET_KEY not set. Using sandbox fallback headers.");
    }

    const currency = (params.orderCurrency || "INR").trim().toUpperCase();
    const isZeroDec = this.isZeroDecimalCurrency(currency);
    const orderAmount = isZeroDec
      ? Math.round(params.orderAmount)
      : Math.round(params.orderAmount * 100) / 100;

    const payload = {
      order_id: params.orderId,
      order_amount: orderAmount,
      order_currency: currency,
      customer_details: {
        customer_id: this.cleanCustomerId(params.customerDetails.customer_id),
        customer_name: this.cleanCustomerName(params.customerDetails.customer_name),
        customer_email: this.cleanEmail(params.customerDetails.customer_email),
        customer_phone: this.cleanPhoneNumber(params.customerDetails.customer_phone),
      },
      order_meta: {
        return_url: params.orderMeta?.return_url || "https://www.truthworld.in/payment-result?order_id={order_id}",
        notify_url: params.orderMeta?.notify_url,
      },
      order_note: this.cleanOrderNote(params.orderNote),
      order_tags: params.orderTags ? this.sanitizeOrderTags(params.orderTags) : undefined,
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
   * (maximum 10 tags, key 3-40 chars [a-zA-Z0-9_], value 1-50 chars [a-zA-Z0-9_.-], NO SPACES).
   */
  public static sanitizeOrderTags(tags?: Record<string, any>): Record<string, string> {
    if (!tags || typeof tags !== "object") return {};
    const sanitized: Record<string, string> = {};
    let count = 0;
    for (const [key, val] of Object.entries(tags)) {
      if (count >= 10) break;
      let cleanKey = String(key).replace(/[^a-zA-Z0-9_]/g, "").substring(0, 40);
      if (!cleanKey) continue;
      if (cleanKey.length < 3) {
        cleanKey = `tag_${cleanKey}`;
      }
      cleanKey = cleanKey.substring(0, 40);

      const cleanVal = String(val ?? "")
        .trim()
        .replace(/\s+/g, "_")
        .replace(/[^a-zA-Z0-9_\-\.]/g, "")
        .substring(0, 50);

      if (!cleanVal) continue;
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
        customer_name: this.cleanCustomerName(params.customerDetails.customer_name),
      },
      link_meta: {
        return_url: params.returnUrl || "https://www.truthworld.in/payment-result?order_id={order_id}",
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

  /**
   * Creates a Cashfree recurring subscription plan (or retrieves existing on 409)
   */
  public static async createSubscriptionPlan(params: CreatePlanParams): Promise<CashfreePlanResponse> {
    const cleanPlanName = String(params.planName)
      .replace(/[()]/g, "")
      .replace(/[^a-zA-Z0-9_\-\s]/g, "")
      .trim()
      .substring(0, 50);
    const cleanPlanId = String(params.planId)
      .replace(/[^a-zA-Z0-9_\-]/g, "")
      .substring(0, 40);
    const cleanPlanNote = String(params.planNote || "TruthWorld Subscription Plan")
      .replace(/[()]/g, "")
      .substring(0, 100);

    const payload = {
      plan_id: cleanPlanId,
      plan_name: cleanPlanName,
      plan_type: params.planType || "PERIODIC",
      plan_currency: params.planCurrency || "INR",
      plan_amount: Math.round(params.planAmount * 100) / 100,
      plan_recurring_amount: Math.round(params.planAmount * 100) / 100,
      plan_max_amount: params.planMaxAmount || Math.max(15000, params.planAmount * 2),
      plan_interval_type: params.planIntervalType || "MONTH",
      plan_intervals: params.planIntervals || 1,
      plan_max_cycles: params.planMaxCycles || 120,
      plan_note: cleanPlanNote,
    };

    try {
      const response = await axios.post<CashfreePlanResponse>(
        `${this.getBaseUrl()}/plans`,
        payload,
        { headers: this.getHeaders(), timeout: 15000 }
      );
      return response.data;
    } catch (err: any) {
      if (err?.response?.status === 409 || err?.response?.data?.type === "plan_already_exists") {
        return this.getSubscriptionPlan(params.planId);
      }
      throw err;
    }
  }

  /**
   * Retrieves a Cashfree subscription plan
   */
  public static async getSubscriptionPlan(planId: string): Promise<CashfreePlanResponse> {
    const response = await axios.get<CashfreePlanResponse>(
      `${this.getBaseUrl()}/plans/${encodeURIComponent(planId)}`,
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  /**
   * Creates a Cashfree subscription mandate (Auto Pay) and returns auth_link
   */
  public static async createSubscription(params: CreateSubscriptionParams): Promise<CashfreeSubscriptionResponse> {
    const cleanPlanId = String(params.planId)
      .replace(/[^a-zA-Z0-9_\-]/g, "")
      .substring(0, 40);
    const cleanSubId = String(params.subscriptionId)
      .replace(/[^a-zA-Z0-9_\-]/g, "")
      .substring(0, 40);

    const payload = {
      subscription_id: cleanSubId,
      customer_details: {
        customer_id: this.cleanCustomerId(params.customerDetails.customer_id),
        customer_name: this.cleanCustomerName(params.customerDetails.customer_name),
        customer_email: this.cleanEmail(params.customerDetails.customer_email),
        customer_phone: this.cleanPhoneNumber(params.customerDetails.customer_phone),
      },
      plan_details: {
        plan_id: cleanPlanId,
      },
      subscription_meta: {
        return_url: params.returnUrl || "https://www.truthworld.in/payment-result?subscription_id={subscription_id}",
        notify_url: params.notifyUrl,
      },
      authorization_details: {
        authorization_amount: params.authorizationAmount != null ? Math.round(params.authorizationAmount * 100) / 100 : undefined,
        payment_methods: params.paymentMethods || ["upi", "card", "enach"],
      },
      subscription_tags: params.subscriptionTags ? this.sanitizeOrderTags(params.subscriptionTags) : undefined,
      subscription_note: String(params.subscriptionNote || "TruthWorld Recurring Auto Pay").replace(/[()]/g, "").substring(0, 100),
    };

    const response = await axios.post<CashfreeSubscriptionResponse>(
      `${this.getBaseUrl()}/subscriptions`,
      payload,
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  /**
   * Authoritatively fetches subscription status directly from Cashfree Subscriptions
   */
  public static async getSubscription(subscriptionId: string): Promise<CashfreeSubscriptionResponse> {
    const response = await axios.get<CashfreeSubscriptionResponse>(
      `${this.getBaseUrl()}/subscriptions/${encodeURIComponent(subscriptionId)}`,
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  /**
   * Cancels a Cashfree subscription mandate
   */
  public static async cancelSubscription(
    subscriptionId: string,
    reason?: string
  ): Promise<{ subscription_id: string; subscription_status: string }> {
    const response = await axios.post(
      `${this.getBaseUrl()}/subscriptions/${encodeURIComponent(subscriptionId)}/cancel`,
      { cancellation_reason: reason || "Cancelled by user via TruthWorld" },
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  /**
   * Charges a subscription mandate
   */
  public static async chargeSubscription(
    subscriptionId: string,
    chargeAmount: number,
    chargeId?: string,
    note?: string
  ): Promise<any> {
    const payload = {
      charge_amount: Math.round(chargeAmount * 100) / 100,
      charge_id: chargeId || `ch_${Date.now()}`,
      charge_note: note || "TruthWorld Subscription Charge",
    };
    const response = await axios.post(
      `${this.getBaseUrl()}/subscriptions/${encodeURIComponent(subscriptionId)}/charges`,
      payload,
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  /**
   * Initiates an order refund via Cashfree PG
   */
  public static async createRefund(params: {
    orderId: string;
    refundId: string;
    refundAmount: number;
    refundNote?: string;
  }): Promise<any> {
    const payload = {
      refund_amount: Math.round(params.refundAmount * 100) / 100,
      refund_id: params.refundId,
      refund_note: params.refundNote || "TruthWorld Wallet Refund",
    };
    const response = await axios.post(
      `${this.getBaseUrl()}/orders/${encodeURIComponent(params.orderId)}/refunds`,
      payload,
      { headers: this.getHeaders(), timeout: 15000 }
    );
    return response.data;
  }

  public static get PublicEnvironment(): "SANDBOX" | "PRODUCTION" {
    return this.getEnvironment();
  }
}


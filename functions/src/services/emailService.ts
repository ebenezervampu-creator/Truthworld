import * as nodemailer from "nodemailer";
import { logger } from "firebase-functions/v2";

export interface WelcomeEmailParams {
  to: string;
  displayName?: string | null;
}

export interface ChannelWelcomeEmailParams {
  to: string;
  channelName: string;
  ownerDisplayName?: string | null;
  handle?: string | null;
}

export interface EmailSendResult {
  success: boolean;
  messageId?: string;
  error?: string;
  skipped?: boolean;
}

export class EmailService {
  private static cachedTransporter: nodemailer.Transporter | null = null;

  /**
   * Validates whether SMTP credentials (Google/Gmail SMTP) are configured in the environment.
   */
  public static isConfigured(): boolean {
    const user = process.env.SMTP_USER || process.env.SMTP_EMAIL;
    const pass = process.env.SMTP_PASS || process.env.SMTP_APP_PASSWORD;
    return Boolean(user && pass);
  }

  /**
   * Resets the cached transporter (primarily for testing and environment switching).
   */
  public static resetTransporter(): void {
    EmailService.cachedTransporter = null;
  }

  /**
   * Returns a lazily created nodemailer transporter configured for Google/Gmail SMTP.
   */
  public static getTransporter(): nodemailer.Transporter | null {
    if (!EmailService.isConfigured()) {
      return null;
    }

    if (!EmailService.cachedTransporter) {
      const user = process.env.SMTP_USER || process.env.SMTP_EMAIL;
      const pass = process.env.SMTP_PASS || process.env.SMTP_APP_PASSWORD;
      const host = process.env.SMTP_HOST || "smtp.gmail.com";
      const port = Number(process.env.SMTP_PORT || 465);
      const secure = process.env.SMTP_SECURE !== "false";

      EmailService.cachedTransporter = nodemailer.createTransport({
        host,
        port,
        secure,
        auth: {
          user,
          pass,
        },
      });
    }

    return EmailService.cachedTransporter;
  }

  /**
   * Generates a high-contrast, responsive HTML welcome email template.
   */
  public static generateWelcomeEmailHtml(displayName: string): string {
    const sanitizedName = displayName.trim() || "TruthWorld Creator";
    const currentYear = new Date().getFullYear();

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to TruthWorld</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0b0f19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #0b0f19; width: 100%; min-height: 100vh;">
    <tr>
      <td align="center" style="padding: 40px 16px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 600px; background-color: #141c2e; border: 1px solid #1e293b; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);">
          <!-- Header Bar -->
          <tr>
            <td style="padding: 32px 36px 20px 36px; border-bottom: 1px solid #1e293b; background-color: #111827;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td>
                    <span style="font-size: 22px; font-weight: 800; letter-spacing: 1.5px; color: #ffffff; text-transform: uppercase;">TRUTH<span style="color: #60a5fa;">WORLD</span></span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Body Content -->
          <tr>
            <td style="padding: 36px 36px 28px 36px;">
              <h1 style="margin: 0 0 20px 0; font-size: 24px; font-weight: 700; color: #ffffff; line-height: 1.3;">
                Welcome to TruthWorld, ${sanitizedName}!
              </h1>
              <p style="margin: 0 0 18px 0; font-size: 16px; line-height: 1.6; color: #cbd5e1;">
                We are thrilled to welcome you to our community. TruthWorld was built on the foundation of epistemic honesty, AI-powered fact-checking, and empowering creators to share authentic knowledge without deceptive gimmicks.
              </p>
              <p style="margin: 0 0 28px 0; font-size: 16px; line-height: 1.6; color: #cbd5e1;">
                Here is what you can explore right now:
              </p>
              <!-- Features List -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom: 32px;">
                <tr>
                  <td style="padding: 12px 16px; background-color: #0f172a; border-radius: 8px; border-left: 4px solid #3b82f6; margin-bottom: 10px;">
                    <div style="font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 4px;">🔍 Verified Discover & Search</div>
                    <div style="font-size: 14px; color: #94a3b8; line-height: 1.5;">Explore trending videos, verified topic feeds, and community analyses.</div>
                  </td>
                </tr>
                <tr><td style="height: 12px;"></td></tr>
                <tr>
                  <td style="padding: 12px 16px; background-color: #0f172a; border-radius: 8px; border-left: 4px solid #10b981; margin-bottom: 10px;">
                    <div style="font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 4px;">🌐 Multilingual Dubbing & Localization</div>
                    <div style="font-size: 14px; color: #94a3b8; line-height: 1.5;">Access content seamlessly in your preferred regional or global languages.</div>
                  </td>
                </tr>
                <tr><td style="height: 12px;"></td></tr>
                <tr>
                  <td style="padding: 12px 16px; background-color: #0f172a; border-radius: 8px; border-left: 4px solid #a855f7;">
                    <div style="font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 4px;">🤝 Transparent Creator Economy</div>
                    <div style="font-size: 14px; color: #94a3b8; line-height: 1.5;">Support truthful journalism and honest voices with zero manipulative marketing tricks.</div>
                  </td>
                </tr>
              </table>
              <!-- CTA Button -->
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin: 0 auto 28px auto;">
                <tr>
                  <td align="center" style="border-radius: 8px; background-color: #ffffff;">
                    <a href="https://truthworld.in" target="_blank" style="display: inline-block; padding: 14px 32px; font-size: 15px; font-weight: 700; color: #000000; text-decoration: none; border-radius: 8px; letter-spacing: 0.5px;">
                      Launch TruthWorld
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin: 0; font-size: 14px; line-height: 1.6; color: #94a3b8;">
                If you have any questions or feedback, reach out to our team anytime at <a href="mailto:hello@truthworld.in" style="color: #60a5fa; text-decoration: none; font-weight: 600;">hello@truthworld.in</a>. We are honored to have you with us.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding: 24px 36px; border-top: 1px solid #1e293b; background-color: #0d1322;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td style="font-size: 12px; color: #64748b; line-height: 1.6; text-align: center;">
                    &copy; ${currentYear} TruthWorld. All rights reserved.<br>
                    You received this email because you registered an account on TruthWorld.
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
  }

  /**
   * Generates a plain text fallback version of the welcome email.
   */
  public static generateWelcomeEmailText(displayName: string): string {
    const sanitizedName = displayName.trim() || "TruthWorld Creator";
    return `Welcome to TruthWorld, ${sanitizedName}!

We are thrilled to welcome you to our community. TruthWorld was built on the foundation of epistemic honesty, AI-powered fact-checking, and empowering creators to share authentic knowledge without deceptive gimmicks.

What you can explore right now:
- Verified Discover & Search: Explore trending videos, verified topic feeds, and community analyses.
- Multilingual Dubbing & Localization: Access content in your preferred language.
- Transparent Creator Economy: Support truthful journalism and honest voices.

Launch TruthWorld: https://truthworld.in

If you have any questions or feedback, feel free to reply to this email or contact hello@truthworld.in.

The TruthWorld Team
https://truthworld.in`;
  }

  /**
   * Sends the welcome email to a newly registered user using Google/Gmail SMTP.
   * If credentials are not configured in the environment, logs a warning and returns skipped status.
   */
  public static async sendWelcomeEmail(params: WelcomeEmailParams): Promise<EmailSendResult> {
    const { to, displayName } = params;

    if (!to || !to.includes("@")) {
      logger.warn(`[EmailService] Invalid recipient email address: "${to}". Skipping.`);
      return { success: false, skipped: true, error: "Invalid email address" };
    }

    const transporter = EmailService.getTransporter();
    if (!transporter) {
      logger.warn(
        `[EmailService] SMTP credentials not configured (SMTP_USER/SMTP_PASS). Welcome email skipped for "${to}".`
      );
      return { success: false, skipped: true, error: "SMTP credentials not configured" };
    }

    const fromUser = process.env.SMTP_USER || process.env.SMTP_EMAIL || "hello@truthworld.in";
    const fromName = process.env.SMTP_FROM_NAME || "TruthWorld";
    const fromAddress = `"${fromName}" <${fromUser}>`;
    const resolvedName = displayName || "there";

    try {
      const info = await transporter.sendMail({
        from: fromAddress,
        replyTo: `"${fromName}" <hello@truthworld.in>`,
        to,
        subject: `Welcome to TruthWorld, ${resolvedName}!`,
        text: EmailService.generateWelcomeEmailText(resolvedName),
        html: EmailService.generateWelcomeEmailHtml(resolvedName),
      });

      logger.info(`[EmailService] Welcome email successfully sent to ${to} (Message ID: ${info.messageId})`);
      return { success: true, messageId: info.messageId };
    } catch (err: any) {
      logger.error(`[EmailService] Failed to send welcome email to ${to}:`, err);
      return { success: false, error: err?.message || String(err) };
    }
  }

  /**
   * Generates a high-contrast, responsive HTML channel welcome email template.
   */
  public static generateChannelWelcomeEmailHtml(
    channelName: string,
    ownerDisplayName?: string | null,
    handle?: string | null
  ): string {
    const sanitizedChannelName = channelName.trim() || "TruthWorld Creator";
    const greetingName = ownerDisplayName?.trim() ? ` ${ownerDisplayName.trim()}` : "";
    const cleanHandle = handle ? (handle.startsWith("@") ? handle : `@${handle}`) : "";
    const currentYear = new Date().getFullYear();

    const handleDisplay = cleanHandle
      ? `<div style="font-size: 14px; color: #94a3b8; margin-top: 4px;">${cleanHandle}</div>`
      : "";

    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to TruthWorld - ${sanitizedChannelName}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #0b0f19; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #0b0f19; width: 100%; min-height: 100vh;">
    <tr>
      <td align="center" style="padding: 40px 16px;">
        <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width: 600px; background-color: #141c2e; border: 1px solid #1e293b; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 25px rgba(0, 0, 0, 0.4);">
          <!-- Header Bar -->
          <tr>
            <td style="padding: 32px 36px 20px 36px; border-bottom: 1px solid #1e293b; background-color: #111827;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td>
                    <span style="font-size: 22px; font-weight: 800; letter-spacing: 1.5px; color: #ffffff; text-transform: uppercase;">TRUTH<span style="color: #60a5fa;">WORLD</span></span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <!-- Body Content -->
          <tr>
            <td style="padding: 36px 36px 28px 36px;">
              <h1 style="margin: 0 0 20px 0; font-size: 24px; font-weight: 700; color: #ffffff; line-height: 1.3;">
                Welcome to TruthWorld, ${sanitizedChannelName}!
              </h1>
              <p style="margin: 0 0 18px 0; font-size: 16px; line-height: 1.6; color: #cbd5e1;">
                Congratulations${greetingName}! Your new creator channel is officially live on TruthWorld. You are now equipped with full ownership of your content, an engaged audience community, and powerful AI tools built on the foundation of epistemic honesty and truth.
              </p>
              <!-- Channel Info Box -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background-color: #0f172a; border: 1px solid #1e293b; border-radius: 8px; margin-bottom: 24px;">
                <tr>
                  <td style="padding: 16px 20px;">
                    <div style="font-size: 11px; font-weight: 700; text-transform: uppercase; color: #60a5fa; letter-spacing: 1.2px; margin-bottom: 4px;">Verified Creator Channel</div>
                    <div style="font-size: 18px; font-weight: 700; color: #ffffff;">${sanitizedChannelName}</div>
                    ${handleDisplay}
                  </td>
                </tr>
              </table>
              <p style="margin: 0 0 24px 0; font-size: 16px; line-height: 1.6; color: #cbd5e1;">
                Here is what you can do with your new channel:
              </p>
              <!-- Features List -->
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="margin-bottom: 32px;">
                <tr>
                  <td style="padding: 12px 16px; background-color: #0f172a; border-radius: 8px; border-left: 4px solid #3b82f6;">
                    <div style="font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 4px;">📹 High-Definition Video Publishing</div>
                    <div style="font-size: 14px; color: #94a3b8; line-height: 1.5;">Publish up to 1040p 60fps video with automated bitrate adaptation and secure offline download support.</div>
                  </td>
                </tr>
                <tr><td style="height: 12px;"></td></tr>
                <tr>
                  <td style="padding: 12px 16px; background-color: #0f172a; border-radius: 8px; border-left: 4px solid #10b981;">
                    <div style="font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 4px;">🔍 AI Fact-Checking & Trust Verification</div>
                    <div style="font-size: 14px; color: #94a3b8; line-height: 1.5;">Build authentic credibility with automated claim verification and epistemic citations that earn viewer trust.</div>
                  </td>
                </tr>
                <tr><td style="height: 12px;"></td></tr>
                <tr>
                  <td style="padding: 12px 16px; background-color: #0f172a; border-radius: 8px; border-left: 4px solid #a855f7;">
                    <div style="font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 4px;">🌐 Multilingual Dubbing & Subtitles</div>
                    <div style="font-size: 14px; color: #94a3b8; line-height: 1.5;">Reach audiences across the globe with automated AI voice dubbing and transcription in over 100 languages.</div>
                  </td>
                </tr>
                <tr><td style="height: 12px;"></td></tr>
                <tr>
                  <td style="padding: 12px 16px; background-color: #0f172a; border-radius: 8px; border-left: 4px solid #f59e0b;">
                    <div style="font-size: 15px; font-weight: 600; color: #ffffff; margin-bottom: 4px;">💎 Transparent Creator Monetization</div>
                    <div style="font-size: 14px; color: #94a3b8; line-height: 1.5;">Earn directly from your community through superchats, memberships, and clear revenue share with zero deceptive tricks.</div>
                  </td>
                </tr>
              </table>
              <!-- CTA Button -->
              <table role="presentation" cellspacing="0" cellpadding="0" border="0" style="margin: 0 auto 28px auto;">
                <tr>
                  <td align="center" style="border-radius: 8px; background-color: #ffffff;">
                    <a href="https://truthworld.in/studio" target="_blank" style="display: inline-block; padding: 14px 32px; font-size: 15px; font-weight: 700; color: #000000; text-decoration: none; border-radius: 8px; letter-spacing: 0.5px;">
                      Launch Creator Studio
                    </a>
                  </td>
                </tr>
              </table>
              <p style="margin: 0; font-size: 14px; line-height: 1.6; color: #94a3b8;">
                If you have any questions about managing your channel or need assistance getting started, reach out to our creator support team at <a href="mailto:hello@truthworld.in" style="color: #60a5fa; text-decoration: none; font-weight: 600;">hello@truthworld.in</a>.
              </p>
            </td>
          </tr>
          <!-- Footer -->
          <tr>
            <td style="padding: 24px 36px; border-top: 1px solid #1e293b; background-color: #0d1322;">
              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0">
                <tr>
                  <td style="font-size: 12px; color: #64748b; line-height: 1.6; text-align: center;">
                    &copy; ${currentYear} TruthWorld. All rights reserved.<br>
                    You received this email because you created a channel on TruthWorld.
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
  }

  /**
   * Generates a plain text fallback version of the channel welcome email.
   */
  public static generateChannelWelcomeEmailText(
    channelName: string,
    ownerDisplayName?: string | null,
    handle?: string | null
  ): string {
    const sanitizedChannelName = channelName.trim() || "TruthWorld Creator";
    const greetingName = ownerDisplayName?.trim() ? `, ${ownerDisplayName.trim()}` : "";
    const cleanHandle = handle ? (handle.startsWith("@") ? handle : `@${handle}`) : "";

    return `Welcome to TruthWorld, ${sanitizedChannelName}!

Congratulations${greetingName}! Your new creator channel is officially live on TruthWorld. You are now equipped with full ownership of your content, an engaged audience community, and powerful AI tools built on epistemic honesty and truth.

Channel Details:
- Channel: ${sanitizedChannelName}${cleanHandle ? `\n- Handle: ${cleanHandle}` : ""}
- Studio: https://truthworld.in/studio

What you can do with your new channel:
- High-Definition Video Publishing: Publish up to 1040p 60fps video with adaptive streaming and offline download support.
- AI Fact-Checking & Trust Verification: Build authentic credibility with automated claim verification and epistemic citations.
- Multilingual Dubbing & Subtitles: Reach global audiences with automated AI voice dubbing and transcription in over 100 languages.
- Transparent Creator Monetization: Earn directly from your community through superchats, memberships, and clear revenue share.

Launch Creator Studio: https://truthworld.in/studio

If you have any questions about managing your channel, feel free to reply to this email or contact hello@truthworld.in.

The TruthWorld Team
https://truthworld.in`;
  }

  /**
   * Sends the channel welcome email to a creator using Google/Gmail SMTP.
   * If credentials are not configured in the environment, logs a warning and returns skipped status.
   */
  public static async sendChannelWelcomeEmail(params: ChannelWelcomeEmailParams): Promise<EmailSendResult> {
    const { to, channelName, ownerDisplayName, handle } = params;

    if (!to || !to.includes("@")) {
      logger.warn(`[EmailService] Invalid recipient email address: "${to}". Skipping channel welcome email.`);
      return { success: false, skipped: true, error: "Invalid email address" };
    }

    const transporter = EmailService.getTransporter();
    if (!transporter) {
      logger.warn(
        `[EmailService] SMTP credentials not configured (SMTP_USER/SMTP_PASS). Channel welcome email skipped for "${to}".`
      );
      return { success: false, skipped: true, error: "SMTP credentials not configured" };
    }

    const fromUser = process.env.SMTP_USER || process.env.SMTP_EMAIL || "hello@truthworld.in";
    const fromName = process.env.SMTP_FROM_NAME || "TruthWorld";
    const fromAddress = `"${fromName}" <${fromUser}>`;
    const resolvedChannelName = (channelName || "TruthWorld Creator").trim();

    try {
      const info = await transporter.sendMail({
        from: fromAddress,
        replyTo: `"${fromName}" <hello@truthworld.in>`,
        to,
        subject: `Welcome to TruthWorld, ${resolvedChannelName}! Your channel is ready`,
        text: EmailService.generateChannelWelcomeEmailText(resolvedChannelName, ownerDisplayName, handle),
        html: EmailService.generateChannelWelcomeEmailHtml(resolvedChannelName, ownerDisplayName, handle),
      });

      logger.info(
        `[EmailService] Channel welcome email successfully sent to ${to} for channel "${resolvedChannelName}" (Message ID: ${info.messageId})`
      );
      return { success: true, messageId: info.messageId };
    } catch (err: any) {
      logger.error(`[EmailService] Failed to send channel welcome email to ${to}:`, err);
      return { success: false, error: err?.message || String(err) };
    }
  }
}

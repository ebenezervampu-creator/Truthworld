import { EmailService } from "../../src/services/emailService";
import * as nodemailer from "nodemailer";

jest.mock("nodemailer");

describe("Unit: EmailService (Google SMTP)", () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    jest.clearAllMocks();
    process.env = { ...originalEnv };
    EmailService.resetTransporter();
  });

  afterAll(() => {
    process.env = { ...originalEnv };
  });

  describe("Configuration & Environment Resolution", () => {
    it("returns false when SMTP credentials are not set", () => {
      delete process.env.SMTP_USER;
      delete process.env.SMTP_EMAIL;
      delete process.env.SMTP_PASS;
      delete process.env.SMTP_APP_PASSWORD;

      expect(EmailService.isConfigured()).toBe(false);
      expect(EmailService.getTransporter()).toBeNull();
    });

    it("returns true when SMTP_USER and SMTP_PASS are set", () => {
      process.env.SMTP_USER = "welcome@truthworld.app";
      process.env.SMTP_PASS = "abcd efgh ijkl mnop";

      expect(EmailService.isConfigured()).toBe(true);
    });

    it("returns true when SMTP_EMAIL and SMTP_APP_PASSWORD are set (alias fallback)", () => {
      delete process.env.SMTP_USER;
      delete process.env.SMTP_PASS;
      process.env.SMTP_EMAIL = "team@truthworld.app";
      process.env.SMTP_APP_PASSWORD = "test-google-app-password";

      expect(EmailService.isConfigured()).toBe(true);
    });

    it("creates a nodemailer transporter with Google SMTP defaults", () => {
      process.env.SMTP_USER = "welcome@truthworld.app";
      process.env.SMTP_PASS = "samplepassword";

      const mockCreateTransport = nodemailer.createTransport as jest.Mock;
      mockCreateTransport.mockReturnValue({ sendMail: jest.fn() });

      const transporter = EmailService.getTransporter();
      expect(transporter).not.toBeNull();
      expect(mockCreateTransport).toHaveBeenCalledWith({
        host: "smtp.gmail.com",
        port: 465,
        secure: true,
        auth: {
          user: "welcome@truthworld.app",
          pass: "samplepassword",
        },
      });
    });
  });

  describe("Template Generation", () => {
    it("generates high-contrast HTML email containing user name and truthworld branding", () => {
      const html = EmailService.generateWelcomeEmailHtml("Ada Lovelace");

      expect(html).toContain("Welcome to TruthWorld, Ada Lovelace!");
      expect(html).toContain("TRUTH");
      expect(html).toContain("WORLD");
      expect(html).toContain("https://truthworld.in");
      // Contrast check: high contrast text and dark canvas
      expect(html).toContain("#0b0f19"); // canvas
      expect(html).toContain("#ffffff"); // headings & text
      expect(html).toContain("#000000"); // black text on white CTA button
    });

    it("falls back to 'TruthWorld Creator' when display name is empty or whitespace", () => {
      const html = EmailService.generateWelcomeEmailHtml("   ");
      expect(html).toContain("Welcome to TruthWorld, TruthWorld Creator!");

      const text = EmailService.generateWelcomeEmailText("");
      expect(text).toContain("Welcome to TruthWorld, TruthWorld Creator!");
    });
  });

  describe("Sending Emails", () => {
    it("skips execution cleanly if recipient email is invalid", async () => {
      const result = await EmailService.sendWelcomeEmail({
        to: "not-an-email",
        displayName: "Test",
      });

      expect(result.success).toBe(false);
      expect(result.skipped).toBe(true);
      expect(result.error).toBe("Invalid email address");
    });

    it("skips execution cleanly if SMTP credentials are missing", async () => {
      delete process.env.SMTP_USER;
      delete process.env.SMTP_EMAIL;
      delete process.env.SMTP_PASS;
      delete process.env.SMTP_APP_PASSWORD;

      const result = await EmailService.sendWelcomeEmail({
        to: "newuser@example.com",
        displayName: "New User",
      });

      expect(result.success).toBe(false);
      expect(result.skipped).toBe(true);
      expect(result.error).toContain("SMTP credentials not configured");
    });

    it("dispatches email when configured and returns messageId", async () => {
      process.env.SMTP_USER = "welcome@truthworld.app";
      process.env.SMTP_PASS = "samplepassword";

      const mockSendMail = jest.fn().mockResolvedValue({ messageId: "<msg-12345@google.com>" });
      (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail: mockSendMail });

      const result = await EmailService.sendWelcomeEmail({
        to: "creator@example.com",
        displayName: "Truth Seeker",
      });

      expect(result.success).toBe(true);
      expect(result.messageId).toBe("<msg-12345@google.com>");
      expect(mockSendMail).toHaveBeenCalledTimes(1);

      const sendArgs = mockSendMail.mock.calls[0][0];
      expect(sendArgs.to).toBe("creator@example.com");
      expect(sendArgs.subject).toBe("Welcome to TruthWorld, Truth Seeker!");
    });

    it("gracefully catches transporter errors without throwing unhandled exceptions", async () => {
      process.env.SMTP_USER = "welcome@truthworld.app";
      process.env.SMTP_PASS = "samplepassword";

      const mockSendMail = jest.fn().mockRejectedValue(new Error("Connection timeout to smtp.gmail.com"));
      (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail: mockSendMail });

      const result = await EmailService.sendWelcomeEmail({
        to: "creator@example.com",
        displayName: "Truth Seeker",
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain("Connection timeout");
    });
  });

  describe("Channel Template Generation", () => {
    it("generates high-contrast HTML channel welcome email containing channel name, handle, and features", () => {
      const html = EmailService.generateChannelWelcomeEmailHtml(
        "Truth Investigations",
        "John Doe",
        "@truth_investigations"
      );

      expect(html).toContain("Welcome to TruthWorld, Truth Investigations!");
      expect(html).toContain("TRUTH");
      expect(html).toContain("WORLD");
      expect(html).toContain("John Doe");
      expect(html).toContain("@truth_investigations");
      expect(html).toContain("Launch Creator Studio");
      expect(html).toContain("https://truthworld.in/studio");
      // Contrast check: high contrast dark canvas & clean text
      expect(html).toContain("#0b0f19");
      expect(html).toContain("#ffffff");
      expect(html).toContain("#000000"); // CTA button font
    });

    it("falls back to 'TruthWorld Creator' when channel name is empty or whitespace", () => {
      const html = EmailService.generateChannelWelcomeEmailHtml("   ");
      expect(html).toContain("Welcome to TruthWorld, TruthWorld Creator!");

      const text = EmailService.generateChannelWelcomeEmailText("");
      expect(text).toContain("Welcome to TruthWorld, TruthWorld Creator!");
    });

    it("formats handle cleanly with leading @ in text and HTML", () => {
      const text = EmailService.generateChannelWelcomeEmailText("Tech Daily", "Alice", "techdaily");
      expect(text).toContain("- Handle: @techdaily");
      expect(text).toContain("Launch Creator Studio: https://truthworld.in/studio");

      const html = EmailService.generateChannelWelcomeEmailHtml("Tech Daily", "Alice", "techdaily");
      expect(html).toContain("@techdaily");
    });
  });

  describe("Sending Channel Welcome Emails", () => {
    it("skips execution cleanly if recipient email is invalid", async () => {
      const result = await EmailService.sendChannelWelcomeEmail({
        to: "invalid-email-format",
        channelName: "Science Channel",
      });

      expect(result.success).toBe(false);
      expect(result.skipped).toBe(true);
      expect(result.error).toBe("Invalid email address");
    });

    it("skips execution cleanly if SMTP credentials are not configured", async () => {
      delete process.env.SMTP_USER;
      delete process.env.SMTP_EMAIL;
      delete process.env.SMTP_PASS;
      delete process.env.SMTP_APP_PASSWORD;

      const result = await EmailService.sendChannelWelcomeEmail({
        to: "creator@example.com",
        channelName: "Science Channel",
      });

      expect(result.success).toBe(false);
      expect(result.skipped).toBe(true);
      expect(result.error).toContain("SMTP credentials not configured");
    });

    it("dispatches channel welcome email when configured and returns messageId", async () => {
      process.env.SMTP_USER = "welcome@truthworld.app";
      process.env.SMTP_PASS = "samplepassword";

      const mockSendMail = jest.fn().mockResolvedValue({ messageId: "<channel-msg-67890@google.com>" });
      (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail: mockSendMail });

      const result = await EmailService.sendChannelWelcomeEmail({
        to: "newchannel@example.com",
        channelName: "Cosmos & Truth",
        ownerDisplayName: "Carl",
        handle: "@cosmos_truth",
      });

      expect(result.success).toBe(true);
      expect(result.messageId).toBe("<channel-msg-67890@google.com>");
      expect(mockSendMail).toHaveBeenCalledTimes(1);

      const sendArgs = mockSendMail.mock.calls[0][0];
      expect(sendArgs.to).toBe("newchannel@example.com");
      expect(sendArgs.subject).toBe("Welcome to TruthWorld, Cosmos & Truth! Your channel is ready");
      expect(sendArgs.text).toContain("Welcome to TruthWorld, Cosmos & Truth!");
      expect(sendArgs.html).toContain("Cosmos &amp; Truth");
    });

    it("gracefully catches transporter errors without throwing unhandled exceptions", async () => {
      process.env.SMTP_USER = "welcome@truthworld.app";
      process.env.SMTP_PASS = "samplepassword";

      const mockSendMail = jest.fn().mockRejectedValue(new Error("Connection refused by SMTP gateway"));
      (nodemailer.createTransport as jest.Mock).mockReturnValue({ sendMail: mockSendMail });

      const result = await EmailService.sendChannelWelcomeEmail({
        to: "newchannel@example.com",
        channelName: "Cosmos & Truth",
      });

      expect(result.success).toBe(false);
      expect(result.error).toContain("Connection refused");
    });
  });
});

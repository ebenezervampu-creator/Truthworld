import * as admin from "firebase-admin";
import { dispatchChannelWelcomeEmail } from "../../src/channels/channels";
import { EmailService } from "../../src/services/emailService";

jest.mock("../../src/services/emailService");

describe("Unit: Channel Welcome Email Dispatcher", () => {
  const channelId = "chan_test_123";
  let mockFirestoreStore: Map<string, any>;
  let mockAuthUsers: Map<string, any>;

  beforeEach(() => {
    jest.clearAllMocks();
    mockFirestoreStore = new Map();
    mockAuthUsers = new Map();

    const mockDoc = (col: string, docId: string) => {
      const key = `${col}/${docId}`;
      return {
        get: jest.fn().mockImplementation(async () => {
          const data = mockFirestoreStore.get(key);
          return {
            exists: data !== undefined,
            id: docId,
            data: () => data,
          };
        }),
        set: jest.fn().mockImplementation(async (data: any, options?: any) => {
          if (options?.merge && mockFirestoreStore.has(key)) {
            mockFirestoreStore.set(key, { ...mockFirestoreStore.get(key), ...data });
          } else {
            mockFirestoreStore.set(key, data);
          }
          return {};
        }),
      };
    };

    const mockCollection = (col: string) => ({
      doc: (docId: string) => mockDoc(col, docId),
    });

    jest.spyOn(admin, "firestore").mockReturnValue({
      collection: mockCollection as any,
    } as any);

    (admin.firestore as any).FieldValue = {
      serverTimestamp: jest.fn().mockReturnValue("MOCK_SERVER_TIMESTAMP"),
    };

    jest.spyOn(admin, "auth").mockReturnValue({
      getUser: jest.fn().mockImplementation(async (uid: string) => {
        const u = mockAuthUsers.get(uid);
        if (!u) throw new Error("User not found");
        return u;
      }),
    } as any);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("returns null when channel data is missing or marked deleted", async () => {
    const resNull = await dispatchChannelWelcomeEmail(channelId, null);
    expect(resNull).toBeNull();

    const resDeleted = await dispatchChannelWelcomeEmail(channelId, { status: "deleted" });
    expect(resDeleted).toBeNull();
    expect(EmailService.sendChannelWelcomeEmail).not.toHaveBeenCalled();
  });

  it("skips if welcomeEmailSent is already true in channel data (idempotency)", async () => {
    const res = await dispatchChannelWelcomeEmail(channelId, {
      channelName: "Science Now",
      welcomeEmailSent: true,
      ownerId: "usr_1",
    });

    expect(res).toEqual({ success: true, skipped: true });
    expect(EmailService.sendChannelWelcomeEmail).not.toHaveBeenCalled();
  });

  it("skips if welcomeEmailSent is already true in Firestore doc (idempotency)", async () => {
    mockFirestoreStore.set(`channels/${channelId}`, {
      welcomeEmailSent: true,
      channelName: "Tech Hub",
    });

    const res = await dispatchChannelWelcomeEmail(channelId, {
      channelName: "Tech Hub",
      ownerId: "usr_1",
    });

    expect(res).toEqual({ success: true, skipped: true });
    expect(EmailService.sendChannelWelcomeEmail).not.toHaveBeenCalled();
  });

  it("resolves recipient from contactEmail first", async () => {
    (EmailService.sendChannelWelcomeEmail as jest.Mock).mockResolvedValue({
      success: true,
      messageId: "msg-contact-1",
    });

    const res = await dispatchChannelWelcomeEmail(channelId, {
      channelName: "Daily News",
      contactEmail: "press@dailynews.org",
      ownerId: "usr_owner_1",
      handle: "@dailynews",
    });

    expect(res?.success).toBe(true);
    expect(EmailService.sendChannelWelcomeEmail).toHaveBeenCalledWith({
      to: "press@dailynews.org",
      channelName: "Daily News",
      ownerDisplayName: null,
      handle: "@dailynews",
    });

    const savedChannel = mockFirestoreStore.get(`channels/${channelId}`);
    expect(savedChannel.welcomeEmailSent).toBe(true);
    expect(savedChannel.welcomeEmailMessageId).toBe("msg-contact-1");
    expect(savedChannel.welcomeEmailRecipient).toBe("press@dailynews.org");
  });

  it("resolves recipient from Firestore user document if contactEmail is absent", async () => {
    mockFirestoreStore.set("users/usr_owner_2", {
      email: "creator@example.com",
      displayName: "Jane Creator",
    });

    (EmailService.sendChannelWelcomeEmail as jest.Mock).mockResolvedValue({
      success: true,
      messageId: "msg-user-doc-2",
    });

    const res = await dispatchChannelWelcomeEmail(channelId, {
      channelName: "Jane's Corner",
      ownerId: "usr_owner_2",
    });

    expect(res?.success).toBe(true);
    expect(EmailService.sendChannelWelcomeEmail).toHaveBeenCalledWith({
      to: "creator@example.com",
      channelName: "Jane's Corner",
      ownerDisplayName: "Jane Creator",
      handle: null,
    });

    const savedChannel = mockFirestoreStore.get(`channels/${channelId}`);
    expect(savedChannel.welcomeEmailSent).toBe(true);
    expect(savedChannel.welcomeEmailRecipient).toBe("creator@example.com");
  });

  it("resolves recipient from Firebase Auth if user document does not have an email", async () => {
    mockFirestoreStore.set("users/usr_owner_3", {
      displayName: "Auth User",
    });
    mockAuthUsers.set("usr_owner_3", {
      email: "authuser@example.com",
      displayName: "Auth User",
    });

    (EmailService.sendChannelWelcomeEmail as jest.Mock).mockResolvedValue({
      success: true,
      messageId: "msg-auth-3",
    });

    const res = await dispatchChannelWelcomeEmail(channelId, {
      channelName: "Auth Channel",
      ownerId: "usr_owner_3",
      handle: "auth_channel",
    });

    expect(res?.success).toBe(true);
    expect(EmailService.sendChannelWelcomeEmail).toHaveBeenCalledWith({
      to: "authuser@example.com",
      channelName: "Auth Channel",
      ownerDisplayName: "Auth User",
      handle: "auth_channel",
    });
  });

  it("skips cleanly when owner has no valid email", async () => {
    const res = await dispatchChannelWelcomeEmail(channelId, {
      channelName: "Anonymous Channel",
      ownerId: "usr_no_email",
    });

    expect(res).toEqual({
      success: false,
      skipped: true,
      error: "No recipient email found",
    });
    expect(EmailService.sendChannelWelcomeEmail).not.toHaveBeenCalled();
  });
});

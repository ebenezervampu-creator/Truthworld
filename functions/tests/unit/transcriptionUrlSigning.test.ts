import { transcriptionLayer } from '../../src/pipeline/layers/05-transcription';
import { mockFile, mockBucket } from '../setup';

describe('Transcription Layer: getAccessibleUrl URL Signing', () => {
  const getAccessibleUrl = (url: string) => (transcriptionLayer as any).getAccessibleUrl(url);

  beforeEach(() => {
    jest.clearAllMocks();
    mockFile.exists.mockResolvedValue([true]);
    mockFile.getSignedUrl.mockResolvedValue(['https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/test/original.mp4?X-Goog-Signature=mock123']);
  });

  it('signs raw Google Cloud Storage path URLs (http 403 prevention)', async () => {
    const rawGcsUrl = 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/ae5584d-e883-4777-bc01-05273792f33d/original.mp4';
    const signed = await getAccessibleUrl(rawGcsUrl);

    expect(mockBucket.file).toHaveBeenCalledWith('videos/ae5584d-e883-4777-bc01-05273792f33d/original.mp4');
    expect(mockFile.getSignedUrl).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'read',
        expires: expect.any(Number),
      })
    );
    expect(signed).toContain('X-Goog-Signature=mock123');
  });

  it('signs Firebase Storage API URLs', async () => {
    const firebaseUrl = 'https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/videos%2Fae5584d-e883-4777-bc01-05273792f33d%2Foriginal.mp4?alt=media';
    const signed = await getAccessibleUrl(firebaseUrl);

    expect(mockBucket.file).toHaveBeenCalledWith('videos/ae5584d-e883-4777-bc01-05273792f33d/original.mp4');
    expect(mockFile.getSignedUrl).toHaveBeenCalled();
    expect(signed).toContain('X-Goog-Signature=mock123');
  });

  it('signs gs:// storage URI format', async () => {
    const gsUrl = 'gs://truthworld-1.firebasestorage.app/videos/ae5584d-e883-4777-bc01-05273792f33d/original.mp4';
    const signed = await getAccessibleUrl(gsUrl);

    expect(mockBucket.file).toHaveBeenCalledWith('videos/ae5584d-e883-4777-bc01-05273792f33d/original.mp4');
    expect(mockFile.getSignedUrl).toHaveBeenCalled();
    expect(signed).toContain('X-Goog-Signature=mock123');
  });

  it('returns already signed URLs directly without re-signing', async () => {
    const alreadySignedUrl = 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/test/original.mp4?GoogleAccessId=service@account.iam.gserviceaccount.com&Expires=1700000000&Signature=abc';
    const result = await getAccessibleUrl(alreadySignedUrl);

    expect(mockFile.getSignedUrl).not.toHaveBeenCalled();
    expect(result).toBe(alreadySignedUrl);
  });

  it('returns external third-party CDN URLs without modification', async () => {
    const externalUrl = 'https://cdn.example.org/audio/sample_podcast.mp3';
    const result = await getAccessibleUrl(externalUrl);

    expect(mockFile.getSignedUrl).not.toHaveBeenCalled();
    expect(result).toBe(externalUrl);
  });

  it('falls back to firebaseStorageDownloadTokens metadata if getSignedUrl fails', async () => {
    mockFile.getSignedUrl.mockRejectedValueOnce(new Error('Signing key unavailable'));
    mockFile.getMetadata.mockResolvedValueOnce([{ metadata: { firebaseStorageDownloadTokens: 'token-abc-xyz' } }]);

    const rawGcsUrl = 'https://storage.googleapis.com/truthworld-1.firebasestorage.app/videos/ae5584d-e883-4777-bc01-05273792f33d/original.mp4';
    const result = await getAccessibleUrl(rawGcsUrl);

    expect(result).toContain('token=token-abc-xyz');
    expect(result).toContain('firebasestorage.googleapis.com');
  });
});

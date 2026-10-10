import {
  PLATFORM_LIMITS,
  ACTIVE_PHASE,
  PHASE_CONFIGS,
  getPhaseConfig,
} from '../../src/config/platformLimits';

describe('Unit: Platform Capacity & Phase Limits', () => {
  it('should have Phase 1 and Phase 2 defined in PHASE_CONFIGS', () => {
    expect(PHASE_CONFIGS[1]).toBeDefined();
    expect(PHASE_CONFIGS[1].maxStandardUsers).toBe(10000);
    expect(PHASE_CONFIGS[1].maxStandardChannels).toBe(100);
    expect(PHASE_CONFIGS[1].isCustomChannelUnlimited).toBe(true);

    expect(PHASE_CONFIGS[2]).toBeDefined();
    expect(PHASE_CONFIGS[2].maxStandardUsers).toBe(100000);
    expect(PHASE_CONFIGS[2].maxStandardChannels).toBe(1000);
    expect(PHASE_CONFIGS[2].isCustomChannelUnlimited).toBe(true);
  });

  it('should default to Phase 1 limits when no env override is present', () => {
    expect(ACTIVE_PHASE).toBe(1);
    expect(PLATFORM_LIMITS.CURRENT_PHASE).toBe(1);
    expect(PLATFORM_LIMITS.MAX_STANDARD_USERS).toBe(10000);
    expect(PLATFORM_LIMITS.MAX_STANDARD_CHANNELS).toBe(100);
    expect(PLATFORM_LIMITS.IS_CUSTOM_CHANNEL_UNLIMITED).toBe(true);
  });

  it('should resolve getPhaseConfig correctly for Phase 2', () => {
    const phase2 = getPhaseConfig(2);
    expect(phase2.phase).toBe(2);
    expect(phase2.maxStandardUsers).toBe(100000);
    expect(phase2.maxStandardChannels).toBe(1000);
  });

  it('should fallback to Phase 1 config for unknown phases', () => {
    const unknown = getPhaseConfig(999);
    expect(unknown.phase).toBe(1);
    expect(unknown.maxStandardUsers).toBe(10000);
  });
});

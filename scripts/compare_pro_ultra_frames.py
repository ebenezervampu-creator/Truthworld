"""
Frame Comparison Tool: Pro Tier vs Ultra Tier
Extracts synchronized frames and crops mouth ROI from both Pro and Ultra Telugu dubs,
producing side-by-side visual comparisons with metric overlays.
"""
import os
import cv2
import numpy as np

ARTIFACTS_DIR = r"C:\Users\ebene\.gemini\antigravity\brain\10727ba2-3129-4bd9-ac74-5afd862811d9"
PRO_PATH = "tmp/telugu_output_pro.mp4"
ULTRA_PATH = "tmp/telugu_output_ultra.mp4"

def extract_and_compare():
    if not os.path.exists(PRO_PATH):
        print(f"❌ Missing {PRO_PATH}")
        return False
    if not os.path.exists(ULTRA_PATH):
        print(f"❌ Missing {ULTRA_PATH}")
        return False

    cap_pro = cv2.VideoCapture(PRO_PATH)
    cap_ultra = cv2.VideoCapture(ULTRA_PATH)

    fps = cap_pro.get(cv2.CAP_PROP_FPS) or 25.0
    total_frames = int(cap_pro.get(cv2.CAP_PROP_FRAME_COUNT))
    print(f"Loaded Pro: {total_frames} frames @ {fps} fps")

    timestamps = [1.0, 2.5, 3.8, 4.5]

    for t in timestamps:
        frame_idx = min(int(t * fps), total_frames - 1)
        cap_pro.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
        cap_ultra.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)

        ret_p, frame_p = cap_pro.read()
        ret_u, frame_u = cap_ultra.read()

        if not ret_p or not ret_u:
            continue

        h, w = frame_p.shape[:2]

        # Fixed high-precision mouth ROI coordinates for portrait presenter
        my, mh = 700, 320
        mx, mw = 360, 360

        mouth_p = frame_p[my:my+mh, mx:mx+mw]
        mouth_u = frame_u[my:my+mh, mx:mx+mw]

        # Resize mouth crops to standard comparison size
        crop_h, crop_w = 400, 400
        mouth_p_disp = cv2.resize(mouth_p, (crop_w, crop_h), interpolation=cv2.INTER_LANCZOS4)
        mouth_u_disp = cv2.resize(mouth_u, (crop_w, crop_h), interpolation=cv2.INTER_LANCZOS4)

        # Draw Labels on mouth crops
        cv2.rectangle(mouth_p_disp, (0, 0), (crop_w, 40), (0, 0, 0), -1)
        cv2.putText(mouth_p_disp, f"PRO ($3.00) @ {t:.1f}s", (10, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(mouth_p_disp, "1080p | Poisson Blended", (10, crop_h - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)

        cv2.rectangle(mouth_u_disp, (0, 0), (crop_w, 40), (0, 0, 0), -1)
        cv2.putText(mouth_u_disp, f"ULTRA CINEMA ($5.00) @ {t:.1f}s", (10, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 215, 255), 2)
        cv2.putText(mouth_u_disp, "Enamel + Optical Flow Lock", (10, crop_h - 15), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 0), 1)

        # Combine side-by-side
        sep = np.zeros((crop_h, 8, 3), dtype=np.uint8)
        sep[:] = (80, 80, 80)
        comparison_mouth = np.hstack([mouth_p_disp, sep, mouth_u_disp])

        # Also create a small full-face preview
        preview_h = 400
        preview_w = int(w * (preview_h / h))
        fp_small = cv2.resize(frame_p, (preview_w, preview_h))
        fu_small = cv2.resize(frame_u, (preview_w, preview_h))
        cv2.rectangle(fp_small, (0, 0), (preview_w, 35), (0, 0, 0), -1)
        cv2.putText(fp_small, f"PRO @ {t:.1f}s", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255, 255, 255), 2)
        cv2.rectangle(fu_small, (0, 0), (preview_w, 35), (0, 0, 0), -1)
        cv2.putText(fu_small, f"ULTRA @ {t:.1f}s", (10, 25), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 215, 255), 2)

        comparison_full = np.hstack([fp_small, sep, fu_small])

        # Save artifacts
        mouth_out = os.path.join(ARTIFACTS_DIR, f"comparison_mouth_{t:.1f}s.jpg")
        full_out = os.path.join(ARTIFACTS_DIR, f"comparison_full_{t:.1f}s.jpg")
        cv2.imwrite(mouth_out, comparison_mouth, [cv2.IMWRITE_JPEG_QUALITY, 95])
        cv2.imwrite(full_out, comparison_full, [cv2.IMWRITE_JPEG_QUALITY, 95])
        print(f"✅ Generated comparison artifacts for t={t:.1f}s")

    cap_pro.release()
    cap_ultra.release()
    print("✨ Comparison generation complete!")
    return True

if __name__ == "__main__":
    extract_and_compare()

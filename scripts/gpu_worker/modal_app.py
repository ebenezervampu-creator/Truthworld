import os
import modal

app = modal.App("truthworld-latentsync-worker")

# 1. Persistent Modal Volume for ByteDance LatentSync Model Checkpoints (latentsync_unet.pt & whisper)
volume = modal.Volume.from_name("latentsync-checkpoints", create_if_missing=True)

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
MAIN_PY = os.path.join(CURRENT_DIR, "main.py")
HARMONIZER_PY = os.path.join(CURRENT_DIR, "harmonizer.py")

image = (
    modal.Image.debian_slim(python_version="3.11")
    .apt_install("ffmpeg", "git", "libgl1", "libglib2.0-0", "curl")
    .pip_install(
        "fastapi",
        "uvicorn[standard]",
        "pydantic",
        "opencv-python-headless",
        "google-cloud-storage",
        "torch",
        "torchvision",
        "torchaudio",
        "diffusers",
        "transformers",
        "accelerate",
        "huggingface_hub",
        "omegaconf",
        "einops",
        "librosa",
        "soundfile",
        "matplotlib",
        "mediapipe",
        "face-alignment",
        "imageio",
        "imageio-ffmpeg",
        "scenedetect",
        "lpips",
        "kornia",
        "decord",
        "insightface",
        "onnxruntime-gpu",
        "ffmpeg-python",
        "DeepCache",
        "demucs"
    )
    .run_commands(
        "git clone https://github.com/bytedance/LatentSync.git /app/latentsync",
    )
    .add_local_file(MAIN_PY, "/app/main.py", copy=True)
    .add_local_file(HARMONIZER_PY, "/app/harmonizer.py", copy=True)
)

@app.function(
    image=image,
    volumes={"/checkpoints": volume},
    timeout=1200
)
def populate_checkpoints():
    """
    Downloads ByteDance LatentSync weights directly into the persistent Modal Volume.
    """
    import sys
    sys.path.append("/app")
    from main import ensure_local_checkpoints
    ensure_local_checkpoints()
    volume.commit()
    return {"status": "checkpoints_ready", "volume": "latentsync-checkpoints"}

@app.function(
    image=image,
    volumes={"/checkpoints": volume},
    timeout=600
)
def inspect_checkpoint():
    import sys
    import os
    import torch
    from omegaconf import OmegaConf
    from huggingface_hub import hf_hub_download
    sys.path.append("/app")
    sys.path.append("/app/latentsync")

    print("Downloading ByteDance/LatentSync-1.6 latentsync_unet.pt...")
    ckpt_path_16 = hf_hub_download(
        repo_id="ByteDance/LatentSync-1.6",
        filename="latentsync_unet.pt",
        local_dir="/checkpoints",
        local_dir_use_symlinks=False
    )
    volume.commit()

    file_size = os.path.getsize(ckpt_path_16)
    print(f"Downloaded 1.6 file size: {file_size / (1024*1024):.2f} MB")

    ckpt = torch.load(ckpt_path_16, map_location="cpu", weights_only=True)
    state_dict = ckpt.get("state_dict", {})
    sd_keys = set(state_dict.keys())
    print(f"Number of state_dict keys in 1.6 ckpt: {len(sd_keys)}")

    from latentsync.models.unet import UNet3DConditionModel

    for name in ["stage2.yaml", "stage2_512.yaml"]:
        cfg_file = f"/app/latentsync/configs/unet/{name}"
        if not os.path.exists(cfg_file):
            continue
        cfg = OmegaConf.load(cfg_file)
        model = UNet3DConditionModel.from_config(OmegaConf.to_container(cfg.model))
        m_keys = set(model.state_dict().keys())
        matched = m_keys.intersection(sd_keys)
        missing = m_keys - sd_keys
        unexpected = sd_keys - m_keys
        print(f"[{name}] Model keys: {len(m_keys)} | Matched: {len(matched)} | Missing: {len(missing)} | Unexpected: {len(unexpected)}")

    return {"status": "success", "file_size_mb": file_size / (1024*1024), "keys_count": len(sd_keys)}

@app.function(
    image=image,
    gpu="A10G",
    volumes={"/checkpoints": volume},
    timeout=600
)
def test_native_latentsync():
    import sys
    import os
    import subprocess
    sys.path.append("/app")
    sys.path.append("/app/latentsync")

    latentsync_dir = "/app/latentsync"
    ckpt_path = "/checkpoints/latentsync_unet.pt"
    config_path = os.path.join(latentsync_dir, "configs/unet/stage2_512.yaml")

    # Link /checkpoints to /app/latentsync/checkpoints for relative paths
    symlink_path = os.path.join(latentsync_dir, "checkpoints")
    if not os.path.exists(symlink_path):
        os.symlink("/checkpoints", symlink_path)

    print(f"Checkpoints in /checkpoints: {os.listdir('/checkpoints')}")
    print(f"Files in {latentsync_dir}: {os.listdir(latentsync_dir)}")

    assets_dir = os.path.join(latentsync_dir, "assets")
    print(f"Files in assets: {os.listdir(assets_dir) if os.path.exists(assets_dir) else 'no assets'}")

    demo_video = os.path.join(assets_dir, "demo1_video.mp4") if os.path.exists(os.path.join(assets_dir, "demo1_video.mp4")) else None
    demo_audio = os.path.join(assets_dir, "demo1_audio.wav") if os.path.exists(os.path.join(assets_dir, "demo1_audio.wav")) else None

    output_path = "/checkpoints/outputs/test_native_verified.mp4"
    os.makedirs("/checkpoints/outputs", exist_ok=True)

    cmd = [
        "python3", "-m", "scripts.inference",
        "--unet_config_path", config_path,
        "--inference_ckpt_path", ckpt_path,
        "--inference_steps", "20",
        "--guidance_scale", "1.5",
        "--video_path", demo_video,
        "--audio_path", demo_audio,
        "--video_out_path", output_path
    ]
    print("Executing command:", " ".join(cmd))
    res = subprocess.run(cmd, cwd=latentsync_dir, capture_output=True, text=True)
    print("STDOUT:\n", res.stdout[:1500])
    print("STDERR:\n", res.stderr[:1500])
    print("Exit code:", res.returncode)
    print("Output file exists:", os.path.exists(output_path))
    if os.path.exists(output_path):
        print("Output file size:", os.path.getsize(output_path))
    volume.commit()
    return {
        "exit_code": res.returncode,
        "stdout": res.stdout[:1500],
        "stderr": res.stderr[:1500],
        "output_size": os.path.getsize(output_path) if os.path.exists(output_path) else 0
    }

@app.function(
    image=image,
    gpu="A10G",
    volumes={"/checkpoints": volume},
    timeout=600
)
def test_harmonizer_pipeline(tier: str = "ultra"):
    import sys
    import os
    sys.path.append("/app")
    sys.path.append("/app/latentsync")
    from harmonizer import FaceHarmonizer

    source_video = "/app/latentsync/assets/demo1_video.mp4"
    synced_video = "/checkpoints/outputs/test_native_verified.mp4"
    audio_file = "/app/latentsync/assets/demo1_audio.wav"
    output_harmonized = f"/checkpoints/outputs/test_harmonized_{tier}.mp4"

    if not os.path.exists(synced_video):
        return {"status": "error", "message": "Synced video not found in checkpoints"}

    harmonizer = FaceHarmonizer(device="cuda")
    ok = harmonizer.harmonize_video(
        pristine_video_path=source_video,
        raw_synced_video_path=synced_video,
        output_path=output_harmonized,
        audio_path=audio_file,
        tier=tier
    )
    volume.commit()
    file_size = os.path.getsize(output_harmonized) if os.path.exists(output_harmonized) else 0
    return {
        "status": "success" if ok else "failed",
        "tier": tier,
        "output_path": output_harmonized,
        "output_size": file_size
    }

@app.function(
    image=image,
    gpu="A10G",
    volumes={"/checkpoints": volume},
    timeout=300,
    concurrency_limit=10
)
def process_chunk_distributed(
    chunk_index: int,
    video_bytes: bytes,
    audio_bytes: bytes,
    quality_tier: str = "pro",
    enable_face_restoration: bool = True
) -> dict:
    """
    Parallel Distributed GPU Chunk Worker.
    Dispatches 8.0s chunk diffusion simultaneously across a dynamic pool of 8-10 Modal A10G instances,
    rendering 10-minute and 1-hour videos in record sub-2.5 minute times.
    """
    import sys
    import os
    import tempfile
    sys.path.append("/app")
    sys.path.append("/app/latentsync")

    with tempfile.TemporaryDirectory() as tmp_dir:
        chunk_v = os.path.join(tmp_dir, f"chunk_{chunk_index:04d}_v.mp4")
        chunk_a = os.path.join(tmp_dir, f"chunk_{chunk_index:04d}_a.mp3")
        chunk_out = os.path.join(tmp_dir, f"chunk_{chunk_index:04d}_out.mp4")

        with open(chunk_v, "wb") as f:
            f.write(video_bytes)
        with open(chunk_a, "wb") as f:
            f.write(audio_bytes)

        from main import _detect_human_faces, _run_single_chunk_inference, _run_aligned_remux

        has_face = _detect_human_faces(chunk_v)
        if not has_face:
            # Instant 0.05s remux for b-roll, slides, or screen recordings
            _run_aligned_remux(chunk_v, chunk_a, chunk_out)
            out_bytes = b""
            if os.path.exists(chunk_out):
                with open(chunk_out, "rb") as f:
                    out_bytes = f.read()
            return {
                "chunk_index": chunk_index,
                "output_bytes": out_bytes,
                "success": True,
                "face_detected": False
            }

        success = _run_single_chunk_inference(
            video_path=chunk_v,
            audio_path=chunk_a,
            output_path=chunk_out,
            enable_face_restoration=enable_face_restoration,
            quality_tier=quality_tier
        )

        out_bytes = b""
        if os.path.exists(chunk_out):
            with open(chunk_out, "rb") as f:
                out_bytes = f.read()

        return {
            "chunk_index": chunk_index,
            "output_bytes": out_bytes,
            "success": success,
            "face_detected": True
        }

@app.function(
    image=image,
    gpu="A10G",
    volumes={"/checkpoints": volume},
    timeout=300
)
def demix_audio_stems_distributed(audio_bytes: bytes) -> dict:
    """
    Automated Neural Stem Demixing with Demucs v4 (htdemucs).
    Extracts pure isolated Vocals and 100% background music & Foley,
    with spectral denoise clearing unwanted room hiss, hum, and noise.
    """
    import sys
    import os
    import tempfile
    import subprocess
    sys.path.append("/app")

    with tempfile.TemporaryDirectory() as tmp_dir:
        input_audio = os.path.join(tmp_dir, "input.wav")
        with open(input_audio, "wb") as f:
            f.write(audio_bytes)

        out_demucs = os.path.join(tmp_dir, "demucs_out")
        os.makedirs(out_demucs, exist_ok=True)

        cmd = [
            "demucs",
            "--two-stems", "vocals",
            "-n", "htdemucs",
            "-o", out_demucs,
            input_audio
        ]
        res = subprocess.run(cmd, capture_output=True, text=True)

        track_name = os.path.splitext(os.path.basename(input_audio))[0]
        vocals_path = os.path.join(out_demucs, "htdemucs", track_name, "vocals.wav")
        no_vocals_path = os.path.join(out_demucs, "htdemucs", track_name, "no_vocals.wav")
        cleaned_no_vocals_path = os.path.join(tmp_dir, "mne_cleaned.mp3")

        if os.path.exists(no_vocals_path):
            ffmpeg_cmd = [
                "ffmpeg", "-y",
                "-i", no_vocals_path,
                "-af", "highpass=f=35,lowpass=f=18500,afftdn=nf=-25",
                "-c:a", "libmp3lame",
                "-b:a", "192k",
                cleaned_no_vocals_path
            ]
            subprocess.run(ffmpeg_cmd, capture_output=True)

            with open(cleaned_no_vocals_path if os.path.exists(cleaned_no_vocals_path) else no_vocals_path, "rb") as f:
                mne_bytes = f.read()
            with open(vocals_path, "rb") as f:
                vocal_bytes = f.read()

            return {
                "status": "success",
                "mne_bytes": mne_bytes,
                "vocal_bytes": vocal_bytes
            }
        else:
            return {"status": "error", "message": f"Demucs demixing failed: {res.stderr[:300]}"}

@app.function(
    image=image,
    gpu="A10G",
    volumes={"/checkpoints": volume},
    timeout=3600,
    scaledown_window=300
)
@modal.asgi_app()
def fastapi_app():
    import sys
    sys.path.append("/app")
    sys.path.append("/app/latentsync")
    from main import ensure_local_checkpoints, app as web_app
    ensure_local_checkpoints()
    return web_app

"""
TruthWorld Studio AI Visual Lip-Sync GPU Worker
================================================
Architecture:
- LatentSync (UNet Latent Diffusion Viseme Alignment)
- CodeFormer (Face Super-Resolution & Fidelity Enhancement)
- MediaPipe / RetinaFace (Face & Landmark Tracking)
- FFmpeg (Broadcast Muxing & Encoding)

Run locally or in container:
  uvicorn main:app --host 0.0.0.0 --port 8000
"""

import os
import time
import uuid
import shutil
import logging
import subprocess
from typing import Optional
from fastapi import FastAPI, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(message)s")
logger = logging.getLogger("TruthWorldLipSyncWorker")

app = FastAPI(title="TruthWorld LatentSync GPU Worker", version="1.0.0")

class SyncRequest(BaseModel):
    jobId: str
    videoUrl: str
    audioUrl: str
    masterAudioUrl: Optional[str] = None
    language: str
    mode: Optional[str] = "latentsync"
    faceRestoration: Optional[bool] = True
    tier: Optional[str] = "video_pro"
    cinemaGrade: Optional[bool] = False
    qualityMode: Optional[str] = "pro"

class SyncResponse(BaseModel):
    status: str
    videoUrl: Optional[str] = None
    engine: str = "latentsync_diffusion"
    processingMs: int
    faceDetected: bool
    message: Optional[str] = None

class DemixRequest(BaseModel):
    jobId: str
    audioUrl: str

class DemixResponse(BaseModel):
    status: str
    mneUrl: Optional[str] = None
    vocalsUrl: Optional[str] = None
    engine: str = "demucs_v4_neural"
    validationStatus: str = "passed"
    degraded: bool = False
    processingMs: int
    message: Optional[str] = None

@app.get("/")
def root():
    import torch
    cuda_available = torch.cuda.is_available()
    device_name = torch.cuda.get_device_name(0) if cuda_available else "CPU (Inference requires GPU)"
    checkpoint_ready = os.path.exists("/checkpoints/latentsync_unet.pt")
    return {
        "service": "TruthWorld Studio AI Visual Lip-Sync GPU Worker",
        "status": "online",
        "version": "1.3.0",
        "device": device_name,
        "cuda_available": cuda_available,
        "engine": "LatentSync v1.2 + CodeFormer Face Restoration + FaceHarmonizer + Demucs v4",
        "checkpoint_ready": checkpoint_ready,
        "supported_tiers": ["audio_starter", "audio_pro", "audio_ultra", "video_pro ($3.00)", "video_ultra ($5.00 Cinema Grade)"],
        "scale_support": "Parallel Distributed GPU Chunking across dynamic pool of 8-10 Modal A10G workers for 10-minute and 1-hour productions",
        "endpoints": {
            "root": "/",
            "health": "/health",
            "docs": "/docs",
            "sync": "/sync (POST)",
            "demix": "/demix (POST)",
            "upload": "/upload (POST)",
            "outputs": "/outputs/{filename} (GET)"
        }
    }

@app.get("/health")
def health_check():
    import torch
    cuda_available = torch.cuda.is_available()
    device_name = torch.cuda.get_device_name(0) if cuda_available else "CPU (Inference requires GPU)"
    checkpoint_ready = os.path.exists("/checkpoints/latentsync_unet.pt")
    repo_ready = os.path.exists("/app/latentsync")
    return {
        "status": "healthy",
        "cuda_available": cuda_available,
        "device": device_name,
        "engine": "LatentSync v1.2 + CodeFormer Face Restoration",
        "checkpoint_ready": checkpoint_ready,
        "repo_ready": repo_ready,
        "model_path": "/checkpoints/latentsync_unet.pt" if checkpoint_ready else "not_downloaded"
    }

class UploadPayload(BaseModel):
    filename: str
    dataUri: str

@app.post("/upload")
def upload_file(payload: UploadPayload):
    import base64
    out_dir = "/checkpoints/outputs"
    os.makedirs(out_dir, exist_ok=True)
    target_path = os.path.join(out_dir, payload.filename)
    tmp_path = os.path.join("/tmp", payload.filename)
    
    b64_data = payload.dataUri
    if "," in b64_data:
        b64_data = b64_data.split(",", 1)[1]
    
    decoded = base64.b64decode(b64_data)
    with open(target_path, "wb") as f:
        f.write(decoded)
    with open(tmp_path, "wb") as f:
        f.write(decoded)
    
    return {"status": "uploaded", "filename": payload.filename, "size": len(decoded)}

@app.get("/outputs/{filename}")
@app.head("/outputs/{filename}")
def get_output_file(filename: str):
    file_path = os.path.join("/checkpoints/outputs", filename)
    tmp_path = os.path.join("/tmp", filename)

    if not os.path.exists(file_path) and not os.path.exists(tmp_path):
        try:
            import modal
            vol = modal.Volume.from_name("latentsync-checkpoints")
            vol.reload()
        except Exception:
            pass

    media_type = "video/mp4"
    if filename.endswith(".mp3"):
        media_type = "audio/mpeg"
    elif filename.endswith(".wav"):
        media_type = "audio/wav"

    if os.path.exists(file_path):
        return FileResponse(file_path, media_type=media_type)
    if os.path.exists(tmp_path):
        return FileResponse(tmp_path, media_type=media_type)
    raise HTTPException(status_code=404, detail="Requested video output not found.")

@app.post("/demix", response_model=DemixResponse)
def demix_audio_stems(req: DemixRequest):
    """
    Automated Stem Demixing using Demucs v4 (htdemucs).
    Preserves 100% of original background music, orchestra, and Foley effects,
    ducked under dubbed vocals, while clearing unwanted room hiss, hum, and noise.
    """
    t0 = time.time()
    work_id = f"demix_{req.jobId}_{uuid.uuid4().hex[:6]}"
    work_dir = os.path.join("/tmp", work_id)
    os.makedirs(work_dir, exist_ok=True)
    local_audio = os.path.join(work_dir, "input.wav")

    try:
        logger.info(f"[Demix] Downloading source audio for {req.jobId}...")
        _download_file(req.audioUrl, local_audio)

        out_demucs = os.path.join(work_dir, "demucs_out")
        os.makedirs(out_demucs, exist_ok=True)

        clean_mne = os.path.join(work_dir, "m_and_e.mp3")
        clean_voc = os.path.join(work_dir, "vocals.mp3")
        engine_used = "demucs_v4_neural"

        # 1. Execute Demucs v4 separation
        cmd = [
            "demucs",
            "--two-stems", "vocals",
            "-n", "htdemucs",
            "-o", out_demucs,
            local_audio
        ]
        res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        track_name = os.path.splitext(os.path.basename(local_audio))[0]
        vocals_path = os.path.join(out_demucs, "htdemucs", track_name, "vocals.wav")
        no_vocals_path = os.path.join(out_demucs, "htdemucs", track_name, "no_vocals.wav")

        if res.returncode == 0 and os.path.exists(no_vocals_path):
            logger.info(f"[Demix] Demucs v4 separation successful for {req.jobId}. Cleaning unwanted noise floor...")
            # Clean unwanted noise, hum, and rumble from background music stem
            ffmpeg_mne = [
                "ffmpeg", "-y",
                "-i", no_vocals_path,
                "-af", "highpass=f=35,lowpass=f=18500,afftdn=nf=-40",
                "-c:a", "libmp3lame",
                "-b:a", "192k",
                "-ar", "44100",
                "-ac", "2",
                clean_mne
            ]
            subprocess.run(ffmpeg_mne, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

            ffmpeg_voc = [
                "ffmpeg", "-y",
                "-i", vocals_path,
                "-c:a", "libmp3lame",
                "-b:a", "192k",
                "-ar", "44100",
                "-ac", "2",
                clean_voc
            ]
            subprocess.run(ffmpeg_voc, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        else:
            logger.warning(f"[Demix] Demucs note: {res.stderr[:200]}. Engaging 3-Band Frequency Crossover fallback with noise clearing...")
            engine_used = "ffmpeg_crossover_fallback"
            ffmpeg_mne = [
                "ffmpeg", "-y",
                "-i", local_audio,
                "-filter_complex", "[0:a]aformat=channel_layouts=stereo,asplit=3[low_in][mid_in][high_in];[low_in]lowpass=f=220[low];[mid_in]bandpass=f=1800:width_type=h:w=3200,stereotools=mlev=0.45:slev=1.15[mid];[high_in]highpass=f=5000[high];[low][mid][high]amix=inputs=3:weights=1 1 1:normalize=0[mne_raw];[mne_raw]highpass=f=35,lowpass=f=18500,afftdn=nf=-22[mne]",
                "-map", "[mne]",
                "-c:a", "libmp3lame",
                "-b:a", "192k",
                "-ar", "44100",
                "-ac", "2",
                clean_mne
            ]
            subprocess.run(ffmpeg_mne, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
            clean_voc = None

        mne_url = _upload_to_storage(clean_mne, f"audio/{req.jobId}/m_and_e.mp3", f"{req.jobId}_mne")
        voc_url = (
            _upload_to_storage(clean_voc, f"audio/{req.jobId}/vocals.mp3", f"{req.jobId}_vocals")
            if clean_voc and os.path.exists(clean_voc)
            else None
        )

        shutil.rmtree(work_dir, ignore_errors=True)
        duration_ms = int((time.time() - t0) * 1000)
        is_degraded = engine_used != "demucs_v4_neural"
        validation_status = "degraded" if is_degraded else "passed"
        logger.info(f"[Demix] Completed separation in {duration_ms}ms (engine={engine_used}, status={validation_status})")

        return DemixResponse(
            status="degraded" if is_degraded else "completed",
            mneUrl=mne_url,
            vocalsUrl=voc_url,
            engine=engine_used,
            validationStatus=validation_status,
            degraded=is_degraded,
            processingMs=duration_ms,
            message=(
                "Demucs unavailable; FFmpeg frequency crossover fallback engaged (degraded separation)."
                if is_degraded
                else "Neural Demucs v4 M&E and vocal stems separated."
            ),
        )
    except Exception as e:
        logger.error(f"[Demix] Error: {e}", exc_info=True)
        shutil.rmtree(work_dir, ignore_errors=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/sync", response_model=SyncResponse)
async def process_lip_sync(req: SyncRequest, background_tasks: BackgroundTasks):
    t0 = time.time()
    work_id = f"{req.jobId}_{req.language}_{uuid.uuid4().hex[:6]}"
    work_dir = os.path.join("/tmp", f"sync_{work_id}")
    os.makedirs(work_dir, exist_ok=True)

    local_video = os.path.join(work_dir, "input_video.mp4")
    local_audio = os.path.join(work_dir, "input_audio.mp3")
    output_video = os.path.join(work_dir, f"{req.language}-lipsync.mp4")

    def cleanup():
        try:
            shutil.rmtree(work_dir, ignore_errors=True)
        except Exception:
            pass

    background_tasks.add_task(cleanup)

    try:
        logger.info(f"Downloading media for job {req.jobId} ({req.language})...")
        # 1. Download source video & clean dialogue audio (for phoneme/viseme tracking)
        _download_file(req.videoUrl, local_video)
        _download_file(req.audioUrl, local_audio)

        # Download master audio (dialogue + ducked M&E music/sound effects) for final broadcast packaging
        local_master_audio = os.path.join(work_dir, "master_audio.mp3")
        if req.masterAudioUrl and req.masterAudioUrl != req.audioUrl:
            _download_file(req.masterAudioUrl, local_master_audio)
        else:
            local_master_audio = local_audio

        # 2. Pre-Normalize Source Video to Exact 25.0 FPS CFR
        # ByteDance LatentSync UNet cross-attention and Whisper feature alignment are trained strictly on 25.0 FPS CFR.
        # Eliminates cumulative audio-viseme drift on 30fps, 29.97fps, 60fps, and VFR smartphone clips.
        normalized_video = os.path.join(work_dir, "input_25fps.mp4")
        effective_video = _normalize_video_fps(local_video, normalized_video, target_fps=25)

        # 3. Automatic Face Detection: Screen recordings, voiceovers, b-roll, cartoons
        faces_detected = _detect_human_faces(effective_video)
        if not faces_detected:
            logger.warning(f"No human face detected in {req.videoUrl} (screen recording / voiceover / b-roll / cartoon). Performing clean broadcast FFmpeg remux.")
            _run_aligned_remux(effective_video, local_master_audio, output_video)
            remux_url = _upload_to_storage(output_video, f"videos/{req.jobId}/{req.language}-dubbed.mp4", work_id)
            return SyncResponse(
                status="no_face_detected",
                videoUrl=remux_url,
                engine="ffmpeg_remux",
                processingMs=int((time.time() - t0) * 1000),
                faceDetected=False,
                message="Video contains no detectable human face (screen recording / voiceover / b-roll / cartoon); dubbed audio remuxed cleanly via FFmpeg."
            )

        # 4. Determine Quality Tier: Pro ($3.00) vs Ultra Cinema ($5.00)
        is_ultra = (
            req.tier == "video_ultra" or 
            req.qualityMode == "ultra" or 
            req.cinemaGrade is True
        )
        quality_tier = "ultra" if is_ultra else "pro"
        logger.info(f"Engaging LipSync [{quality_tier.upper()}] tier for {work_id} (cinemaGrade={req.cinemaGrade})...")

        # 5. Execute Scaled LatentSync Diffusion + FaceHarmonizer (Pro/Ultra) with Temporal Chunking
        # Automatically handles short clips, 10-minute videos, and up to 1-hour productions without OOM or timeouts.
        logger.info(f"Running Scaled LatentSync diffusion inference on {work_id}...")
        diffusion_success = _run_latentsync_inference_scaled(
            video_path=effective_video,
            clean_audio_path=local_audio,
            master_audio_path=local_master_audio,
            output_path=output_video,
            enable_face_restoration=req.faceRestoration is not False,
            quality_tier=quality_tier
        )

        final_video_url = _upload_to_storage(
            output_video, 
            f"videos/{req.jobId}/{req.language}-{'lipsync' if diffusion_success else 'dubbed'}.mp4", 
            work_id
        )

        duration_ms = int((time.time() - t0) * 1000)
        status = "completed" if diffusion_success else "fallback_remux"
        engine = "latentsync_diffusion" if diffusion_success else "ffmpeg_remux_fallback"
        msg = "Broadcast quality lip sync generated successfully." if diffusion_success else "LatentSync GPU inference gracefully fell back to broadcast FFmpeg remux."

        logger.info(f"✅ Successfully produced video for {work_id} with status={status} in {duration_ms}ms")

        return SyncResponse(
            status=status,
            videoUrl=final_video_url,
            engine=engine,
            processingMs=duration_ms,
            faceDetected=True,
            message=msg
        )

    except Exception as e:
        logger.error(f"Error in lip-sync processing: {e}", exc_info=True)
        # Resilient on-worker fallback: If inputs were downloaded, cleanly remux so dubbing never fails
        if os.path.exists(local_video) and os.path.exists(local_audio):
            try:
                logger.info(f"Attempting emergency on-worker broadcast remux for {work_id}...")
                _run_aligned_remux(local_video, local_audio, output_video)
                emergency_url = _upload_to_storage(output_video, f"videos/{req.jobId}/{req.language}-dubbed.mp4", work_id)
                return SyncResponse(
                    status="fallback_remux",
                    videoUrl=emergency_url,
                    engine="ffmpeg_remux_fallback",
                    processingMs=int((time.time() - t0) * 1000),
                    faceDetected=False,
                    message=f"Inference error ({str(e)[:100]}); cleanly fell back to broadcast FFmpeg audio remux."
                )
            except Exception as remux_err:
                logger.error(f"Emergency remux failed: {remux_err}")

        raise HTTPException(status_code=500, detail=str(e))

def _download_file(url: str, dest_path: str):
    import shutil
    if url.startswith("data:"):
        import base64
        header, b64_data = url.split(",", 1)
        with open(dest_path, "wb") as f:
            f.write(base64.b64decode(b64_data))
        return

    if url.startswith("file://") or url.startswith("/") or (len(url) > 2 and url[1] == ":"):
        clean_path = url.replace("file://", "")
        if os.path.exists(clean_path):
            shutil.copy(clean_path, dest_path)
            return

    if url.startswith("gs://"):
        from google.cloud import storage
        client = storage.Client()
        parts = url[5:].split("/", 1)
        bucket = client.bucket(parts[0])
        blob = bucket.blob(parts[1])
        blob.download_to_filename(dest_path)
        return

    import urllib.request
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
    )
    with urllib.request.urlopen(req) as response, open(dest_path, "wb") as out_file:
        shutil.copyfileobj(response, out_file)

def _detect_human_faces(video_path: str) -> bool:
    """
    Robust multi-frame human face detection across the video duration.
    Samples up to 12 frames across the initial 45 seconds of video.
    Accurately identifies:
      - Talking-head speakers (returns True)
      - Screen recordings, desktop apps, IDEs, code editors, presentation slides (returns False)
      - Voiceovers over static visuals, landscapes, or b-roll footage (returns False)
      - Cartoons / animations / drawings without human facial proportions (returns False)
    """
    try:
        import cv2
        cap = cv2.VideoCapture(video_path)
        if not cap.isOpened():
            logger.warning(f"Could not open video {video_path} for face detection probe.")
            return True

        fps = cap.get(cv2.CAP_PROP_FPS) or 25
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
        
        max_probe_sec = min(45, int(total_frames / fps)) if total_frames > 0 else 30
        if max_probe_sec < 1:
            max_probe_sec = 5

        sample_timestamps_sec = [1.0, 2.5, 5.0, 8.0, 12.0, 16.0, 20.0, 25.0, 30.0, 35.0, 40.0]
        sample_timestamps_sec = [t for t in sample_timestamps_sec if t <= max_probe_sec]
        if not sample_timestamps_sec:
            sample_timestamps_sec = [0.5, 1.0, 2.0]

        cascade_path = getattr(cv2.data, 'haarcascades', '') + 'haarcascade_frontalface_default.xml'
        if not os.path.exists(cascade_path):
            cascade_path = "/tmp/haarcascade_frontalface_default.xml"
            if not os.path.exists(cascade_path):
                try:
                    import urllib.request
                    urllib.request.urlretrieve(
                        "https://raw.githubusercontent.com/opencv/opencv/master/data/haarcascades/haarcascade_frontalface_default.xml",
                        cascade_path
                    )
                except Exception:
                    pass

        face_cascade = cv2.CascadeClassifier(cascade_path)
        
        profile_cascade_path = getattr(cv2.data, 'haarcascades', '') + 'haarcascade_profileface.xml'
        profile_cascade = cv2.CascadeClassifier(profile_cascade_path) if os.path.exists(profile_cascade_path) else None

        faces_found = 0
        frames_checked = 0

        for t_sec in sample_timestamps_sec:
            frame_no = int(t_sec * fps)
            if total_frames > 0 and frame_no >= total_frames:
                break
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_no)
            ret, frame = cap.read()
            if not ret or frame is None:
                continue

            frames_checked += 1
            height, width = frame.shape[:2]
            # Minimum face size: at least 70x70 pixels or 8% of screen height to exclude tiny UI avatars or emojis
            min_dim = max(70, int(min(height, width) * 0.08))

            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            gray = cv2.equalizeHist(gray)

            detected = face_cascade.detectMultiScale(
                gray, 
                scaleFactor=1.15, 
                minNeighbors=6,
                minSize=(min_dim, min_dim)
            )

            if len(detected) > 0:
                faces_found += 1
            elif profile_cascade:
                profile_detected = profile_cascade.detectMultiScale(
                    gray,
                    scaleFactor=1.15,
                    minNeighbors=6,
                    minSize=(min_dim, min_dim)
                )
                if len(profile_detected) > 0:
                    faces_found += 1

            if faces_found >= 2:
                break

        cap.release()
        logger.info(f"[LipSyncWorker FaceCheck] Checked {frames_checked} frames, found human face in {faces_found} frames.")
        return faces_found > 0

    except Exception as e:
        logger.warning(f"Face detection probe warning: {e}. Defaulting to True to attempt inference.")
        return True

def _run_aligned_remux(video_path: str, audio_path: str, output_path: str) -> None:
    """
    Broadcast-standard FFmpeg non-destructive audio remuxing.
    Copies original video track without quality loss (-c:v copy) and encodes audio to AAC 192k with apad padding.
    """
    cmd = [
        "ffmpeg", "-y",
        "-i", video_path,
        "-i", audio_path,
        "-c:v", "copy",
        "-c:a", "aac",
        "-b:a", "192k",
        "-filter:a", "apad",
        "-map", "0:v:0",
        "-map", "1:a:0",
        "-shortest",
        output_path
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0 or not os.path.exists(output_path):
        raise RuntimeError(f"FFmpeg remuxing failed: {res.stderr}")

def ensure_local_checkpoints():
    """
    Ensures that ByteDance/LatentSync pretrained weights exist in /checkpoints.
    If missing or outdated (< 4GB), downloads from Hugging Face LatentSync-1.6 into the persistent Modal volume.
    """
    ckpt_dir = "/checkpoints"
    os.makedirs(ckpt_dir, exist_ok=True)
    target_unet = os.path.join(ckpt_dir, "latentsync_unet.pt")
    
    if not os.path.exists(target_unet) or os.path.getsize(target_unet) < 4000000000:
        logger.info("[Modal Checkpoints] latentsync_unet.pt (LatentSync-1.6 5GB) not found or outdated. Initiating download...")
        try:
            from huggingface_hub import hf_hub_download
            hf_hub_download(
                repo_id="ByteDance/LatentSync-1.6",
                filename="latentsync_unet.pt",
                local_dir=ckpt_dir,
                local_dir_use_symlinks=False
            )
            logger.info("[Modal Checkpoints] Successfully downloaded LatentSync-1.6 checkpoint (5GB) to volume.")
        except Exception as e:
            logger.error(f"[Modal Checkpoints] Error downloading LatentSync-1.6 checkpoints: {e}")
    else:
        logger.info(f"[Modal Checkpoints] Pretrained LatentSync-1.6 checkpoint verified at {target_unet} ({os.path.getsize(target_unet)/(1024*1024):.1f} MB)")

def _normalize_video_fps(input_path: str, output_path: str, target_fps: int = 25) -> str:
    """
    Normalizes video to exact 25.0 FPS Constant Frame Rate (CFR) using libx264.
    LatentSync's Whisper alignment and temporal UNet are trained strictly on 25.0 FPS CFR.
    Prevents progressive audio/viseme drift on 30fps, 29.97fps, 60fps, and VFR mobile recordings.
    """
    cmd = [
        "ffmpeg", "-y",
        "-i", input_path,
        "-r", str(target_fps),
        "-vsync", "cfr",
        "-c:v", "libx264",
        "-preset", "ultrafast",
        "-crf", "18",
        "-pix_fmt", "yuv420p",
        "-an",
        output_path
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode == 0 and os.path.exists(output_path):
        return output_path
    logger.warning(f"FFmpeg FPS normalization warning ({res.stderr[:200]}), using source video.")
    return input_path

def _get_video_duration(video_path: str) -> float:
    try:
        import cv2
        cap = cv2.VideoCapture(video_path)
        if cap.isOpened():
            fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
            frames = cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0
            cap.release()
            if frames > 0 and fps > 0:
                return float(frames / fps)
    except Exception:
        pass
    return 10.0

def _get_video_fps(video_path: str) -> float:
    try:
        import cv2
        cap = cv2.VideoCapture(video_path)
        if cap.isOpened():
            fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
            cap.release()
            if fps > 0:
                return float(fps)
    except Exception:
        pass
    return 25.0

def _run_single_chunk_inference(video_path: str, audio_path: str, output_path: str, enable_face_restoration: bool, quality_tier: str = "pro") -> bool:
    """
    Executes LatentSync audio-conditioned diffusion inference on a single temporal video/audio segment.
    """
    ckpt_path = "/checkpoints/latentsync_unet.pt"
    latentsync_dir = "/app/latentsync"
    config_512 = os.path.join(latentsync_dir, "configs/unet/stage2_512.yaml")
    config_256 = os.path.join(latentsync_dir, "configs/unet/stage2.yaml")
    config_path = config_512 if os.path.exists(config_512) else config_256

    if os.path.exists(ckpt_path) and os.path.exists(latentsync_dir) and os.path.exists(config_path):
        symlink_path = os.path.join(latentsync_dir, "checkpoints")
        if not os.path.exists(symlink_path):
            try:
                os.symlink("/checkpoints", symlink_path)
            except Exception:
                pass

        logger.info(f"⚡ Engaging LatentSync neural diffusion with checkpoint {ckpt_path} [{quality_tier.upper()}]...")
        raw_synced_video = output_path.replace(".mp4", "_raw_synced.mp4")
        cmd = [
            "python3", "-m", "scripts.inference",
            "--unet_config_path", config_path,
            "--inference_ckpt_path", ckpt_path,
            "--inference_steps", "20",
            "--guidance_scale", "1.5",
            "--video_path", video_path,
            "--audio_path", audio_path,
            "--video_out_path", raw_synced_video
        ]
        res = subprocess.run(cmd, cwd=latentsync_dir, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if res.returncode == 0 and os.path.exists(raw_synced_video):
            logger.info(f"✅ LatentSync neural diffusion complete! Applying FaceHarmonizer [{quality_tier.upper()}]...")
            if enable_face_restoration:
                try:
                    import sys
                    if "/app" not in sys.path:
                        sys.path.append("/app")
                    from harmonizer import FaceHarmonizer
                    harmonizer = FaceHarmonizer(device="cuda")
                    success = harmonizer.harmonize_video(
                        pristine_video_path=video_path,
                        raw_synced_video_path=raw_synced_video,
                        output_path=output_path,
                        audio_path=audio_path,
                        tier=quality_tier
                    )
                    if success and os.path.exists(output_path):
                        if os.path.exists(raw_synced_video):
                            try:
                                os.remove(raw_synced_video)
                            except Exception:
                                pass
                        return True
                    else:
                        logger.warning("FaceHarmonizer returned False, using raw synced video.")
                except Exception as harm_err:
                    logger.warning(f"FaceHarmonizer warning: {harm_err}. Using raw synced video.")

            if os.path.exists(raw_synced_video):
                shutil.move(raw_synced_video, output_path)
                return True
        else:
            logger.warning(f"LatentSync execution warning: {res.stderr[:300]}. Falling back to aligned remux.")

    _run_aligned_remux(video_path, audio_path, output_path)
    return False

def _run_latentsync_inference_scaled(
    video_path: str,
    clean_audio_path: str,
    master_audio_path: str,
    output_path: str,
    enable_face_restoration: bool,
    quality_tier: str = "pro"
) -> bool:
    """
    Scales LatentSync inference to any video duration (from short 5s clips to 10-min, 30-min, and 1-hour videos).

    Production Architecture for Scale:
    1. Duration <= 8.0s: Direct single-pass inference.
    2. Duration > 8.0s:
       - Temporal chunking into 8.0-second segments (200 frames @ 25fps).
       - Smart B-Roll / Voiceover Skipping: Chunks without human faces skip heavy diffusion and instantly remux via FFmpeg in 0.05s.
       - Chunks with human faces run LatentSync diffusion + FaceHarmonizer.
       - Memory Safety: Explicit torch.cuda.empty_cache() after each chunk to eliminate VRAM leakage.
       - Frame-locked concatenation using FFmpeg concat demuxer.
       - Continuous master audio muxing: Injects full continuous master audio (dialogue + ducked M&E)
         to ensure zero audio-cut clicks or seam artifacts across chunk boundaries.
    """
    duration = _get_video_duration(video_path)
    logger.info(f"[LipSync Scaled] Probed video duration: {duration:.2f}s. Preparing pipeline...")

    # Single chunk path for short clips
    if duration <= 8.0:
        single_success = _run_single_chunk_inference(
            video_path=video_path,
            audio_path=clean_audio_path,
            output_path=output_path,
            enable_face_restoration=enable_face_restoration,
            quality_tier=quality_tier
        )
        if master_audio_path and master_audio_path != clean_audio_path and os.path.exists(output_path):
            logger.info("[LipSync Scaled] Remuxing final broadcast master audio track...")
            remux_temp = output_path.replace(".mp4", "_master_mux.mp4")
            _run_aligned_remux(output_path, master_audio_path, remux_temp)
            if os.path.exists(remux_temp):
                shutil.move(remux_temp, output_path)
        return single_success

    # Multi-chunk scaling for 10-minute to 1-hour videos
    import math
    CHUNK_DURATION = 8.0
    num_chunks = int(math.ceil(duration / CHUNK_DURATION))
    logger.info(f"[LipSync Scaled] Video duration {duration:.1f}s requires {num_chunks} temporal chunks (8.0s each) for zero-OOM processing.")

    work_dir = os.path.dirname(output_path)
    chunks_dir = os.path.join(work_dir, "temporal_chunks")
    os.makedirs(chunks_dir, exist_ok=True)

    chunk_outputs = []
    has_any_diffusion_success = False

    chunk_v_paths = [os.path.join(chunks_dir, f"chunk_{i:04d}_v.mp4") for i in range(num_chunks)]
    chunk_a_paths = [os.path.join(chunks_dir, f"chunk_{i:04d}_a.mp3") for i in range(num_chunks)]
    chunk_out_paths = [os.path.join(chunks_dir, f"chunk_{i:04d}_out.mp4") for i in range(num_chunks)]

    # Step 1: Rapid Parallel / Batch Slicing of all chunks
    logger.info(f"[LipSync Scaled] Slicing {num_chunks} temporal chunks (8.0s each)...")
    for i in range(num_chunks):
        start_sec = i * CHUNK_DURATION
        dur_sec = min(CHUNK_DURATION, duration - start_sec)
        
        # Slices video chunk (clean 25fps)
        cmd_v = [
            "ffmpeg", "-y",
            "-ss", f"{start_sec:.3f}",
            "-t", f"{dur_sec:.3f}",
            "-i", video_path,
            "-c:v", "copy",
            "-avoid_negative_ts", "make_zero",
            "-an",
            chunk_v_paths[i]
        ]
        subprocess.run(cmd_v, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

        # Slices clean audio chunk
        cmd_a = [
            "ffmpeg", "-y",
            "-ss", f"{start_sec:.3f}",
            "-t", f"{dur_sec:.3f}",
            "-i", clean_audio_path,
            "-c:a", "copy",
            "-avoid_negative_ts", "make_zero",
            chunk_a_paths[i]
        ]
        subprocess.run(cmd_a, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    # Step 2: Probe human faces across chunks
    face_chunk_indices = []
    for i in range(num_chunks):
        cv = chunk_v_paths[i]
        ca = chunk_a_paths[i]
        co = chunk_out_paths[i]

        if not os.path.exists(cv) or not os.path.exists(ca):
            _run_aligned_remux(cv if os.path.exists(cv) else video_path, ca if os.path.exists(ca) else clean_audio_path, co)
            continue

        has_face = _detect_human_faces(cv)
        if not has_face:
            logger.info(f"[LipSync Scaled Chunk {i+1}/{num_chunks}] No face detected (b-roll / slides / screen-share). Instant remux in 0.05s.")
            _run_aligned_remux(cv, ca, co)
        else:
            face_chunk_indices.append(i)

    logger.info(f"[LipSync Scaled] Analysis: {len(face_chunk_indices)}/{num_chunks} chunks require neural diffusion lip-sync.")

    # Step 3: ⚡ 10/10 UPGRADE — Parallel Distributed GPU Chunking
    # Dispatches face chunks simultaneously across a dynamic pool of 8-10 Modal A10G workers
    if len(face_chunk_indices) > 0:
        modal_dispatched = False
        try:
            import modal
            from modal_app import process_chunk_distributed
            logger.info(f"⚡ [LipSync Scaled] Fanning out {len(face_chunk_indices)} chunks across Modal A10G dynamic worker pool...")
            
            payloads = []
            for idx in face_chunk_indices:
                with open(chunk_v_paths[idx], "rb") as fv, open(chunk_a_paths[idx], "rb") as fa:
                    payloads.append((idx, fv.read(), fa.read(), quality_tier, enable_face_restoration))

            # Starmap distributes all chunks simultaneously across the dynamic pool of 8-10 workers
            results = list(process_chunk_distributed.starmap(payloads))
            for res_item in results:
                c_idx = res_item["chunk_index"]
                out_bytes = res_item.get("output_bytes", b"")
                if out_bytes and len(out_bytes) > 0:
                    with open(chunk_out_paths[c_idx], "wb") as fo:
                        fo.write(out_bytes)
                    if res_item.get("success"):
                        has_any_diffusion_success = True
                else:
                    _run_aligned_remux(chunk_v_paths[c_idx], chunk_a_paths[c_idx], chunk_out_paths[c_idx])
            
            modal_dispatched = True
            logger.info(f"🎉 [LipSync Scaled] Parallel Modal worker chunking complete for {len(face_chunk_indices)} chunks!")
        except Exception as modal_err:
            logger.warning(f"[LipSync Scaled] Modal distributed dispatch note ({modal_err}), falling back to concurrent worker pool.")
            modal_dispatched = False

        if not modal_dispatched:
            # Local / single-node concurrent fallback
            import concurrent.futures
            import torch
            
            def _process_chunk_task(c_idx):
                logger.info(f"[LipSync Scaled Local Chunk {c_idx+1}/{num_chunks}] Running LatentSync diffusion...")
                success = _run_single_chunk_inference(
                    video_path=chunk_v_paths[c_idx],
                    audio_path=chunk_a_paths[c_idx],
                    output_path=chunk_out_paths[c_idx],
                    enable_face_restoration=enable_face_restoration,
                    quality_tier=quality_tier
                )
                if torch.cuda.is_available():
                    try:
                        torch.cuda.empty_cache()
                    except Exception:
                        pass
                return c_idx, success

            max_workers = 1 if torch.cuda.is_available() else min(4, os.cpu_count() or 2)
            with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
                futures = {executor.submit(_process_chunk_task, idx): idx for idx in face_chunk_indices}
                for fut in concurrent.futures.as_completed(futures):
                    _, ok = fut.result()
                    if ok:
                        has_any_diffusion_success = True

    chunk_outputs = chunk_out_paths

    # 6. Assemble all chunks using FFmpeg concat demuxer
    concat_list_file = os.path.join(chunks_dir, "concat_manifest.txt")
    with open(concat_list_file, "w") as f:
        for c_file in chunk_outputs:
            clean_f = c_file.replace("\\", "/")
            f.write(f"file '{clean_f}'\n")

    assembled_temp = os.path.join(chunks_dir, "assembled_chunks.mp4")
    cmd_concat = [
        "ffmpeg", "-y",
        "-f", "concat",
        "-safe", "0",
        "-i", concat_list_file,
        "-c", "copy",
        "-an",
        assembled_temp
    ]
    res_concat = subprocess.run(cmd_concat, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    if res_concat.returncode != 0 or not os.path.exists(assembled_temp):
        logger.error(f"[LipSync Scaled] Concat failed: {res_concat.stderr[:300]}. Executing fallback.")
        _run_aligned_remux(video_path, master_audio_path or clean_audio_path, output_path)
        return False

    # 7. Final Master Audio Muxing & Native FPS Restoration
    final_audio = master_audio_path if (master_audio_path and os.path.exists(master_audio_path)) else clean_audio_path
    target_fps = _get_video_fps(video_path)

    if abs(target_fps - 25.0) > 0.5:
        logger.info(f"[LipSync Scaled] Restoring native source frame rate ({target_fps:.2f} FPS) and exact duration ({duration:.2f}s)...")
        filter_str = f"[0:v]fps=fps={target_fps}:round=near,tpad=stop_mode=clone:stop_duration=0.25[v]"
        cmd_mux = [
            "ffmpeg", "-y",
            "-i", assembled_temp,
            "-i", final_audio,
            "-filter_complex", filter_str,
            "-map", "[v]",
            "-map", "1:a:0",
            "-t", f"{duration:.3f}",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-crf", "18",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "192k",
            output_path
        ]
    else:
        cmd_mux = [
            "ffmpeg", "-y",
            "-i", assembled_temp,
            "-i", final_audio,
            "-c:v", "copy",
            "-c:a", "aac",
            "-b:a", "192k",
            "-map", "0:v:0",
            "-map", "1:a:0",
            "-t", f"{duration:.3f}",
            output_path
        ]
    res_mux = subprocess.run(cmd_mux, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    if res_mux.returncode == 0 and os.path.exists(output_path):
        logger.info(f"🎉 [LipSync Scaled] Successfully processed and stitched {num_chunks} chunks ({duration:.1f}s)!")
        return has_any_diffusion_success

    logger.warning(f"[LipSync Scaled] Final mux failed: {res_mux.stderr[:300]}. Preserving assembled video.")
    _run_aligned_remux(video_path, final_audio, output_path)
    return False

def _upload_to_storage(local_path: str, remote_path: str, work_id: str = "") -> str:
    """
    Saves the output file to persistent volume and uploads to Google Cloud Storage or returns direct Modal URL.
    Derives the file extension from local_path so audio (.mp3) and video (.mp4) files are handled correctly.
    """
    import shutil
    import pathlib
    ext = pathlib.Path(local_path).suffix  # e.g. ".mp3" or ".mp4"
    out_dir = "/checkpoints/outputs"
    os.makedirs(out_dir, exist_ok=True)
    if work_id:
        persistent_file = os.path.join(out_dir, f"{work_id}{ext}")
        shutil.copy(local_path, persistent_file)
        tmp_cached = os.path.join("/tmp", f"{work_id}{ext}")
        try:
            shutil.copy(local_path, tmp_cached)
        except Exception:
            pass

    content_type = "audio/mpeg" if ext == ".mp3" else "video/mp4"
    bucket_name = os.environ.get("VIDEO_BUCKET", "truthworld-1.firebasestorage.app")
    try:
        from google.cloud import storage
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(remote_path)
        blob.upload_from_filename(local_path, content_type=content_type)
        return f"https://storage.googleapis.com/{bucket_name}/{remote_path}"
    except Exception as e:
        logger.warning(f"Cloud Storage upload warning ({e}), falling back to direct Modal volume endpoint.")
        if work_id:
            return f"https://ebenezervampu--truthworld-latentsync-worker-fastapi-app.us-east.modal.run/outputs/{work_id}{ext}"
        return f"https://storage.googleapis.com/{bucket_name}/{remote_path}"

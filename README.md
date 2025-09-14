This library is forked from [aadnk/whisper-webui](https://gitlab.com/aadnk/whisper-webui). I optimized the Docker image and added a one-click script whisper.sh that can be executed on Google Colab. The original documentation is here [**ORIGINAL DOCUMENT**](ORIGINAL_README.md).

# Using Whisper in Google Colab

### Step 1: Create Folder Structure in Google Drive

1. Navigate to your Google Drive root directory
2. Create a new folder named `whisper`
3. Inside the `whisper` folder, create a subfolder named `mp4`
4. Place your video or audio files that need subtitle recognition in the `mp4` folder
5. Save a shortcut to [this file](https://drive.google.com/file/d/1OmL5T1jlD7SPCNSa0bT2ulXV0j06NIU2/view?usp=sharing) in the `whisper` folder

**Final folder structure should look like this:**

```
├─ whisper/
   ├─ mp4/
   │  └─ video or audio files
   └─ whisperenv.img
```

### Step 2: Execute Commands in Google Colab

1. Open your Google Colab notebook
2. Switch to terminal mode
3. Run the following commands:

#### Usage Instructions:
```bash
curl -fsSL https://raw.githubusercontent.com/ericwang2006/whisper-webui/refs/heads/main/whisper.sh | bash -s -- --input <filename> [--engine whisper|faster-whisper] [--model medium] [--language Chinese]
```


#### Example Usage:
```bash
curl -fsSL https://raw.githubusercontent.com/ericwang2006/whisper-webui/refs/heads/main/whisper.sh | bash -s -- --input 054.mp4 --engine whisper --model medium --language Chinese
```

## Command Parameters

| Parameter | Options | Description |
|-----------|---------|-------------|
| `--input` | `<filename>` | **Required.** Name of the input file |
| `--engine` | `whisper` or `faster-whisper` | **Optional.** Choose the processing engine |
| `--model` | `medium` (or other model sizes) | **Optional.** Select the model size |
| `--language` | `Chinese` (or other languages) | **Optional.** Specify the source language |

## Additional Resources

**Video Tutorial**: https://www.126126.xyz/post/055/

---

**Note**: Make sure all your media files are properly uploaded to the `mp4` folder in your Google Drive before running the commands.

# Docker image usage

### Using Standard Whisper

1. Start WebUI with GPU Support

```bash
sudo docker run -d --gpus=all -p 7860:7860 ericwang2006/whisper-webui
```

2. CLI Usage

```bash
sudo docker run --rm \
--gpus=all \
-v ./.cache/whisper:/root/.cache/whisper \
-v ./.cache/huggingface:/root/.cache/huggingface \
-v ./:/app/data \
ericwang2006/whisper-webui \
python3 cli.py --model medium --auto_parallel True \
--vad silero-vad-skip-gaps \
--vad_max_merge_size 8.0 \
--vad_merge_window 1.0 \
--vad_padding 0.3 \
--language Chinese \
--fp16 True \
--output_dir /app/data /app/data/example.mp4
```

### Using Faster-Whisper

1. Start WebUI with GPU Support

```bash
sudo docker run -d --gpus=all -p 7860:7860 ericwang2006/whisper-webui:faster-whisper
```

2. CLI Usage

```bash
sudo docker run --rm \
--gpus=all \
-v ./.cache/whisper:/root/.cache/whisper \
-v ./.cache/huggingface:/root/.cache/huggingface \
-v ./:/app/data \
ericwang2006/whisper-webui:faster-whisper \
python3 cli.py --model large --auto_parallel True \
--vad silero-vad-skip-gaps \
--vad_max_merge_size 8.0 \
--vad_merge_window 1.0 \
--vad_padding 0.3 \
--language Chinese \
--whisper_implementation faster-whisper \
--compute_type float16 \
--output_dir /app/data /app/data/example.mp4
```

## Cache Directories

The following directories are used for caching:

- `/root/.cache/whisper` - Whisper model cache directory
- `/root/.cache/huggingface` - Faster-Whisper model cache directory

These directories are mounted as volumes to persist downloaded models between container runs.

## Additional Notes for Command Line Usage

- To run the CLI in CPU mode, remove the `--gpus=all` parameter from the command.
- The `--language` parameter can be used to specify the language of the audio input, which helps improve transcription accuracy.


## Key Parameter Explanations

1. **`--vad_max_merge_size`** – This is the most critical parameter
    - Setting it between `10.0-15.0` seconds limits the maximum length of a single subtitle segment.
    - If you want shorter subtitles, set it to `8.0` seconds or less.
2. **`--vad_merge_window`** – Controls merge logic
    - Setting it to `1.5-2.0` seconds helps reduce over-merging of adjacent voice segments.
    - Smaller values produce more but shorter subtitle segments.
3. **`--vad silero-vad-skip-gaps`** – Algorithm choice
    - This variant skips silent gaps compared to the basic `silero-vad`.
    - It helps split subtitles naturally at speech pauses.
4. **`--vad_padding`** – Fine-tunes segment boundaries
    - Setting it from `0.3-0.5` seconds adds a small padding around each segment.
    - Helps avoid cutting off the beginning or end of words.

## Adjusting Parameters Based on Content Type

- **Dialogue/Interview**: `--vad_max_merge_size 12.0 --vad_merge_window 2.0`
- **Speech/Lecture**: `--vad_max_merge_size 20.0 --vad_merge_window 3.0`
- **Fast Conversation**: `--vad_max_merge_size 8.0 --vad_merge_window 1.0`

## Features

- GPU acceleration support
- Voice Activity Detection (VAD) with configurable parameters
- Support for multiple languages
- Both standard Whisper and Faster-Whisper implementations
- Web UI and CLI interfaces
- Configurable model sizes and precision settings

# Pyannote Speaker Diarization Guide

⚠️ **Note:** The following steps have not been tested.

---

### 💰 Cost

* **Free** – Pyannote Speaker Diarization is open-source under the MIT License and can be used without payment.

---

### 🔑 How to Get a HuggingFace Access Token

#### 1. Create / Log in to a HuggingFace Account

* Visit [https://huggingface.co](https://huggingface.co)
* Sign up or log in to your account

#### 2. Request Model Access

* Go to [https://huggingface.co/pyannote/speaker-diarization](https://huggingface.co/pyannote/speaker-diarization)
* Click **"Accept conditions"** to agree to the terms of use
* Fill out the short user information form

#### 3. Create an Access Token

* Open account settings: [https://huggingface.co/settings/tokens](https://huggingface.co/settings/tokens)
* Click **"New token"**
* Choose the permission type:

  * **Read**: Recommended for model inference
  * **Write**: Read/write access
* Copy the generated token

#### 4. Use the Token

**Option 1: Environment Variable**

```bash
export HK_ACCESS_TOKEN="hf_xxxxxxxxxxxxxxxxxxxx"
```

**Option 2: Command Line Argument**

```bash
python cli.py --diarization True --auth_token "hf_xxxxxxxxxxxxxxxxxxxx"
```

---

### ⚠️ Notes

* Token format usually looks like: `hf_xxxxxxxxxxxxxxxxxxxx`
* It’s recommended to create a separate token for each application
* For production, use a **fine-grained token**
* Keep your token secret — **do not commit it to version control**

# 🎬 macOS Batch Video Converter

A local video conversion tool built specifically for macOS. This app provides a streamlined, drag-and-drop workflow for batch processing videos without the overhead of heavy media players.

## ✨ Key Features
*   **Drag & Drop UI:** Effortlessly queue multiple files for batch conversion.
*   **Optimized for Apple Silicon:** Built to leverage the power of **M1/M2/M3 chips**.
*   **Robust Background Processing:** Designed to run multiple conversions reliably in the background without crashing or slowing down your workflow. (VLC interrupts when opening another video during the conversion.)
*   **Superior Speed:** Performance-tuned to be faster and more stable than generic tools like VLC for dedicated conversion tasks.

## 🛠 Technical Overview
At its core, this application serves as a **FFmpeg wrapper**. 

*   **Language:** Swift
*   **Engine:** FFmpeg (optimized for ARM64/M-chips)
*   **Architecture:** Native macOS application

## 🧠 Project Backstory
This project is a testament to the power of **AI-assisted development**. Despite having no prior experience with Swift, I was able to build a functional, native macOS application by leveraging my background in Python and Data Science.

*   **Developer Background:** Python, Data Science, and Scientific Programming for lab experiments.
*   **Development Philosophy:** Using AI to bridge the gap between scientific logic and platform-specific app development.

---

## ⚙️ How to Use
1.  **Launch** the application.
2.  **Drag and drop** your video files or folders into the window.
3.  **Start Conversion:** The app will handle the batch processing in the background using optimized FFmpeg parameters.

---

## Interface

During processing you get an overview of how far the process came so far and how long it took.
<img width="895" height="573" alt="During_processing" src="https://github.com/user-attachments/assets/077d3147-7e1f-4b58-9f53-70e068d39da9" />

The .mov files are usually quite large. This is why I added the option to select output quality (without actually loosing too much visual quality). The response in the UI tells me how much space I have been able to compress the file when converting to mp4.
<img width="894" height="572" alt="Finished" src="https://github.com/user-attachments/assets/b5e39226-98c2-4d82-a238-d2acecee8adf" />

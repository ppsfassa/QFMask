import cv2
import numpy as np
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import threading
import os
from moviepy import VideoFileClip, AudioFileClip

class VideoProcessorGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("動画チャンネル加工ツール")
        self.root.geometry("500x250")

        self.input_path = tk.StringVar()
        self.output_path = tk.StringVar()

        tk.Label(root, text="入力動画:").pack(pady=(10, 0))
        entry_frame = tk.Frame(root)
        entry_frame.pack(fill="x", padx=20)
        tk.Entry(entry_frame, textvariable=self.input_path).pack(side="left", expand=True, fill="x")
        tk.Button(entry_frame, text="参照", command=self.select_file).pack(side="right")

        self.start_btn = tk.Button(root, text="処理開始", command=self.start_thread, bg="#4CAF50", fg="white", height=2)
        self.start_btn.pack(pady=20)

        self.progress = ttk.Progressbar(root, orient="horizontal", length=400, mode="determinate")
        self.progress.pack(pady=10)
        
        self.status_label = tk.Label(root, text="待機中")
        self.status_label.pack()

    def select_file(self):
        file_path = filedialog.askopenfilename(filetypes=[("Video files", "*.mp4 *.avi *.mov *.mkv")])
        if file_path:
            self.input_path.set(file_path)
            base, ext = os.path.splitext(file_path)
            self.output_path.set(f"{base}_q.mp4")

    def start_thread(self):
        if not self.input_path.get():
            messagebox.showwarning("警告", "動画ファイルを選択してください。")
            return
        self.start_btn.config(state="disabled")
        thread = threading.Thread(target=self.process_video)
        thread.daemon = True
        thread.start()

    def process_video(self):
        input_file = self.input_path.get()
        output_file = self.output_path.get()
        temp_video = "temp_no_audio.mp4" # 一時ファイル

        try:
            # 1. OpenCVで映像のみを加工
            cap = cv2.VideoCapture(input_file)
            fps = cap.get(cv2.CAP_PROP_FPS)
            width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
            
            fourcc = cv2.VideoWriter_fourcc(*'mp4v')
            out = cv2.VideoWriter(temp_video, fourcc, fps, (width, height))

            count = 0
            while cap.isOpened():
                ret, frame = cap.read()
                if not ret:
                    break
                
                # BGR分解
                b, g, r = cv2.split(frame)
                
                # 指定の加工 (R:上下反転, G:ネガ, B:左右反転)
                r_p = cv2.flip(cv2.bitwise_not(r), 0)
                g_p = cv2.bitwise_not(g)
                b_p = cv2.flip(cv2.bitwise_not(b), 1)
                
                # 結合 (OpenCV形式)
                res = cv2.merge((b_p, g_p, r_p))
                out.write(res)
                
                count += 1
                if count % 10 == 0:
                    percent = (count / total_frames) * 100
                    self.root.after(0, self.update_progress, percent, "映像加工中...")

            cap.release()
            out.release()

            # 2. MoviePyで音声のみ抽出し、映像と結合
            self.root.after(0, self.update_progress, 95, "音声結合中...")
            
            video_clip = VideoFileClip(temp_video)
            original_clip = VideoFileClip(input_file)
            
            if original_clip.audio is not None:
                final_clip = video_clip.with_audio(original_clip.audio)
                final_clip.write_videofile(output_file, codec="libx264", audio_codec="aac", logger=None)
                final_clip.close()
            else:
                # 音声がない場合はそのままリネーム
                video_clip.write_videofile(output_file, codec="libx264", logger=None)

            video_clip.close()
            original_clip.close()
            
            # 一時ファイルの削除
            if os.path.exists(temp_video):
                os.remove(temp_video)
                
            self.root.after(0, self.finish_process, output_file)
            
        except Exception as e:
            self.root.after(0, lambda: messagebox.showerror("エラー", f"エラーが発生しました:\n{e}"))
            self.root.after(0, lambda: self.start_btn.config(state="normal"))

    def update_progress(self, value, text):
        self.progress["value"] = value
        self.status_label.config(text=f"{text} {int(value)}%")

    def finish_process(self, output_file):
        self.progress["value"] = 100
        self.status_label.config(text="完了！")
        self.start_btn.config(state="normal")
        messagebox.showinfo("完了", f"保存が完了しました：\n{output_file}")

if __name__ == "__main__":
    root = tk.Tk()
    app = VideoProcessorGUI(root)
    root.mainloop()
import cv2
import numpy as np
import os
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from PIL import Image
import pillow_avif

def process_image(img_path, invert_alpha=False):
    try:
        with Image.open(img_path) as pil_img:
            # 1. 強制的にRGBA（4チャンネル）に変換
            img_rgba = pil_img.convert("RGBA")
            
            # 2. numpy配列に変換 (R, G, B, A)
            data = np.array(img_rgba)
            
            # 3. チャンネルを分離
            if data.shape[2] == 4:
                r, g, b, a = cv2.split(data)

                # Rチャンネルをネガポジ反転 + 上下反転
                r_processed = cv2.flip(cv2.bitwise_not(r), 0)

                # Gチャンネルをネガポジ反転
                g_processed = cv2.bitwise_not(g)
                
                # Bチャンネルをネガポジ反転 + 左右反転
                b_processed = cv2.flip(cv2.bitwise_not(b), 1)
                
                # --- アルファチャンネルの処理 ---
                a_processed = a
                if invert_alpha:
                    a_processed = cv2.bitwise_not(a)
                # ----------------------------
                
                # 4. 加工したチャンネルを再結合
                res_data = cv2.merge((r_processed, g_processed, b_processed, a_processed))
                res_pil = Image.fromarray(res_data, "RGBA")
                
                return res_pil, None
            else:
                return None, "RGBA変換に失敗しました"
            
    except Exception as e:
        return None, str(e)

class QFMaskBatchGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("QF-MASK")
        self.root.geometry("500x450") # 高さを少し調整

        self.dir_path = tk.StringVar(value="処理するフォルダを選択してください")
        tk.Label(root, textvariable=self.dir_path, fg="blue", wraplength=450).pack(pady=10)
        
        btn_select = tk.Button(root, text="フォルダを選択", command=self.select_dir)
        btn_select.pack(pady=5)

        # オプション設定用フレーム
        frame_options = tk.LabelFrame(root, text="処理オプション", padx=10, pady=10)
        frame_options.pack(pady=10, fill="x", padx=20)

        # 形式選択
        tk.Label(frame_options, text="デフォルトの出力形式 (JPG等の変換用):").pack(anchor="w")
        self.format_var = tk.StringVar(value="PNG")
        frame_format = tk.Frame(frame_options)
        frame_format.pack(anchor="w")
        tk.Radiobutton(frame_format, text="AVIF", variable=self.format_var, value="AVIF").pack(side="left")
        tk.Radiobutton(frame_format, text="PNG", variable=self.format_var, value="PNG").pack(side="left")

        # --- アルファ反転チェックボックスの追加 ---
        self.invert_alpha_var = tk.BooleanVar(value=False)
        self.chk_alpha = tk.Checkbutton(frame_options, text="アルファチャンネルをネガポジ反転する", variable=self.invert_alpha_var)
        self.chk_alpha.pack(anchor="w", pady=(10, 0))

        self.progress = ttk.Progressbar(root, orient="horizontal", length=400, mode="determinate")
        self.progress.pack(pady=15)

        self.btn_run = tk.Button(root, text="実行開始", bg="lightblue", width=20, command=self.run_batch)
        self.btn_run.pack(pady=10)

    def select_dir(self):
        directory = filedialog.askdirectory()
        if directory:
            self.dir_path.set(directory)

    def run_batch(self):
        input_dir = self.dir_path.get()
        if not os.path.isdir(input_dir):
            messagebox.showerror("Error", "有効なフォルダを選択してください。")
            return

        # チェックボックスの状態を取得
        do_invert_alpha = self.invert_alpha_var.get()

        output_dir = os.path.join(input_dir, "output")
        if not os.path.exists(output_dir):
            os.makedirs(output_dir)

        extensions = (".png", ".bmp", ".jpg", ".jpeg", ".webp", ".avif")
        files = [f for f in os.listdir(input_dir) if f.lower().endswith(extensions)]
        
        if not files:
            messagebox.showinfo("Info", "画像が見つかりませんでした。")
            return

        alpha_formats = [".png", ".webp", ".avif"]
        target_format = self.format_var.get().lower()

        self.btn_run.config(state="disabled")
        self.progress["maximum"] = len(files)
        
        success_count = 0
        for i, f in enumerate(files):
            img_path = os.path.join(input_dir, f)
            # アルファ反転フラグを渡す
            res_pil, err = process_image(img_path, invert_alpha=do_invert_alpha)
            
            if res_pil is not None:
                base_name, ext = os.path.splitext(f)
                ext = ext.lower()
                out_ext = ext if ext in alpha_formats else f".{target_format}"
                save_name = base_name + out_ext
                save_path = os.path.join(output_dir, save_name)

                try:
                    if out_ext == ".avif":
                        res_pil.save(save_path, "AVIF", quality=100, subsampling="4:4:4", speed=6)
                    else:
                        res_pil.save(save_path)
                    
                    success_count += 1
                except Exception as e:
                    print(f"Save Error ({f}): {e}")

            self.progress["value"] = i + 1
            self.root.update_idletasks()

        self.btn_run.config(state="normal")
        messagebox.showinfo("完了", f"成功: {success_count} 件\n保存先: {output_dir}")

if __name__ == "__main__":
    root = tk.Tk()
    app = QFMaskBatchGUI(root)
    root.mainloop()
"""Windows desktop interface for the private PS license issuer."""
import base64
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory
import tkinter as tk
from tkinter import filedialog, messagebox, simpledialog, ttk

from issue_license import DEFAULT_KEY, generate_key, issue, load_key, public_key


class LicenseManager:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.key_path = DEFAULT_KEY
        self.key = None
        self.device = tk.StringVar()
        self.days = tk.StringVar(value="7")
        self.public = tk.StringVar()
        self.status = tk.StringVar()

        root.title("PS License Manager")
        root.minsize(590, 365)
        style = ttk.Style(root)
        style.configure("Title.TLabel", font=("Segoe UI", 20, "bold"))
        style.configure("TButton", padding=7)

        frame = ttk.Frame(root, padding=24)
        frame.pack(fill="both", expand=True)
        frame.columnconfigure(0, weight=1)
        ttk.Label(frame, text="إدارة تراخيص PS Management", style="Title.TLabel").grid(
            row=0, column=0, columnspan=2, sticky="e", pady=(0, 8),
        )
        ttk.Label(frame, text="جهّز مفتاح الإصدار مرة واحدة، وبعدها أصدر ملف لكل عميل.").grid(
            row=1, column=0, columnspan=2, sticky="e", pady=(0, 14),
        )

        self._field(frame, 2, "معرّف الجهاز", self.device)
        self._field(frame, 3, "عدد الأيام", self.days)
        self._field(frame, 4, "المفتاح العام للبناء", self.public, readonly=True)

        buttons = ttk.Frame(frame)
        buttons.grid(row=5, column=0, columnspan=2, sticky="ew", pady=(14, 10))
        ttk.Button(buttons, text="فتح أو إنشاء مفتاح الإصدار", command=self.unlock).pack(side="right", padx=4)
        ttk.Button(buttons, text="نسخ المفتاح العام", command=self.copy_public).pack(side="right", padx=4)
        ttk.Button(buttons, text="حفظ ملف الترخيص", command=self.save).pack(side="right", padx=4)

        ttk.Label(frame, textvariable=self.status, wraplength=540, justify="right").grid(
            row=6, column=0, columnspan=2, sticky="e",
        )
        self.status.set("مفتاح الإصدار محفوظ على جهازك في مجلد .ps-desktop-licensing داخل حساب ويندوز.")

    def _field(self, frame, row, label, variable, readonly=False):
        ttk.Label(frame, text=label).grid(row=row, column=1, sticky="e", padx=(12, 0), pady=5)
        entry = ttk.Entry(frame, textvariable=variable, state="readonly" if readonly else "normal")
        entry.grid(row=row, column=0, sticky="ew", pady=5)

    def unlock(self):
        if self.key is not None:
            return True
        create = not self.key_path.exists()
        prompt = "اختار كلمة سر للمفتاح (١٢ حرف على الأقل)" if create else "اكتب كلمة سر مفتاح الإصدار"
        password = simpledialog.askstring("مفتاح الإصدار", prompt, show="*", parent=self.root)
        if password is None:
            return False
        if create:
            again = simpledialog.askstring("تأكيد كلمة السر", "اكتب كلمة السر مرة تانية", show="*", parent=self.root)
            if again is None:
                return False
            if again != password or len(password) < 12:
                messagebox.showerror("مفتاح الإصدار", "كلمة السر لازم تتكرر زي ما هي وتكون ١٢ حرف على الأقل.", parent=self.root)
                return False
        try:
            if create:
                generate_key(self.key_path, password)
            self.key = load_key(self.key_path, password)
            self.public.set(public_key(self.key))
            self.status.set("المفتاح جاهز. استخدم المفتاح العام ده عند بناء نسخة العميل.")
            return True
        except (OSError, ValueError, TypeError):
            messagebox.showerror("مفتاح الإصدار", "تعذر فتح أو حفظ المفتاح. راجع كلمة السر ومجلد الحفظ.", parent=self.root)
            return False

    def copy_public(self):
        if self.unlock():
            self.root.clipboard_clear()
            self.root.clipboard_append(self.public.get())
            self.status.set("تم نسخ المفتاح العام.")

    def save(self):
        device = self.device.get().strip().upper()
        try:
            days = int(self.days.get().strip())
            if not 1 <= days <= 3650:
                raise ValueError()
        except ValueError:
            messagebox.showerror("مدة الترخيص", "اكتب عدد أيام صحيح من ١ إلى ٣٦٥٠.", parent=self.root)
            return
        if len(device) != 32 or any(c not in "0123456789ABCDEF" for c in device):
            messagebox.showerror("معرّف الجهاز", "انسخ معرّف الجهاز بالكامل من شاشة التفعيل.", parent=self.root)
            return
        if not self.unlock():
            return
        path = filedialog.asksaveasfilename(
            parent=self.root,
            title="حفظ ملف الترخيص",
            defaultextension=".pslicense",
            initialfile=f"PS-{device[:8]}-{days}days.pslicense",
            filetypes=[("PS License", "*.pslicense")],
        )
        if not path:
            return
        try:
            token = issue(self.key, device, days, datetime.now(timezone.utc))
            Path(path).write_text(token + "\n", encoding="utf-8")
            self.status.set(f"تم حفظ الترخيص: {Path(path).name}")
            messagebox.showinfo("الترخيص جاهز", "ابعت ملف الترخيص فقط للعميل عشان يفتحه من شاشة التفعيل.", parent=self.root)
        except (OSError, ValueError):
            messagebox.showerror("ملف الترخيص", "تعذر حفظ الملف. اختار مجلد تاني وحاول مرة أخرى.", parent=self.root)


def self_test():
    with TemporaryDirectory() as directory:
        path = Path(directory) / "key.pem"
        password = "Temporary build test"
        expected = generate_key(path, password)
        key = load_key(path, password)
        if public_key(key) != expected:
            raise RuntimeError("Issuer public key mismatch")
        token = issue(key, "A" * 32, 7, datetime.now(timezone.utc))
        license_file = Path(directory) / "test.pslicense"
        license_file.write_text(token + "\n", encoding="utf-8")
        prefix, body, signature = license_file.read_text(encoding="utf-8").strip().split(".")
        decode = lambda value: base64.urlsafe_b64decode(value + "=" * (-len(value) % 4))
        key.public_key().verify(decode(signature), f"{prefix}.{body}".encode("ascii"))
        claims = json.loads(decode(body))
        if claims["exp"] - claims["iat"] != 604800:
            raise RuntimeError("Incorrect license duration")


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        self_test()
    else:
        window = tk.Tk()
        LicenseManager(window)
        window.mainloop()

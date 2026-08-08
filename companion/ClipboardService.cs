using System.Runtime.InteropServices;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Small defensive wrapper over the Win32 clipboard. The companion already is a
    /// Windows-only process (Tolk and NVDA are native Windows dependencies), so using
    /// the platform API avoids adding WinForms solely for Clipboard.SetText.
    /// </summary>
    internal static class ClipboardService
    {
        private const uint CfUnicodeText = 13;
        private const uint GmemMoveable = 0x0002;
        private const uint GmemZeroInit = 0x0040;

        internal static bool TrySetText(string text)
        {
            if (string.IsNullOrEmpty(text)) return false;

            try
            {
                // Another desktop process may own the clipboard for a few milliseconds.
                // A short bounded retry prevents that ordinary contention from making the
                // seed-copy action flaky while keeping the log-tail thread responsive.
                for (int attempt = 0; attempt < 10; attempt++)
                {
                    if (OpenClipboard(IntPtr.Zero))
                    {
                        try { return TrySetTextWhileOpen(text); }
                        finally { CloseClipboard(); }
                    }

                    Thread.Sleep(10);
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"[Clipboard] Could not copy text: {e.Message}");
            }

            return false;
        }

        private static bool TrySetTextWhileOpen(string text)
        {
            UIntPtr byteCount = (UIntPtr)((text.Length + 1) * sizeof(char));
            IntPtr memory = GlobalAlloc(GmemMoveable | GmemZeroInit, byteCount);
            if (memory == IntPtr.Zero) return false;

            bool clipboardOwnsMemory = false;
            IntPtr destination = IntPtr.Zero;
            try
            {
                destination = GlobalLock(memory);
                if (destination == IntPtr.Zero) return false;

                char[] characters = text.ToCharArray();
                Marshal.Copy(characters, 0, destination, characters.Length);
                Marshal.WriteInt16(destination, characters.Length * sizeof(char), 0);
                GlobalUnlock(memory);
                destination = IntPtr.Zero;

                // Empty only after the replacement text is fully allocated. A memory
                // or marshaling failure must leave the user's previous clipboard intact.
                if (!EmptyClipboard()) return false;
                if (SetClipboardData(CfUnicodeText, memory) == IntPtr.Zero) return false;
                clipboardOwnsMemory = true;
                return true;
            }
            finally
            {
                if (destination != IntPtr.Zero) GlobalUnlock(memory);
                // SetClipboardData transfers ownership to Windows only on success.
                if (!clipboardOwnsMemory) GlobalFree(memory);
            }
        }

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool OpenClipboard(IntPtr newOwner);

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseClipboard();

        [DllImport("user32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool EmptyClipboard();

        [DllImport("user32.dll", SetLastError = true)]
        private static extern IntPtr SetClipboardData(uint format, IntPtr memory);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GlobalAlloc(uint flags, UIntPtr bytes);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GlobalLock(IntPtr memory);

        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GlobalUnlock(IntPtr memory);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern IntPtr GlobalFree(IntPtr memory);
    }
}

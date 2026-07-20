using System;
using System.Runtime.InteropServices;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// P/Invoke bindings for Tolk (https://github.com/dkager/tolk), the screen-reader
    /// abstraction layer. Tolk.dll and nvdaControllerClient64.dll are copied next to
    /// the built exe (see the .csproj), which is the process working directory, so
    /// the loader resolves them by plain name.
    /// </summary>
    internal static class Tolk
    {
        private const string Dll = "Tolk.dll";

        [DllImport(Dll, EntryPoint = "Tolk_Load")]
        internal static extern void Load();

        [DllImport(Dll, EntryPoint = "Tolk_Unload")]
        internal static extern void Unload();

        [DllImport(Dll, EntryPoint = "Tolk_IsLoaded")]
        [return: MarshalAs(UnmanagedType.I1)]
        internal static extern bool IsLoaded();

        [DllImport(Dll, EntryPoint = "Tolk_Output", CharSet = CharSet.Unicode)]
        [return: MarshalAs(UnmanagedType.I1)]
        internal static extern bool Output(
            [MarshalAs(UnmanagedType.LPWStr)] string str,
            [MarshalAs(UnmanagedType.I1)] bool interrupt);

        [DllImport(Dll, EntryPoint = "Tolk_Silence")]
        [return: MarshalAs(UnmanagedType.I1)]
        internal static extern bool Silence();

        // Stock Tolk keeps its SAPI driver disabled until explicitly requested;
        // opting in lets SAPI act as the lowest-priority fallback when no screen
        // reader is running. Call before Load so the initial detection sees it.
        [DllImport(Dll, EntryPoint = "Tolk_TrySAPI")]
        internal static extern void TrySAPI([MarshalAs(UnmanagedType.I1)] bool trySAPI);

        [DllImport(Dll, EntryPoint = "Tolk_HasSpeech")]
        [return: MarshalAs(UnmanagedType.I1)]
        internal static extern bool HasSpeech();

        // Returns a pointer to memory OWNED BY TOLK. It must be read with
        // Marshal.PtrToStringUni, never marshaled as string: declaring the return
        // as LPWStr makes the CLR free the pointer (CoTaskMemFree), corrupting the
        // native heap and killing the process with no managed exception.
        [DllImport(Dll, EntryPoint = "Tolk_DetectScreenReader")]
        private static extern IntPtr Tolk_DetectScreenReader();

        internal static string? DetectScreenReader()
        {
            IntPtr ptr = Tolk_DetectScreenReader();
            return ptr == IntPtr.Zero ? null : Marshal.PtrToStringUni(ptr);
        }
    }
}

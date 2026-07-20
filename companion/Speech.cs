using System;
using System.Diagnostics;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Thin, defensive wrapper over <see cref="Tolk"/>. Every caller goes through
    /// here so that a missing screen reader or a Tolk load failure can never crash
    /// the companion process — it just degrades to silence.
    /// </summary>
    internal static class Speech
    {
        private static bool _ready;
        private static readonly Stopwatch Clock = Stopwatch.StartNew();

        // Suppress immediate duplicate announcements within a short window (e.g.
        // the same event reported by two independent hooks in the same frame).
        private static string? _last;
        private static double _lastSeconds;
        private const double DedupeSeconds = 0.15;

        internal static void Init()
        {
            try
            {
                // Without this, stock Tolk never considers SAPI and a machine with
                // no screen reader running is silent despite having voices installed.
                Tolk.TrySAPI(true);
                Tolk.Load();
                _ready = true;

                string? reader;
                try { reader = Tolk.DetectScreenReader(); }
                catch { reader = null; }
                bool hasSpeech;
                try { hasSpeech = Tolk.HasSpeech(); }
                catch { hasSpeech = false; }

                if (reader != null)
                    Console.WriteLine($"[Speech] Tolk loaded. Speech driver: {reader}");
                else if (hasSpeech)
                    Console.WriteLine("[Speech] Tolk loaded. No screen reader detected; using an unnamed speech driver.");
                else
                    Console.WriteLine("[Speech] Tolk loaded, but no screen reader or SAPI voice was found; speech will be silent.");
            }
            catch (Exception e)
            {
                _ready = false;
                Console.WriteLine($"[Speech] Could not load Tolk.dll; speech disabled. {e.Message}");
            }
        }

        internal static void Shutdown()
        {
            if (!_ready) return;
            try { Tolk.Unload(); } catch { /* ignore */ }
            _ready = false;
        }

        /// <summary>Speak <paramref name="text"/>. When interrupt is true, cut off
        /// whatever is currently being spoken (used for fast cursor navigation).</summary>
        internal static void Speak(string text, bool interrupt = true)
        {
            if (!_ready) return;
            if (string.IsNullOrEmpty(text)) return;

            // TextCleaner is defensive itself, but keep the original here too so
            // that even a future regression in cleanup can never silence speech.
            string original = text;
            try { text = TextCleaner.Clean(text); }
            catch { text = original; }

            text = text.Trim();
            if (text.Length == 0) return;

            double now = Clock.Elapsed.TotalSeconds;
            if (text == _last && (now - _lastSeconds) < DedupeSeconds) return;
            _last = text;
            _lastSeconds = now;

            try { Tolk.Output(text, interrupt); }
            catch (Exception e) { Console.WriteLine($"[Speech] Tolk output failed: {e.Message}"); }
        }
    }
}

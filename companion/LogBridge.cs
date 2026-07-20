using System.Text.Json;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Bridge plan B (docs/arquitectura-propuesta-y-roadmap.md, tarea 0.4): the
    /// game's own log.html is a live-appended HTML debug log shared with the
    /// engine and every other mod. We tail it and pick out only the lines we
    /// ourselves wrote via ::logInfo, marked with <see cref="Marker"/>, then
    /// speak them. If tarea 0.4 settles on a live WebSocket/XHR bridge instead,
    /// this is the only file that changes — Speech and the message shape stay.
    /// </summary>
    internal static class LogBridge
    {
        private const string Marker = "UB_MSG:";
        private const string EntryEnd = "</div>";

        // How often we re-check the file for growth. Not yet in a config file
        // (see L10n's own TODO — roadmap 5.1 introduces one); revisit then.
        private const int PollMilliseconds = 100;

        internal static void Watch(string path, CancellationToken token)
        {
            new Thread(() => Run(path, token)) { IsBackground = true }.Start();
        }

        private static void Run(string path, CancellationToken token)
        {
            long position = 0;
            try
            {
                if (File.Exists(path))
                {
                    using var initial = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                    // Start at end-of-file: we only want events from now on, not
                    // the whole session's history replayed on companion startup.
                    position = initial.Length;
                }
            }
            catch (Exception e)
            {
                Console.WriteLine($"[LogBridge] Could not open {path}: {e.Message}");
                return;
            }

            while (!token.IsCancellationRequested)
            {
                try
                {
                    using var fs = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
                    if (fs.Length < position)
                    {
                        // The game truncates and rewrites log.html on every launch.
                        // Restart from the top of the new file — its early content is
                        // engine startup noise with no UB_MSG lines, so no replay risk.
                        position = 0;
                    }
                    if (fs.Length > position)
                    {
                        fs.Seek(position, SeekOrigin.Begin);
                        using var reader = new StreamReader(fs);
                        string chunk = reader.ReadToEnd();
                        position = fs.Length;
                        ProcessChunk(chunk);
                    }
                }
                catch (IOException)
                {
                    // The game holds this file open and writes to it continuously;
                    // an occasional lock conflict is expected. Retry next tick.
                }
                catch (Exception e)
                {
                    Console.WriteLine($"[LogBridge] Tail error: {e.Message}");
                }

                Thread.Sleep(PollMilliseconds);
            }
        }

        private static void ProcessChunk(string chunk)
        {
            int searchFrom = 0;
            while (true)
            {
                int markerIndex = chunk.IndexOf(Marker, searchFrom, StringComparison.Ordinal);
                if (markerIndex < 0) break;

                int jsonStart = markerIndex + Marker.Length;
                int jsonEnd = chunk.IndexOf(EntryEnd, jsonStart, StringComparison.Ordinal);
                if (jsonEnd < 0) break; // entry not fully written yet; pick it up next poll

                string json = chunk.Substring(jsonStart, jsonEnd - jsonStart);
                searchFrom = jsonEnd + EntryEnd.Length;

                HandleMessage(json);
            }
        }

        private static void HandleMessage(string json)
        {
            try
            {
                // The game writes log.html as HTML, so it may entity-escape the
                // quotes in our JSON payload; undo that before parsing.
                json = System.Net.WebUtility.HtmlDecode(json);
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                string canal = root.GetProperty("canal").GetString() ?? "interrupt";
                string texto = root.GetProperty("texto").GetString() ?? "";
                Speech.Speak(texto, interrupt: canal == "interrupt");
            }
            catch (Exception e)
            {
                Console.WriteLine($"[LogBridge] Malformed message ignored: {json} ({e.Message})");
            }
        }
    }
}

using System.Runtime.InteropServices;
using System.Text.Json;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Immediate positional cue for the unit under the tactical tile cursor.
    /// Squirrel supplies only semantics (ally/enemy, live turn bucket and the
    /// horizontal/vertical offset); this class owns every audible decision.
    ///
    /// The waveform is rendered at its final frequency instead of replaying a WAV
    /// faster or slower. Transposing the cue up/down therefore never
    /// changes the requested 250/400/600 ms rhythm. Like cursor speech, playback is
    /// last-focus-wins: a new tile stops the old cue before starting.
    /// </summary>
    internal static class CombatSonar
    {
        private const int SampleRate = 48_000;
        private const short ChannelCount = 2;
        private const short BitsPerSample = 16;

        private const uint SoundAsync = 0x0001;
        private const uint SoundNoDefault = 0x0002;
        private const uint SoundMemory = 0x0004;

        private static readonly object Sync = new();
        private static readonly Dictionary<SoundKey, byte[]> Cache = new();

        private static SonarSettings _settings = new();
        private static bool _ready;
        private static bool _failureReported;
        private static GCHandle _currentWave;
        private static bool _currentWavePinned;

        [DllImport("winmm.dll", EntryPoint = "PlaySoundW", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool PlaySound(IntPtr sound, IntPtr module, uint flags);

        internal static void Init(string configPath)
        {
            lock (Sync)
            {
                StopCore();
                Cache.Clear();
                _failureReported = false;
                _settings = SonarSettings.Load(configPath);
                _ready = OperatingSystem.IsWindows() && _settings.Enabled;

                if (!_settings.Enabled)
                {
                    Console.WriteLine("[CombatSonar] Disabled in sonar.json.");
                }
                else if (!_ready)
                {
                    Console.WriteLine("[CombatSonar] Positional audio requires Windows; sonar disabled.");
                }
                else
                {
                    Console.WriteLine(
                        $"[CombatSonar] Ready. Volume {_settings.Volume:0.##}, " +
                        $"pan {_settings.PanPerHorizontalTile:0.##} per column, " +
                        $"vertical shift {_settings.PitchSemitonesPerVerticalTile:0.##} " +
                        "semitones per tile.");
                }
            }
        }

        internal static void Shutdown()
        {
            lock (Sync)
            {
                StopCore();
                Cache.Clear();
                _ready = false;
            }
        }

        /// <param name="relation"><c>ally</c> or <c>enemy</c>.</param>
        /// <param name="timing"><c>1</c>, <c>2</c>, <c>3</c>, <c>many</c> or <c>done</c>.</param>
        /// <param name="positionText">
        /// Signed horizontal and vertical tile counts as <c>x|y</c>.
        /// Positive values mean right/up; negative values mean left/down.
        /// </param>
        internal static void Play(string relation, string timing, string positionText)
        {
            string[] position = positionText.Split('|');
            if ((relation != "ally" && relation != "enemy")
                || !IsKnownTiming(timing)
                || position.Length != 2
                || !int.TryParse(position[0], out int horizontalTiles)
                || !int.TryParse(position[1], out int verticalTiles)
                || horizontalTiles is < -128 or > 128
                || verticalTiles is < -128 or > 128)
            {
                return;
            }

            lock (Sync)
            {
                if (!_ready) return;

                try
                {
                    var key = new SoundKey(
                        relation, timing, horizontalTiles, verticalTiles);
                    if (!Cache.TryGetValue(key, out byte[]? wave))
                    {
                        // Positions are data-dependent, so keep the otherwise useful
                        // waveform cache bounded during long battles.
                        if (Cache.Count >= 256) Cache.Clear();
                        wave = RenderWave(key);
                        Cache[key] = wave;
                    }

                    // Cursor audio is an interrupt channel: never leave a long cue
                    // describing the unit which lost focus one keystroke ago.
                    StopCore();
                    _currentWave = GCHandle.Alloc(wave, GCHandleType.Pinned);
                    _currentWavePinned = true;

                    if (!PlaySound(_currentWave.AddrOfPinnedObject(), IntPtr.Zero,
                            SoundAsync | SoundMemory | SoundNoDefault))
                    {
                        int error = Marshal.GetLastWin32Error();
                        StopCore();
                        Disable($"PlaySound failed with Win32 error {error}.");
                    }
                }
                catch (Exception e)
                {
                    StopCore();
                    Disable(e.Message);
                }
            }
        }

        private static bool IsKnownTiming(string timing)
        {
            return timing is "1" or "2" or "3" or "many" or "done";
        }

        private static void StopCore()
        {
            try
            {
                if (OperatingSystem.IsWindows()) PlaySound(IntPtr.Zero, IntPtr.Zero, 0);
            }
            catch
            {
                // Audio is optional. Free our own memory even if winmm is unavailable.
            }

            if (_currentWavePinned)
            {
                try { _currentWave.Free(); } catch { /* already harmlessly gone */ }
                _currentWavePinned = false;
            }
        }

        private static void Disable(string reason)
        {
            _ready = false;
            if (_failureReported) return;
            _failureReported = true;
            Console.WriteLine($"[CombatSonar] Audio failed; sonar disabled. {reason}");
        }

        private static byte[] RenderWave(SoundKey key)
        {
            bool friendly = key.Relation == "ally";
            int[] chordMidi = friendly
                ? _settings.FriendlyChordMidi
                : _settings.ThreateningChordMidi;
            int[] doneMidi = friendly
                ? _settings.FriendlyDoneMidi
                : _settings.ThreateningDoneMidi;

            (double pitch, double pan) = SpatialParameters(
                key.HorizontalTiles, key.VerticalTiles);
            List<ToneEvent> events = BuildEvents(key.Timing, chordMidi, doneMidi, pitch);
            int totalSamples = events.Count == 0
                ? 1
                : events.Max(e => e.EndSample);
            var mono = new double[totalSamples];

            foreach (ToneEvent toneEvent in events)
            {
                RenderEvent(mono, toneEvent);
            }

            // Equal-power stereo panning: centre is -3 dB in each ear, while total
            // power remains stable as the cue moves left or right.
            double angle = (pan + 1.0) * Math.PI / 4.0;
            double leftGain = Math.Cos(angle);
            double rightGain = Math.Sin(angle);
            return MakePcmWave(mono, leftGain, rightGain, _settings.Volume);
        }

        private static (double pitch, double pan) SpatialParameters(
            int horizontalTiles, int verticalTiles)
        {
            double semitones = _settings.PitchSemitonesPerVerticalTile * verticalTiles;
            double pitch = Math.Pow(2.0, semitones / 12.0);
            double pan = Math.Clamp(
                horizontalTiles * _settings.PanPerHorizontalTile, -1.0, 1.0);
            return (pitch, pan);
        }

        private static List<ToneEvent> BuildEvents(
            string timing, int[] chordMidi, int[] doneMidi, double pitch)
        {
            var events = new List<ToneEvent>();
            if (timing == "done")
            {
                int startMs = 0;
                foreach (int midi in doneMidi)
                {
                    AddEvent(events, startMs, _settings.DoneNoteMilliseconds,
                        new[] { MidiToFrequency(midi) * pitch });
                    startMs += _settings.DoneNoteMilliseconds + _settings.DoneGapMilliseconds;
                }
                return events;
            }

            double[] chord = chordMidi
                .Select(midi => MidiToFrequency(midi) * pitch)
                .ToArray();

            switch (timing)
            {
                case "1":
                    AddEvent(events, 0, _settings.OneTurnPulseMilliseconds, chord);
                    break;
                case "2":
                    AddRepeatedEvents(events, 2, _settings.TwoTurnPulseMilliseconds,
                        _settings.TwoTurnGapMilliseconds, chord);
                    break;
                case "3":
                    AddRepeatedEvents(events, 3, _settings.ThreeTurnPulseMilliseconds,
                        _settings.ThreeTurnGapMilliseconds, chord);
                    break;
                case "many":
                    AddEvent(events, 0, _settings.ManyTurnsPulseMilliseconds, chord);
                    break;
            }

            return events;
        }

        private static void AddRepeatedEvents(
            List<ToneEvent> events, int count, int pulseMs, int gapMs, double[] frequencies)
        {
            int startMs = 0;
            for (int i = 0; i < count; i++)
            {
                AddEvent(events, startMs, pulseMs, frequencies);
                startMs += pulseMs + gapMs;
            }
        }

        private static void AddEvent(
            List<ToneEvent> events, int startMs, int durationMs, double[] frequencies)
        {
            int start = MillisecondsToSamples(startMs);
            int length = Math.Max(1, MillisecondsToSamples(durationMs));
            events.Add(new ToneEvent(start, length, frequencies));
        }

        private static int MillisecondsToSamples(int milliseconds)
        {
            return (int)Math.Round(milliseconds * SampleRate / 1000.0);
        }

        private static void RenderEvent(double[] mono, ToneEvent toneEvent)
        {
            int attack = Math.Min(
                MillisecondsToSamples(_settings.AttackMilliseconds), toneEvent.Length / 2);
            int release = Math.Min(
                MillisecondsToSamples(_settings.ReleaseMilliseconds), toneEvent.Length / 2);

            for (int local = 0; local < toneEvent.Length; local++)
            {
                double envelope = 1.0;
                if (attack > 0 && local < attack)
                    envelope *= (local + 1.0) / attack;
                if (release > 0 && local >= toneEvent.Length - release)
                    envelope *= (toneEvent.Length - local) / (double)release;

                double sample = 0.0;
                foreach (double frequency in toneEvent.Frequencies)
                {
                    double phase = local * frequency / SampleRate;
                    double fraction = phase - Math.Floor(phase);
                    sample += 1.0 - 4.0 * Math.Abs(fraction - 0.5); // triangle
                }

                sample /= toneEvent.Frequencies.Length;
                mono[toneEvent.StartSample + local] += sample * envelope;
            }
        }

        private static byte[] MakePcmWave(
            double[] mono, double leftGain, double rightGain, double volume)
        {
            int bytesPerSample = BitsPerSample / 8;
            int blockAlign = ChannelCount * bytesPerSample;
            int dataLength = mono.Length * blockAlign;

            using var stream = new MemoryStream(44 + dataLength);
            using var writer = new BinaryWriter(stream);
            WriteFourCc(writer, "RIFF");
            writer.Write(36 + dataLength);
            WriteFourCc(writer, "WAVE");
            WriteFourCc(writer, "fmt ");
            writer.Write(16);
            writer.Write((short)1); // PCM
            writer.Write(ChannelCount);
            writer.Write(SampleRate);
            writer.Write(SampleRate * blockAlign);
            writer.Write((short)blockAlign);
            writer.Write(BitsPerSample);
            WriteFourCc(writer, "data");
            writer.Write(dataLength);

            foreach (double sample in mono)
            {
                writer.Write(ToPcm16(sample * leftGain * volume));
                writer.Write(ToPcm16(sample * rightGain * volume));
            }

            writer.Flush();
            return stream.ToArray();
        }

        private static short ToPcm16(double sample)
        {
            sample = Math.Clamp(sample, -1.0, 1.0);
            return (short)Math.Round(sample * short.MaxValue);
        }

        private static void WriteFourCc(BinaryWriter writer, string value)
        {
            foreach (char character in value) writer.Write((byte)character);
        }

        private static double MidiToFrequency(int midi)
        {
            return 440.0 * Math.Pow(2.0, (midi - 69) / 12.0);
        }

        private readonly record struct SoundKey(
            string Relation, string Timing, int HorizontalTiles, int VerticalTiles);

        private sealed class ToneEvent
        {
            internal ToneEvent(int startSample, int length, double[] frequencies)
            {
                StartSample = startSample;
                Length = length;
                Frequencies = frequencies;
            }

            internal int StartSample { get; }
            internal int Length { get; }
            internal int EndSample => StartSample + Length;
            internal double[] Frequencies { get; }
        }

        private sealed class SonarSettings
        {
            internal const string FileName = "sonar.json";

            public bool Enabled { get; set; } = true;
            public double Volume { get; set; } = 0.55;
            public double PanPerHorizontalTile { get; set; } = 0.10;
            public double PitchSemitonesPerVerticalTile { get; set; } = 3.0;
            public int AttackMilliseconds { get; set; } = 8;
            public int ReleaseMilliseconds { get; set; } = 12;

            public int OneTurnPulseMilliseconds { get; set; } = 250;
            public int TwoTurnPulseMilliseconds { get; set; } = 150;
            public int TwoTurnGapMilliseconds { get; set; } = 100;
            public int ThreeTurnPulseMilliseconds { get; set; } = 140;
            public int ThreeTurnGapMilliseconds { get; set; } = 90;
            public int ManyTurnsPulseMilliseconds { get; set; } = 400;
            public int DoneNoteMilliseconds { get; set; } = 120;
            public int DoneGapMilliseconds { get; set; } = 40;

            // MIDI notes make octave choice explicit while keeping the requested
            // note names editable: G3+D4, Bb3+C#4, D4-G4-D4-G4 and
            // C#4-Bb3-C#4-Bb3.
            public int[] FriendlyChordMidi { get; set; } = new[] { 55, 62 };
            public int[] ThreateningChordMidi { get; set; } = new[] { 58, 61 };
            public int[] FriendlyDoneMidi { get; set; } = new[] { 62, 67, 62, 67 };
            public int[] ThreateningDoneMidi { get; set; } = new[] { 61, 58, 61, 58 };

            internal static SonarSettings Load(string path)
            {
                var defaults = new SonarSettings();
                try
                {
                    if (!File.Exists(path))
                    {
                        Console.WriteLine(
                            $"[CombatSonar] Config not found at '{path}'; using defaults.");
                        defaults.Normalize();
                        return defaults;
                    }

                    var options = new JsonSerializerOptions
                    {
                        PropertyNameCaseInsensitive = true,
                        ReadCommentHandling = JsonCommentHandling.Skip,
                        AllowTrailingCommas = true,
                    };
                    SonarSettings loaded = JsonSerializer.Deserialize<SonarSettings>(
                        File.ReadAllText(path), options) ?? defaults;
                    loaded.Normalize();
                    return loaded;
                }
                catch (Exception e)
                {
                    Console.WriteLine(
                        $"[CombatSonar] Could not read '{path}'; using defaults. {e.Message}");
                    defaults.Normalize();
                    return defaults;
                }
            }

            private void Normalize()
            {
                Volume = Math.Clamp(Volume, 0.0, 1.0);
                PanPerHorizontalTile = Math.Clamp(PanPerHorizontalTile, 0.0, 1.0);
                PitchSemitonesPerVerticalTile = Math.Clamp(
                    PitchSemitonesPerVerticalTile, 0.0, 12.0);
                AttackMilliseconds = ClampTime(AttackMilliseconds, 0, 100);
                ReleaseMilliseconds = ClampTime(ReleaseMilliseconds, 0, 100);
                OneTurnPulseMilliseconds = ClampTime(OneTurnPulseMilliseconds, 20, 2_000);
                TwoTurnPulseMilliseconds = ClampTime(TwoTurnPulseMilliseconds, 20, 2_000);
                TwoTurnGapMilliseconds = ClampTime(TwoTurnGapMilliseconds, 0, 1_000);
                ThreeTurnPulseMilliseconds = ClampTime(ThreeTurnPulseMilliseconds, 20, 2_000);
                ThreeTurnGapMilliseconds = ClampTime(ThreeTurnGapMilliseconds, 0, 1_000);
                ManyTurnsPulseMilliseconds = ClampTime(ManyTurnsPulseMilliseconds, 20, 2_000);
                DoneNoteMilliseconds = ClampTime(DoneNoteMilliseconds, 20, 2_000);
                DoneGapMilliseconds = ClampTime(DoneGapMilliseconds, 0, 1_000);

                FriendlyChordMidi = NormalizeNotes(FriendlyChordMidi, new[] { 55, 62 }, 2);
                ThreateningChordMidi = NormalizeNotes(ThreateningChordMidi, new[] { 58, 61 }, 2);
                FriendlyDoneMidi = NormalizeNotes(FriendlyDoneMidi, new[] { 62, 67, 62, 67 }, 4);
                ThreateningDoneMidi = NormalizeNotes(ThreateningDoneMidi, new[] { 61, 58, 61, 58 }, 4);
            }

            private static int ClampTime(int value, int minimum, int maximum)
            {
                return Math.Clamp(value, minimum, maximum);
            }

            private static int[] NormalizeNotes(int[]? notes, int[] fallback, int expected)
            {
                if (notes == null || notes.Length != expected
                    || notes.Any(note => note is < 0 or > 127))
                {
                    return fallback;
                }
                return notes;
            }
        }
    }
}

using System.Runtime.InteropServices;
using System.Text.Json;

namespace TheUnseenBanner.Companion
{
    /// <summary>
    /// Immediate positional cue for the tile under the tactical cursor.
    /// Squirrel supplies only semantics (ally/enemy, live turn bucket, the
    /// horizontal/vertical offset and whether the ground rises or falls); this
    /// class owns every audible decision.
    ///
    /// The waveform is rendered at its final frequency instead of replaying a WAV
    /// faster or slower. Transposing the cue up/down therefore never
    /// changes the requested 250/400/600 ms rhythm. Like cursor speech, playback is
    /// last-focus-wins: a new tile stops the old cue before starting.
    ///
    /// A tile can report two facts at once — a unit standing on it and the height of
    /// the ground under it. PlaySound plays exactly one buffer at a time, so the two
    /// are not two sounds racing each other: they are mixed into a single waveform
    /// and therefore always start together.
    /// </summary>
    internal static class CombatSonar
    {
        private const int SampleRate = 48_000;
        private const short ChannelCount = 2;
        private const short BitsPerSample = 16;

        private const uint SoundAsync = 0x0001;
        private const uint SoundNoDefault = 0x0002;
        private const uint SoundMemory = 0x0004;

        // A bowed string is a sawtooth-ish stack of harmonics rather than the near-pure
        // triangle used by the unit chords, which is exactly what keeps the two cues
        // apart when they sound together. Amplitudes fall off faster than 1/n so the
        // top of the stack cannot turn harsh once the glide climbs.
        private static readonly double[] ViolinHarmonicGains =
            { 1.0, 0.62, 0.40, 0.28, 0.19, 0.13, 0.08, 0.05 };

        // Harmonics do not peak together, so dividing the stack by the sum of its own
        // gains leaves the glide about half as loud as the triangle chords it is mixed
        // with. Measure one period instead and normalize by what the wave actually
        // reaches, which also keeps the balance if the table above is ever retuned.
        private static readonly double ViolinPeak = MeasureViolinPeak();

        // The impassable rasp needs the opposite treatment: enough harmonics, falling
        // off slowly enough, that the tone is all edge. Twelve reaches past 3 kHz from
        // the A below middle C without aliasing at 48 kHz.
        private const int RaspHarmonics = 12;
        private static readonly double RaspPeak = MeasureRaspPeak();

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
                        $"[CombatSonar] Ready. {SampleRate / 1000} kHz {BitsPerSample}-bit, " +
                        $"volume {_settings.Volume:0.##}, " +
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

        /// <param name="relation"><c>ally</c>, <c>enemy</c> or <c>none</c>.</param>
        /// <param name="timing"><c>1</c>, <c>2</c>, <c>3</c>, <c>many</c>, <c>done</c>
        /// or <c>none</c>.</param>
        /// <param name="positionText">
        /// Signed horizontal and vertical tile counts, the ground's height and whether
        /// the hex can be stood on, as <c>x|y|height|blocked</c>. Positive counts mean
        /// right/up; negative mean left/down. Height is <c>up</c>, <c>down</c> or
        /// <c>level</c>, relative to the active brother's own hex; blocked is
        /// <c>1</c> for ground no one can stand on.
        /// </param>
        internal static void Play(string relation, string timing, string positionText)
        {
            string[] position = positionText.Split('|');
            string height = position.Length > 2 ? position[2] : "level";
            string blockedText = position.Length > 3 ? position[3] : "0";
            bool hasUnit = relation is "ally" or "enemy";
            bool blocked = blockedText == "1";

            if ((!hasUnit && relation != "none")
                || !IsKnownTiming(timing)
                || (hasUnit && timing == "none")
                || height is not ("up" or "down" or "level")
                || blockedText is not ("0" or "1")
                || position.Length < 2
                || !int.TryParse(position[0], out int horizontalTiles)
                || !int.TryParse(position[1], out int verticalTiles)
                || horizontalTiles is < -128 or > 128
                || verticalTiles is < -128 or > 128)
            {
                return;
            }

            // Nothing to say about this hex. Squirrel already filters these out; the
            // guard keeps a future caller from queueing a buffer of pure silence.
            if (!hasUnit && height == "level" && !blocked) return;

            lock (Sync)
            {
                if (!_ready) return;

                try
                {
                    var key = new SoundKey(
                        hasUnit ? relation : "none", hasUnit ? timing : "none",
                        horizontalTiles, verticalTiles, height, blocked);
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
            return timing is "1" or "2" or "3" or "many" or "done" or "none";
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
            (double pitch, double pan) = SpatialParameters(
                key.HorizontalTiles, key.VerticalTiles);

            var events = new List<ToneEvent>();
            if (key.Relation != "none")
            {
                bool friendly = key.Relation == "ally";
                AddUnitEvents(
                    events,
                    key.Timing,
                    friendly ? _settings.FriendlyChordMidi : _settings.ThreateningChordMidi,
                    friendly ? _settings.FriendlyDoneMidi : _settings.ThreateningDoneMidi,
                    pitch);
            }

            if (key.Height != "level") AddHeightEvent(events, key.Height == "up");
            if (key.Blocked) AddBlockedEvent(events);

            int totalSamples = events.Count == 0 ? 1 : events.Max(e => e.EndSample);
            var mono = new double[totalSamples];
            foreach (ToneEvent toneEvent in events) RenderEvent(mono, toneEvent);

            // Equal-power stereo panning: centre is -3 dB in each ear, while total
            // power remains stable as the cue moves left or right. The height glide is
            // panned with the unit because it describes the very same hex.
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

        private static void AddUnitEvents(
            List<ToneEvent> events, string timing, int[] chordMidi, int[] doneMidi,
            double pitch)
        {
            if (timing == "done")
            {
                int startMs = 0;
                foreach (int midi in doneMidi)
                {
                    AddSteadyEvent(events, startMs, _settings.DoneNoteMilliseconds,
                        new[] { MidiToFrequency(midi) * pitch });
                    startMs += _settings.DoneNoteMilliseconds + _settings.DoneGapMilliseconds;
                }
                return;
            }

            double[] chord = chordMidi
                .Select(midi => MidiToFrequency(midi) * pitch)
                .ToArray();

            switch (timing)
            {
                case "1":
                    AddSteadyEvent(events, 0, _settings.OneTurnPulseMilliseconds, chord);
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
                    AddSteadyEvent(events, 0, _settings.ManyTurnsPulseMilliseconds, chord);
                    break;
            }
        }

        /// <summary>The ground under the cursor as one bowed glide, starting with the
        /// unit cue rather than after it: the two answer different questions about the
        /// same hex, and a player sweeping hexes must not pay for the second answer in
        /// time. Higher ground rises C to G, lower ground falls G to C — the interval
        /// is the same fifth read in the direction the ground goes. Both octaves sound
        /// at once, which is what makes the glide read as terrain rather than as
        /// another unit note, and the vertical-tile transposition is deliberately NOT
        /// applied to it: that shift already means "distance up the screen", and reusing
        /// it here would blur the one pitch movement that means height.</summary>
        private static void AddHeightEvent(List<ToneEvent> events, bool rising)
        {
            int fromMidi = rising ? _settings.HeightRisingFromMidi : _settings.HeightFallingFromMidi;
            int toMidi = rising ? _settings.HeightRisingToMidi : _settings.HeightFallingToMidi;
            int octave = _settings.HeightOctaveOffsetSemitones;

            var start = new[]
            {
                MidiToFrequency(fromMidi),
                MidiToFrequency(fromMidi + octave),
            };
            var end = new[]
            {
                MidiToFrequency(toMidi),
                MidiToFrequency(toMidi + octave),
            };

            int length = Math.Max(1, MillisecondsToSamples(_settings.HeightGlideMilliseconds));
            events.Add(new ToneEvent(0, length, start, end, Timbre.Violin,
                _settings.HeightAttackMilliseconds, _settings.HeightReleaseMilliseconds,
                _settings.HeightGain,
                _settings.HeightVibratoHertz, _settings.HeightVibratoSemitones));
        }

        /// <summary>Ground no one can stand on: a tree, a boulder, a wall, deep water.
        /// It shares the hex with whatever else the cursor found there, so like the
        /// height glide it starts at zero rather than queueing behind the unit cue.
        ///
        /// The texture is the message. Where a unit sings a chord and the ground bows a
        /// clean fifth, this one buzzes and is chopped into grains, so "you cannot go
        /// here" is recognisable from its first few milliseconds without any note being
        /// identified. Its pitch wobbles up from A to C and back rather than gliding:
        /// an unsteady, unresolved interval, deliberately the opposite of the height
        /// cue's single clean sweep.</summary>
        private static void AddBlockedEvent(List<ToneEvent> events)
        {
            double semitones = _settings.BlockedHighMidi - _settings.BlockedLowMidi;
            var frequencies = new[] { MidiToFrequency(_settings.BlockedLowMidi) };
            int length = Math.Max(1, MillisecondsToSamples(_settings.BlockedMilliseconds));

            events.Add(new ToneEvent(0, length, frequencies, frequencies, Timbre.Rasp,
                _settings.BlockedAttackMilliseconds, _settings.BlockedReleaseMilliseconds,
                _settings.BlockedGain,
                _settings.BlockedVibratoHertz, semitones, vibratoUpwardsOnly: true,
                _settings.BlockedGrainHertz, _settings.BlockedGrainDepth));
        }

        private static void AddRepeatedEvents(
            List<ToneEvent> events, int count, int pulseMs, int gapMs, double[] frequencies)
        {
            int startMs = 0;
            for (int i = 0; i < count; i++)
            {
                AddSteadyEvent(events, startMs, pulseMs, frequencies);
                startMs += pulseMs + gapMs;
            }
        }

        private static void AddSteadyEvent(
            List<ToneEvent> events, int startMs, int durationMs, double[] frequencies)
        {
            int start = MillisecondsToSamples(startMs);
            int length = Math.Max(1, MillisecondsToSamples(durationMs));
            events.Add(new ToneEvent(start, length, frequencies, frequencies,
                Timbre.Triangle, _settings.AttackMilliseconds,
                _settings.ReleaseMilliseconds, 1.0));
        }

        private static int MillisecondsToSamples(int milliseconds)
        {
            return (int)Math.Round(milliseconds * SampleRate / 1000.0);
        }

        private static void RenderEvent(double[] mono, ToneEvent toneEvent)
        {
            int attack = Math.Min(
                MillisecondsToSamples(toneEvent.AttackMilliseconds), toneEvent.Length / 2);
            int release = Math.Min(
                MillisecondsToSamples(toneEvent.ReleaseMilliseconds), toneEvent.Length / 2);

            // Phase is integrated sample by sample rather than computed from an elapsed
            // time, because a glide has no single frequency to multiply by: the only way
            // to sweep C to G without a click halfway is to keep the running phase.
            var phases = new double[toneEvent.Frequencies.Length];
            double vibratoRate = toneEvent.VibratoHertz;
            double vibratoDepth = toneEvent.VibratoSemitones;

            for (int local = 0; local < toneEvent.Length; local++)
            {
                double seconds = local / (double)SampleRate;
                double envelope = 1.0;
                if (attack > 0 && local < attack)
                    envelope *= (local + 1.0) / attack;
                if (release > 0 && local >= toneEvent.Length - release)
                    envelope *= (toneEvent.Length - local) / (double)release;

                // The grain gate is deliberately hard-edged: its discontinuities are
                // most of what the ear hears as roughness. It sits inside the attack
                // and release ramps, so the event as a whole still starts and ends
                // without a click.
                if (toneEvent.GrainHertz > 0.0 && toneEvent.GrainDepth > 0.0)
                {
                    bool open = Math.Sin(2.0 * Math.PI * toneEvent.GrainHertz * seconds) >= 0.0;
                    if (!open) envelope *= 1.0 - toneEvent.GrainDepth;
                }

                // Exponential interpolation, so the sweep is musically even: equal
                // fractions of the glide cover equal intervals, not equal hertz.
                double progress = toneEvent.Length == 1
                    ? 1.0
                    : local / (double)(toneEvent.Length - 1);

                double vibrato = 1.0;
                if (vibratoRate > 0.0 && vibratoDepth > 0.0)
                {
                    // Upwards-only starts at rest and swings to +depth and back, so the
                    // written note is the bottom of the interval rather than its centre.
                    double swing = toneEvent.VibratoUpwardsOnly
                        ? (1.0 - Math.Cos(2.0 * Math.PI * vibratoRate * seconds)) / 2.0
                        : Math.Sin(2.0 * Math.PI * vibratoRate * seconds);
                    vibrato = Math.Pow(2.0, vibratoDepth * swing / 12.0);
                }

                double sample = 0.0;
                for (int partial = 0; partial < toneEvent.Frequencies.Length; partial++)
                {
                    double from = toneEvent.Frequencies[partial];
                    double to = toneEvent.EndFrequencies[partial];
                    double frequency = from * Math.Pow(to / from, progress) * vibrato;
                    phases[partial] += frequency / SampleRate;
                    sample += Voice(toneEvent.Timbre, phases[partial]);
                }

                sample /= toneEvent.Frequencies.Length;
                mono[toneEvent.StartSample + local] += sample * envelope * toneEvent.Gain;
            }
        }

        private static double Voice(Timbre timbre, double phase)
        {
            if (timbre == Timbre.Triangle)
            {
                double fraction = phase - Math.Floor(phase);
                return 1.0 - 4.0 * Math.Abs(fraction - 0.5);
            }

            if (timbre == Timbre.Rasp) return RaspSample(phase) / RaspPeak;
            return ViolinSample(phase) / ViolinPeak;
        }

        /// <summary>A sawtooth carries every harmonic at 1/n, which is bright but still
        /// musical. Rolling off at 1/sqrt(n) instead keeps the upper harmonics loud
        /// enough to buzz, which is the difference between a bowed note and a scrape.
        /// </summary>
        private static double RaspSample(double phase)
        {
            double sum = 0.0;
            for (int harmonic = 1; harmonic <= RaspHarmonics; harmonic++)
            {
                sum += Math.Sin(2.0 * Math.PI * harmonic * phase) / Math.Sqrt(harmonic);
            }
            return sum;
        }

        private static double ViolinSample(double phase)
        {
            double sum = 0.0;
            for (int harmonic = 0; harmonic < ViolinHarmonicGains.Length; harmonic++)
            {
                sum += ViolinHarmonicGains[harmonic]
                    * Math.Sin(2.0 * Math.PI * (harmonic + 1) * phase);
            }
            return sum;
        }

        private static double MeasureViolinPeak()
        {
            return MeasurePeak(ViolinSample);
        }

        private static double MeasureRaspPeak()
        {
            return MeasurePeak(RaspSample);
        }

        /// <summary>Normalize an additive voice to unit amplitude, so adding or removing
        /// harmonics changes its colour without changing how loud the cue comes out.
        /// </summary>
        private static double MeasurePeak(Func<double, double> voice)
        {
            double peak = 0.0;
            const int steps = 4096;
            for (int step = 0; step < steps; step++)
            {
                peak = Math.Max(peak, Math.Abs(voice(step / (double)steps)));
            }
            return peak > 0.0 ? peak : 1.0;
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

        private enum Timbre
        {
            Triangle,
            Violin,
            Rasp,
        }

        private readonly record struct SoundKey(
            string Relation, string Timing, int HorizontalTiles, int VerticalTiles,
            string Height, bool Blocked);

        private sealed class ToneEvent
        {
            internal ToneEvent(
                int startSample, int length, double[] frequencies, double[] endFrequencies,
                Timbre timbre, int attackMilliseconds, int releaseMilliseconds, double gain,
                double vibratoHertz = 0.0, double vibratoSemitones = 0.0,
                bool vibratoUpwardsOnly = false, double grainHertz = 0.0,
                double grainDepth = 0.0)
            {
                StartSample = startSample;
                Length = length;
                Frequencies = frequencies;
                EndFrequencies = endFrequencies;
                Timbre = timbre;
                AttackMilliseconds = attackMilliseconds;
                ReleaseMilliseconds = releaseMilliseconds;
                Gain = gain;
                VibratoHertz = vibratoHertz;
                VibratoSemitones = vibratoSemitones;
                VibratoUpwardsOnly = vibratoUpwardsOnly;
                GrainHertz = grainHertz;
                GrainDepth = grainDepth;
            }

            internal int StartSample { get; }
            internal int Length { get; }
            internal int EndSample => StartSample + Length;
            internal double[] Frequencies { get; }
            internal double[] EndFrequencies { get; }
            internal Timbre Timbre { get; }
            internal int AttackMilliseconds { get; }
            internal int ReleaseMilliseconds { get; }
            internal double Gain { get; }
            internal double VibratoHertz { get; }
            internal double VibratoSemitones { get; }

            /// <summary>Bowed vibrato swings either side of the written note, so it
            /// colours a pitch without changing it. The impassable rasp instead uses
            /// its swing AS the interval — it must start on A and reach C, never dip
            /// below A — so its oscillation is one-sided.</summary>
            internal bool VibratoUpwardsOnly { get; }

            /// <summary>Hard amplitude gate; zero leaves the tone smooth. This is what
            /// makes the impassable cue scrape rather than sing: the tone is chopped
            /// tens of times per second, the way a bow dragged across a string is.
            /// </summary>
            internal double GrainHertz { get; }
            internal double GrainDepth { get; }
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

            // The terrain glide: C4 to G4 climbing, G4 to C4 falling, doubled one
            // octave up, bowed rather than struck.
            public int HeightGlideMilliseconds { get; set; } = 200;
            public int HeightRisingFromMidi { get; set; } = 60;
            public int HeightRisingToMidi { get; set; } = 67;
            public int HeightFallingFromMidi { get; set; } = 67;
            public int HeightFallingToMidi { get; set; } = 60;
            public int HeightOctaveOffsetSemitones { get; set; } = 12;
            public int HeightAttackMilliseconds { get; set; } = 30;
            public int HeightReleaseMilliseconds { get; set; } = 45;
            public double HeightGain { get; set; } = 0.8;
            public double HeightVibratoHertz { get; set; } = 5.5;
            public double HeightVibratoSemitones { get; set; } = 0.2;

            // Impassable ground: A3 wobbling up to C4 and back, buzzed and chopped.
            // The gate rate is deliberately far above the vibrato rate — one is the
            // roughness, the other the wobble, and they must not lock into each other.
            public int BlockedMilliseconds { get; set; } = 250;
            public int BlockedLowMidi { get; set; } = 57;
            public int BlockedHighMidi { get; set; } = 60;
            public double BlockedVibratoHertz { get; set; } = 8.0;
            public double BlockedGrainHertz { get; set; } = 55.0;
            public double BlockedGrainDepth { get; set; } = 0.55;
            public int BlockedAttackMilliseconds { get; set; } = 6;
            public int BlockedReleaseMilliseconds { get; set; } = 18;
            public double BlockedGain { get; set; } = 0.7;

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

                HeightGlideMilliseconds = ClampTime(HeightGlideMilliseconds, 40, 2_000);
                HeightRisingFromMidi = ClampNote(HeightRisingFromMidi, 60);
                HeightRisingToMidi = ClampNote(HeightRisingToMidi, 67);
                HeightFallingFromMidi = ClampNote(HeightFallingFromMidi, 67);
                HeightFallingToMidi = ClampNote(HeightFallingToMidi, 60);
                // The doubled octave must stay inside MIDI range for every note above.
                HeightOctaveOffsetSemitones = Math.Clamp(HeightOctaveOffsetSemitones, 0, 24);
                HeightAttackMilliseconds = ClampTime(HeightAttackMilliseconds, 0, 200);
                HeightReleaseMilliseconds = ClampTime(HeightReleaseMilliseconds, 0, 200);
                HeightGain = Math.Clamp(HeightGain, 0.0, 1.0);
                HeightVibratoHertz = Math.Clamp(HeightVibratoHertz, 0.0, 12.0);
                HeightVibratoSemitones = Math.Clamp(HeightVibratoSemitones, 0.0, 2.0);

                BlockedMilliseconds = ClampTime(BlockedMilliseconds, 40, 2_000);
                BlockedLowMidi = ClampNote(BlockedLowMidi, 57);
                BlockedHighMidi = ClampNote(BlockedHighMidi, 60);
                // The wobble is expressed as the interval between the two notes, so an
                // upside-down pair would silently invert it into a downward swing.
                if (BlockedHighMidi < BlockedLowMidi) BlockedHighMidi = BlockedLowMidi;
                BlockedVibratoHertz = Math.Clamp(BlockedVibratoHertz, 0.0, 40.0);
                BlockedGrainHertz = Math.Clamp(BlockedGrainHertz, 0.0, 400.0);
                BlockedGrainDepth = Math.Clamp(BlockedGrainDepth, 0.0, 1.0);
                BlockedAttackMilliseconds = ClampTime(BlockedAttackMilliseconds, 0, 200);
                BlockedReleaseMilliseconds = ClampTime(BlockedReleaseMilliseconds, 0, 200);
                BlockedGain = Math.Clamp(BlockedGain, 0.0, 1.0);
            }

            private static int ClampTime(int value, int minimum, int maximum)
            {
                return Math.Clamp(value, minimum, maximum);
            }

            private static int ClampNote(int value, int fallback)
            {
                return value is < 0 or > 103 ? fallback : value;
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

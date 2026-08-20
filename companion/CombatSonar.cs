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
    /// Morale is the exception, and can be: it is the one layer the vertical-tile
    /// transposition never touches, so a recording can stand in for the synthesized
    /// phrase without any resampling and without inheriting the rhythm problem above.
    /// The five files in <c>sounds\</c> are read once at startup and mixed in like any
    /// other layer; a file that is missing or unreadable falls back to the synthesized
    /// voice for that state, so a bad edit costs the recording, never the cue.
    ///
    /// A tile can report several facts at once — a unit standing on it, the height of
    /// the ground under it, and that unit's morale. PlaySound plays exactly one buffer
    /// at a time, so they are not sounds racing each other: they are mixed into a
    /// single waveform, which is also the only way to place the morale cue half a
    /// second after the rest instead of on top of it.
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

        // Morale gets a voice of its own so it is recognisable before a single note is
        // identified: rounder than the triangle chords, warmer and far less edgy than
        // the bowed glide, with the even harmonics kept in — a horn rather than a
        // string. It is the only cue that has to carry a melody, and a melody needs a
        // timbre the ear will follow for a whole second without tiring.
        private static readonly double[] HornHarmonicGains =
            { 1.0, 0.45, 0.30, 0.15, 0.08 };

        private static readonly double HornPeak = MeasureHornPeak();

        private static readonly object Sync = new();
        private static readonly Dictionary<SoundKey, byte[]> Cache = new();

        // The morale phrase makes a cue up to 1.5 s long, six times the old maximum, so
        // the cache is bounded by the memory it actually holds rather than by a count of
        // entries that now vary hugely in size.
        private const int CacheByteBudget = 16 * 1024 * 1024;
        private static int _cacheBytes;

        private static SonarSettings _settings = new();

        /// <summary>The morale recordings, by the engine's own morale index, already
        /// downmixed to mono at <see cref="SampleRate"/>. A state missing from here is
        /// a state that sings its synthesized phrase instead.</summary>
        private static Dictionary<string, double[]> _moraleSamples = new();

        /// <summary>The corpse recording, read the same way and on the same terms: null
        /// is the file missing or unreadable, and then the hex rasps its synthesized
        /// stand-in instead of going quiet.</summary>
        private static double[]? _corpseSample;

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
                _cacheBytes = 0;
                _failureReported = false;
                _settings = SonarSettings.Load(configPath);
                // The recordings sit beside the config that names them, so moving both
                // to another folder keeps them together with no second path to edit.
                string soundsFolder = ResolveSoundsFolder(
                    Path.GetDirectoryName(configPath) ?? AppContext.BaseDirectory);
                _moraleSamples = LoadMoraleSamples(soundsFolder);
                _corpseSample = _settings.CorpseEnabled
                    ? LoadSample(soundsFolder, _settings.CorpseSample, "Corpse sound",
                        _settings.CorpseSampleMaxMilliseconds)
                    : null;
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
                _cacheBytes = 0;
                _moraleSamples = new Dictionary<string, double[]>();
                _corpseSample = null;
                _ready = false;
            }
        }

        /// <summary>Where the recorded cues live: beside the config that names them,
        /// unless the config gives an absolute path of its own.</summary>
        private static string ResolveSoundsFolder(string baseDirectory)
        {
            return Path.IsPathRooted(_settings.SoundsFolder)
                ? _settings.SoundsFolder
                : Path.Combine(baseDirectory, _settings.SoundsFolder);
        }

        /// <summary>Read whatever recordings the config names, once, so a battle never
        /// pays for disk. Every failure is reported and then forgiven: the state simply
        /// keeps its synthesized voice.</summary>
        private static Dictionary<string, double[]> LoadMoraleSamples(string folder)
        {
            var samples = new Dictionary<string, double[]>();
            if (!_settings.MoraleEnabled) return samples;

            foreach (string morale in MoraleIndices)
            {
                MoraleVoice? voice = _settings.MoraleVoiceFor(morale);
                double[]? mono = LoadSample(folder, voice?.Sample ?? string.Empty,
                    "Morale sound", _settings.MoraleSampleMaxMilliseconds);
                if (mono != null) samples[morale] = mono;
            }

            return samples;
        }

        /// <summary>One recorded cue as mono at <see cref="SampleRate"/>, or null when
        /// the config names none, the file is not there, or it cannot be read. Every one
        /// of those is a line on the console and then forgiven: a layer that loses its
        /// recording falls back to being synthesized, so a bad file costs the recording
        /// and never the cue.</summary>
        private static double[]? LoadSample(
            string folder, string file, string what, int maximumMilliseconds)
        {
            if (string.IsNullOrWhiteSpace(file)) return null;

            string path = Path.IsPathRooted(file) ? file : Path.Combine(folder, file);
            if (!File.Exists(path))
            {
                Console.WriteLine(
                    $"[CombatSonar] {what} '{path}' not found; " +
                    "that cue keeps its synthesized voice.");
                return null;
            }

            try
            {
                double[] mono = WaveFile.ReadMono(path, SampleRate);
                if (mono.Length == 0) throw new InvalidDataException("no audio in the file.");

                double milliseconds = mono.Length * 1000.0 / SampleRate;
                string note = milliseconds > maximumMilliseconds
                    ? $" — cut to {maximumMilliseconds} ms; raise the cue's " +
                      "maximum to hear all of it"
                    : string.Empty;
                Console.WriteLine(
                    $"[CombatSonar] {what} '{Path.GetFileName(path)}' loaded, " +
                    $"{milliseconds:0} ms.{note}");
                return mono;
            }
            catch (Exception e)
            {
                Console.WriteLine(
                    $"[CombatSonar] Could not read {what.ToLowerInvariant()} '{path}'; " +
                    $"that cue keeps its synthesized voice. {e.Message}");
                return null;
            }
        }

        /// <param name="relation"><c>ally</c>, <c>enemy</c> or <c>none</c>.</param>
        /// <param name="timing"><c>1</c>, <c>2</c>, <c>3</c>, <c>many</c>, <c>done</c>
        /// or <c>none</c>.</param>
        /// <param name="positionText">
        /// Signed horizontal and vertical tile counts, the ground's height, whether
        /// the hex can be stood on, the occupant's morale and whether a body lies on
        /// it, as <c>x|y|height|blocked|morale|corpse</c>. Positive counts mean
        /// right/up; negative mean left/down. Height is <c>up</c>, <c>down</c> or
        /// <c>level</c>, relative to the active brother's own hex; blocked is <c>1</c>
        /// for ground no one can stand on; morale is the engine's own state index
        /// <c>0</c>-<c>4</c> (fleeing to confident) or <c>-</c> for none; corpse is
        /// <c>1</c> for a hex with the dead on it, and may be absent entirely, which
        /// reads as none.
        /// </param>
        internal static void Play(string relation, string timing, string positionText)
        {
            SoundKey? parsed = ParseRequest(relation, timing, positionText);
            if (parsed == null) return;
            SoundKey key = parsed.Value;

            lock (Sync)
            {
                if (!_ready) return;

                try
                {
                    if (!Cache.TryGetValue(key, out byte[]? wave))
                    {
                        // Positions are data-dependent, so keep the otherwise useful
                        // waveform cache bounded during long battles.
                        if (_cacheBytes >= CacheByteBudget)
                        {
                            Cache.Clear();
                            _cacheBytes = 0;
                        }
                        wave = RenderWave(key);
                        Cache[key] = wave;
                        _cacheBytes += wave.Length;
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

        /// <summary>Render the very waveform <see cref="Play"/> would play, without
        /// playing it, so a cue can be written out and auditioned as a file. Returns
        /// null for a request that says nothing about the hex.</summary>
        internal static byte[]? Render(string relation, string timing, string positionText)
        {
            SoundKey? parsed = ParseRequest(relation, timing, positionText);
            return parsed == null ? null : RenderWave(parsed.Value);
        }

        /// <summary>Validate a request and reduce it to the key which identifies its
        /// waveform. Null means "nothing audible here": either the fields are
        /// malformed, or the hex carries no unit, no slope, no obstacle and no
        /// morale. Squirrel already filters the silent case out; the guard keeps a
        /// future caller from queueing a buffer of pure silence.</summary>
        private static SoundKey? ParseRequest(
            string relation, string timing, string positionText)
        {
            string[] position = positionText.Split('|');
            string height = position.Length > 2 ? position[2] : "level";
            string blockedText = position.Length > 3 ? position[3] : "0";
            string morale = position.Length > 4 ? position[4] : "-";
            // The corpse flag was added after the field it follows, and a mod and a
            // companion of different vintages meet during every dev restart: an absent
            // field is "no corpse here", never a malformed request.
            string corpseText = position.Length > 5 ? position[5] : "0";
            bool hasUnit = relation is "ally" or "enemy";
            bool blocked = blockedText == "1";
            bool corpse = corpseText == "1";

            if ((!hasUnit && relation != "none")
                || !IsKnownTiming(timing)
                || height is not ("up" or "down" or "level")
                || blockedText is not ("0" or "1")
                || corpseText is not ("0" or "1")
                || !IsKnownMorale(morale)
                || position.Length < 2
                || !int.TryParse(position[0], out int horizontalTiles)
                || !int.TryParse(position[1], out int verticalTiles)
                || horizontalTiles is < -128 or > 128
                || verticalTiles is < -128 or > 128)
            {
                return null;
            }

            // Morale belongs to a unit, so an empty hex claiming one is ignored rather
            // than given a voice of its own. A unit whose live queue position carries
            // no honest value arrives with timing "none": that silences its rhythm
            // without silencing the morale phrase that travels with it.
            if (!hasUnit) morale = "-";
            bool hasRhythm = hasUnit && timing != "none";
            if (!hasRhythm && height == "level" && !blocked && morale == "-" && !corpse)
                return null;

            return new SoundKey(
                hasUnit ? relation : "none", hasUnit ? timing : "none",
                horizontalTiles, verticalTiles, height, blocked, morale, corpse);
        }

        private static bool IsKnownTiming(string timing)
        {
            return timing is "1" or "2" or "3" or "many" or "done" or "none";
        }

        /// <summary>The engine's own Const.MoraleState indices, minus Ignore (5): a
        /// unit which cannot break has no morale to report.</summary>
        private static readonly string[] MoraleIndices = { "0", "1", "2", "3", "4" };

        private static bool IsKnownMorale(string morale)
        {
            return morale == "-" || Array.IndexOf(MoraleIndices, morale) >= 0;
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
            if (key.Corpse) AddCorpseEvent(events);
            if (key.Morale != "-") AddMoraleEvents(events, key.Morale);

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

        /// <summary>A body on the hex. Like the height glide and the impassable rasp it
        /// describes the ground rather than whoever stands on it, so it starts at zero
        /// with them instead of queueing behind: the dead are commonly under a living
        /// unit, and a player sweeping hexes must get all three answers in one breath.
        ///
        /// It is a recording (<c>corpse.wav</c>, named in the config like the morale
        /// cues) with a synthesized rasp behind it, so a missing or unreadable file
        /// costs the recording and never the cue. Both are the same idea: a high, dry
        /// rasp — the impassable cue's texture taken up two and a half octaves, where it
        /// reads as a rattle rather than as a wall. High against low is what tells the
        /// two rasps apart; nothing about the note matters beyond that.</summary>
        private static void AddCorpseEvent(List<ToneEvent> events)
        {
            if (!_settings.CorpseEnabled) return;

            int delay = MillisecondsToSamples(_settings.CorpseDelayMilliseconds);
            if (_corpseSample != null)
            {
                int length = Math.Min(_corpseSample.Length,
                    Math.Max(1, MillisecondsToSamples(_settings.CorpseSampleMaxMilliseconds)));
                if (length > 0)
                {
                    events.Add(new ToneEvent(delay, length, _corpseSample,
                        _settings.CorpseSampleFadeMilliseconds,
                        _settings.CorpseSampleFadeMilliseconds,
                        _settings.CorpseSampleGain));
                    return;
                }
            }

            // The synthesized stand-in: the same hard grain gate as the impassable cue,
            // but the pitch sags instead of climbing. Rising is that cue's signature —
            // the ground pushing back — and a corpse must not borrow it. Its wobble is a
            // shallow tremble either side of the glide rather than an interval of its
            // own, so what the ear measures is the fall.
            var start = new[] { MidiToFrequency(_settings.CorpseHighMidi) };
            var end = new[] { MidiToFrequency(_settings.CorpseLowMidi) };
            int total = Math.Max(1, MillisecondsToSamples(_settings.CorpseMilliseconds));

            events.Add(new ToneEvent(delay, total, start, end, Timbre.Rasp,
                _settings.CorpseAttackMilliseconds, _settings.CorpseReleaseMilliseconds,
                _settings.CorpseGain,
                _settings.CorpseVibratoHertz, _settings.CorpseVibratoSemitones,
                vibratoUpwardsOnly: false,
                _settings.CorpseGrainHertz, _settings.CorpseGrainDepth));
        }

        /// <summary>The focused unit's morale. A recording from <c>sounds\</c> when the
        /// state has one, and the synthesized phrase below when it does not.
        ///
        /// Unlike every other cue it does not start at zero: it is delayed half a second
        /// so the unit's rhythm and the ground's glide — the two answers a player
        /// navigates by — are already over when it begins. Morale is context, not
        /// navigation, and must never be the thing that delays them. Recordings were
        /// tried without the delay and it is the delay that makes them legible: mixed
        /// underneath, they arrive as texture on the cue rather than as their own answer.
        ///
        /// The synthesized fallback: a one-second chord with a short modal phrase sung
        /// over it. Each state is a different mode over the same D, so what changes
        /// between them is the colour of the interval rather than a pitch to be measured:
        ///
        ///  - Confident: D dorian, five notes arpeggiating up to the natural sixth and
        ///    the octave. The major sixth over a minor triad is what makes dorian sound
        ///    resolute rather than merely sad.
        ///  - Steady: an open fifth with no third at all and two unhurried notes. The
        ///    most common state says the least, and says it without an opinion.
        ///  - Wavering: A minor, four notes circling the second degree and ending on it,
        ///    with vibrato. Nothing resolves; the phrase trembles in place.
        ///  - Breaking: D minor with a phrygian flat second and the harmonic minor's
        ///    raised seventh — Eb falling to C# is a diminished third, the lament figure,
        ///    and it collapses an octave onto the tonic.
        ///  - Fleeing: D locrian over a diminished triad, five fast notes reaching the
        ///    flat fifth. The tritone in both chord and phrase is the point: the ground
        ///    under the tonic is missing.
        /// </summary>
        private static void AddMoraleEvents(List<ToneEvent> events, string morale)
        {
            MoraleVoice? voice = _settings.MoraleVoiceFor(morale);
            if (voice == null || !_settings.MoraleEnabled) return;

            int delay = MillisecondsToSamples(_settings.MoraleDelayMilliseconds);
            int total = Math.Max(1, MillisecondsToSamples(_settings.MoraleMilliseconds));

            if (_moraleSamples.TryGetValue(morale, out double[]? sample))
            {
                AddMoraleSampleEvent(events, sample, delay,
                    Math.Max(1, MillisecondsToSamples(_settings.MoraleSampleMaxMilliseconds)));
                return;
            }

            double[] chord = voice.ChordMidi.Select(MidiToFrequency).ToArray();
            events.Add(new ToneEvent(delay, total, chord, chord, Timbre.Horn,
                _settings.MoraleAttackMilliseconds, _settings.MoraleReleaseMilliseconds,
                _settings.MoraleChordGain));

            int startMs = voice.StartMilliseconds;
            foreach (int midi in voice.MelodyMidi)
            {
                // The phrase never outlives the chord under it: a note that would run
                // past the one-second cue is dropped rather than stretching the buffer,
                // so retuning a melody can change what is heard but never how long the
                // player waits for the next hex.
                if (startMs + voice.NoteMilliseconds > _settings.MoraleMilliseconds) break;

                var note = new[] { MidiToFrequency(midi) };
                events.Add(new ToneEvent(
                    delay + MillisecondsToSamples(startMs),
                    Math.Max(1, MillisecondsToSamples(voice.NoteMilliseconds)),
                    note, note, Timbre.Horn,
                    _settings.MoraleNoteAttackMilliseconds,
                    _settings.MoraleNoteReleaseMilliseconds,
                    _settings.MoraleMelodyGain,
                    voice.VibratoHertz, voice.VibratoSemitones));
                startMs += voice.NoteMilliseconds + voice.GapMilliseconds;
            }
        }

        /// <summary>Place a morale recording in the mix. Its shape is left alone — it
        /// was authored, not generated — but its level is not: what a file was exported
        /// at has nothing to do with how loud it should sit under a chord it never met,
        /// so one gain in the config balances it against the rest, and two more rules
        /// apply. A recording longer than the configured maximum is cut short, because
        /// that cap is what guarantees a hex stops speaking; and both ends get a fade of
        /// a few milliseconds, inaudible on a file that already starts and ends in
        /// silence and the difference between a clean cut and a click on one that does
        /// not.</summary>
        private static void AddMoraleSampleEvent(
            List<ToneEvent> events, double[] sample, int delay, int maximumLength)
        {
            int length = Math.Min(sample.Length, maximumLength);
            if (length <= 0) return;

            events.Add(new ToneEvent(delay, length, sample,
                _settings.MoraleSampleFadeMilliseconds,
                _settings.MoraleSampleFadeMilliseconds,
                _settings.MoraleSampleGain));
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

            if (toneEvent.Sample != null)
            {
                RenderSampleEvent(mono, toneEvent, attack, release);
                return;
            }

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

        /// <summary>A recorded layer: no oscillator, no glide, no vibrato — every one of
        /// those decisions was already made by whoever recorded it. All that is left is
        /// the fade at each end and the gain, and then it joins the same mono bus as the
        /// synthesized layers, so it is panned by the hex's column exactly like them.
        /// </summary>
        private static void RenderSampleEvent(
            double[] mono, ToneEvent toneEvent, int attack, int release)
        {
            double[] sample = toneEvent.Sample!;
            for (int local = 0; local < toneEvent.Length; local++)
            {
                double envelope = 1.0;
                if (attack > 0 && local < attack)
                    envelope *= (local + 1.0) / attack;
                if (release > 0 && local >= toneEvent.Length - release)
                    envelope *= (toneEvent.Length - local) / (double)release;

                mono[toneEvent.StartSample + local] +=
                    sample[local] * envelope * toneEvent.Gain;
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
            if (timbre == Timbre.Horn) return HornSample(phase) / HornPeak;
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

        private static double HornSample(double phase)
        {
            double sum = 0.0;
            for (int harmonic = 0; harmonic < HornHarmonicGains.Length; harmonic++)
            {
                sum += HornHarmonicGains[harmonic]
                    * Math.Sin(2.0 * Math.PI * (harmonic + 1) * phase);
            }
            return sum;
        }

        private static double MeasureViolinPeak()
        {
            return MeasurePeak(ViolinSample);
        }

        private static double MeasureHornPeak()
        {
            return MeasurePeak(HornSample);
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

        /// <summary>Just enough WAV reading for hand-made cue material: the chunks are
        /// walked rather than assumed, because an editor's export carries metadata
        /// (<c>bext</c>, <c>LIST</c>, cue points) between the header and the audio, and
        /// the classic "audio starts at byte 44" shortcut reads that metadata as sound.
        /// </summary>
        private static class WaveFile
        {
            private const int FormatPcm = 1;
            private const int FormatFloat = 3;
            private const int FormatExtensible = 0xFFFE;

            /// <summary>Read a file as one mono channel at <paramref name="targetRate"/>,
            /// in the -1..1 the mixer works in. Mono because the sonar's own equal-power
            /// pan is what places a cue in the player's head: a stereo recording placing
            /// itself would fight the one thing the cue exists to say, which is which way
            /// the hex lies.</summary>
            internal static double[] ReadMono(string path, int targetRate)
            {
                using FileStream stream = File.OpenRead(path);
                using var reader = new BinaryReader(stream);

                if (ReadFourCc(reader) != "RIFF")
                    throw new InvalidDataException("not a RIFF file.");
                reader.ReadUInt32(); // Declared size; the chunk walk is the real bound.
                if (ReadFourCc(reader) != "WAVE")
                    throw new InvalidDataException("not a WAVE file.");

                int format = 0;
                int channels = 0;
                int sourceRate = 0;
                int bits = 0;
                byte[]? data = null;

                while (stream.Position + 8 <= stream.Length)
                {
                    string id = ReadFourCc(reader);
                    long size = reader.ReadUInt32();
                    // Chunks are word-aligned: an odd size is followed by a pad byte
                    // which belongs to no one.
                    long next = stream.Position + size + (size % 2);

                    if (id == "fmt " && size >= 16)
                    {
                        format = reader.ReadUInt16();
                        channels = reader.ReadUInt16();
                        sourceRate = reader.ReadInt32();
                        reader.ReadInt32();  // Byte rate, derivable from the rest.
                        reader.ReadUInt16(); // Block align, likewise.
                        bits = reader.ReadUInt16();

                        // WAVE_FORMAT_EXTENSIBLE hides the real format in the first two
                        // bytes of a sub-format GUID. Read past it, or 32-bit float —
                        // which is what several editors export by default — is taken for
                        // PCM and comes out as noise.
                        if (format == FormatExtensible && size >= 40)
                        {
                            reader.ReadUInt16(); // Extension size.
                            reader.ReadUInt16(); // Valid bits per sample.
                            reader.ReadUInt32(); // Channel mask.
                            format = reader.ReadUInt16();
                        }
                    }
                    else if (id == "data" && size > 0)
                    {
                        data = reader.ReadBytes((int)Math.Min(size, int.MaxValue));
                    }

                    if (next > stream.Length) break;
                    stream.Position = next;
                }

                if (data == null) throw new InvalidDataException("no data chunk.");
                if (channels is < 1 or > 8)
                    throw new InvalidDataException($"unsupported channel count {channels}.");
                if (sourceRate is < 1_000 or > 384_000)
                    throw new InvalidDataException($"unsupported sample rate {sourceRate}.");

                double[] mono = ToMono(data, format, channels, bits);
                return sourceRate == targetRate ? mono : Resample(mono, sourceRate, targetRate);
            }

            private static double[] ToMono(byte[] data, int format, int channels, int bits)
            {
                int bytesPerSample = bits / 8;
                if (bytesPerSample <= 0 || !IsSupported(format, bits))
                {
                    throw new InvalidDataException(
                        $"unsupported format {format} at {bits} bits. " +
                        "Export as 16-bit PCM.");
                }

                int frameBytes = bytesPerSample * channels;
                int frames = data.Length / frameBytes;
                var mono = new double[frames];

                for (int frame = 0; frame < frames; frame++)
                {
                    double sum = 0.0;
                    int offset = frame * frameBytes;
                    for (int channel = 0; channel < channels; channel++)
                    {
                        sum += ReadSample(data, offset + channel * bytesPerSample, format, bits);
                    }
                    mono[frame] = sum / channels;
                }

                return mono;
            }

            private static bool IsSupported(int format, int bits)
            {
                if (format == FormatPcm) return bits is 8 or 16 or 24 or 32;
                if (format == FormatFloat) return bits is 32 or 64;
                return false;
            }

            private static double ReadSample(byte[] data, int offset, int format, int bits)
            {
                if (format == FormatFloat)
                {
                    return bits == 32
                        ? BitConverter.ToSingle(data, offset)
                        : BitConverter.ToDouble(data, offset);
                }

                switch (bits)
                {
                    // 8-bit PCM is the odd one out in the format: unsigned, centred on
                    // 128 rather than on zero.
                    case 8: return (data[offset] - 128) / 128.0;
                    case 16: return BitConverter.ToInt16(data, offset) / 32_768.0;
                    case 24:
                        int value = data[offset] | (data[offset + 1] << 8)
                                                 | (data[offset + 2] << 16);
                        // Sign-extend the 24th bit by hand; there is no Int24.
                        if ((value & 0x800000) != 0) value -= 0x1000000;
                        return value / 8_388_608.0;
                    default: return BitConverter.ToInt32(data, offset) / 2_147_483_648.0;
                }
            }

            /// <summary>Linear interpolation. These are short, quiet, hand-made cues and
            /// the common case is a file already at 48 kHz, which skips this entirely;
            /// a windowed-sinc resampler would be precision nobody can hear.</summary>
            private static double[] Resample(double[] source, int sourceRate, int targetRate)
            {
                if (source.Length == 0) return source;

                double ratio = targetRate / (double)sourceRate;
                var resampled = new double[Math.Max(1, (int)(source.Length * ratio))];
                for (int index = 0; index < resampled.Length; index++)
                {
                    double position = index / ratio;
                    int left = (int)position;
                    int right = Math.Min(left + 1, source.Length - 1);
                    double fraction = position - left;
                    if (left >= source.Length) break;
                    resampled[index] = source[left] * (1.0 - fraction) + source[right] * fraction;
                }

                return resampled;
            }

            private static string ReadFourCc(BinaryReader reader)
            {
                byte[] bytes = reader.ReadBytes(4);
                if (bytes.Length < 4) return string.Empty;
                return new string(bytes.Select(b => (char)b).ToArray());
            }
        }

        private enum Timbre
        {
            Triangle,
            Violin,
            Rasp,
            Horn,
        }

        private readonly record struct SoundKey(
            string Relation, string Timing, int HorizontalTiles, int VerticalTiles,
            string Height, bool Blocked, string Morale, bool Corpse);

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

            /// <summary>A recorded event. It carries no frequencies because it has no
            /// notes to be told: the audio is the note.</summary>
            internal ToneEvent(
                int startSample, int length, double[] sample, int attackMilliseconds,
                int releaseMilliseconds, double gain)
            {
                StartSample = startSample;
                Length = length;
                Sample = sample;
                Frequencies = Array.Empty<double>();
                EndFrequencies = Array.Empty<double>();
                Timbre = Timbre.Triangle;
                AttackMilliseconds = attackMilliseconds;
                ReleaseMilliseconds = releaseMilliseconds;
                Gain = gain;
            }

            /// <summary>Non-null on a recorded event, and then it is the whole of the
            /// waveform: <see cref="Timbre"/> and the frequency fields say nothing.
            /// </summary>
            internal double[]? Sample { get; }

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

        /// <summary>One morale state's music: the chord held under it, the notes sung
        /// over it, and how fast they are sung. All five states share the envelopes and
        /// the timbre, so this is the whole of what tells them apart.</summary>
        internal sealed class MoraleVoice
        {
            /// <summary>A recording in the sounds folder which replaces the chord and
            /// phrase below entirely. Empty, or naming a file which cannot be read, and
            /// the state sings instead — which is why the written music stays here even
            /// for the states that ship with a recording.</summary>
            public string Sample { get; set; } = string.Empty;

            public int[] ChordMidi { get; set; } = Array.Empty<int>();
            public int[] MelodyMidi { get; set; } = Array.Empty<int>();

            /// <summary>Offset of the first note inside the cue, so a phrase can let its
            /// chord speak first (heroic) or crowd in from the very first sample
            /// (panic).</summary>
            public int StartMilliseconds { get; set; }
            public int NoteMilliseconds { get; set; } = 160;
            public int GapMilliseconds { get; set; } = 30;
            public double VibratoHertz { get; set; }
            public double VibratoSemitones { get; set; }

            /// <summary>A voice edited into nonsense falls back whole rather than in
            /// pieces: half a hand-tuned phrase and half a default one would be a mode
            /// nobody chose.</summary>
            internal static MoraleVoice Normalize(MoraleVoice? voice, MoraleVoice fallback)
            {
                if (voice == null
                    || !AreNotesUsable(voice.ChordMidi, 1, 4)
                    || !AreNotesUsable(voice.MelodyMidi, 1, 8))
                {
                    // The recording is the one thing kept across that fallback: a config
                    // which names a sound and no notes at all is the likeliest edit
                    // anyone will make by hand, and it must not lose the sound.
                    if (voice != null && !string.IsNullOrWhiteSpace(voice.Sample))
                    {
                        fallback.Sample = voice.Sample;
                    }
                    return fallback;
                }

                voice.Sample = voice.Sample.Trim();
                voice.StartMilliseconds = Math.Clamp(voice.StartMilliseconds, 0, 2_000);
                voice.NoteMilliseconds = Math.Clamp(voice.NoteMilliseconds, 20, 2_000);
                voice.GapMilliseconds = Math.Clamp(voice.GapMilliseconds, 0, 1_000);
                voice.VibratoHertz = Math.Clamp(voice.VibratoHertz, 0.0, 12.0);
                voice.VibratoSemitones = Math.Clamp(voice.VibratoSemitones, 0.0, 2.0);
                return voice;
            }

            private static bool AreNotesUsable(int[]? notes, int minimum, int maximum)
            {
                return notes != null
                    && notes.Length >= minimum && notes.Length <= maximum
                    && notes.All(note => note is >= 0 and <= 127);
            }
        }

        private sealed class SonarSettings
        {
            internal const string FileName = "sonar.json";

            public bool Enabled { get; set; } = true;
            public double Volume { get; set; } = 0.55;

            /// <summary>Where the recorded cues live, relative to this config unless an
            /// absolute path is given. Its own setting so a player can keep a folder of
            /// alternatives and switch sets with one line.</summary>
            public string SoundsFolder { get; set; } = "sounds";
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

            // The dead on the hex: a recording, with a high rasp behind it for when the
            // file is gone. D6 sagging to A5 — the impassable cue's texture two and a
            // half octaves up, where the ear takes it for a rattle instead of a wall,
            // which is the whole of what keeps the two rasps apart. The grain gate runs
            // faster than the impassable one for the same reason: at this pitch a slow
            // chop reads as a tremolo rather than as roughness.
            public bool CorpseEnabled { get; set; } = true;
            public string CorpseSample { get; set; } = "corpse.wav";
            public double CorpseSampleGain { get; set; } = 0.8;
            public int CorpseSampleFadeMilliseconds { get; set; } = 5;
            public int CorpseSampleMaxMilliseconds { get; set; } = 600;

            /// <summary>Where the cue sits inside the hex's waveform. Zero puts it with
            /// the ground cues it belongs to; a player who finds it crowds the unit
            /// chord can push it back without touching anything else.</summary>
            public int CorpseDelayMilliseconds { get; set; }

            public int CorpseMilliseconds { get; set; } = 250;
            public int CorpseHighMidi { get; set; } = 86;
            public int CorpseLowMidi { get; set; } = 81;
            public double CorpseVibratoHertz { get; set; } = 9.0;
            public double CorpseVibratoSemitones { get; set; } = 0.35;
            public double CorpseGrainHertz { get; set; } = 95.0;
            public double CorpseGrainDepth { get; set; } = 0.6;
            public int CorpseAttackMilliseconds { get; set; } = 4;
            public int CorpseReleaseMilliseconds { get; set; } = 40;
            public double CorpseGain { get; set; } = 0.5;

            // Morale. The delay is what keeps this cue out of the way of the two the
            // player steers by, and the length is what gives the synthesized melody room
            // to be a melody.
            public bool MoraleEnabled { get; set; } = true;
            public int MoraleDelayMilliseconds { get; set; } = 500;
            public int MoraleMilliseconds { get; set; } = 1_000;
            public double MoraleChordGain { get; set; } = 0.50;
            public double MoraleMelodyGain { get; set; } = 0.80;

            // A recording arrives already mixed and already shaped, so it gets one level
            // and one fade instead of the four envelope settings the synthesized voice
            // needs. The fade is short enough to be inaudible on a file that starts and
            // ends in silence, and long enough to stop a click on one that does not.
            //
            // The gain goes well past 1 on purpose. Cue material tends to be exported
            // with the headroom a music file wants, and the shipped set peaks around
            // -18 dBFS, which under the unit chord is not quiet but inaudible. Matching
            // it here rather than asking for a re-export means a player can drop in any
            // file and balance it by ear with one number.
            //
            // Its cap is its own rather than the melody's, so lengthening a recording
            // never silently rewrites the phrase that stands in when a file is missing.
            // The cap is what guarantees a hex stops speaking even with the cursor
            // parked on it; a file longer than this is cut, and says so at startup.
            public double MoraleSampleGain { get; set; } = 5.0;
            public int MoraleSampleFadeMilliseconds { get; set; } = 5;
            public int MoraleSampleMaxMilliseconds { get; set; } = 2_500;

            // The chord swells and dies away; the notes over it speak and stop. Their
            // envelopes are therefore nothing alike, which is most of what keeps the
            // phrase legible over its own accompaniment.
            public int MoraleAttackMilliseconds { get; set; } = 30;
            public int MoraleReleaseMilliseconds { get; set; } = 160;
            public int MoraleNoteAttackMilliseconds { get; set; } = 12;
            public int MoraleNoteReleaseMilliseconds { get; set; } = 45;

            // MIDI 50 is D3. Every mode is written over that same D except wavering,
            // which is the A minor the player asked for; see AddMoraleEvents for what
            // each phrase is saying.
            public MoraleVoice MoraleConfident { get; set; } = DefaultConfident();
            public MoraleVoice MoraleSteady { get; set; } = DefaultSteady();
            public MoraleVoice MoraleWavering { get; set; } = DefaultWavering();
            public MoraleVoice MoraleBreaking { get; set; } = DefaultBreaking();
            public MoraleVoice MoraleFleeing { get; set; } = DefaultFleeing();

            /// <summary>D dorian: Dm spread wide, then D-F-A-B-D climbing through the
            /// natural sixth to the octave.</summary>
            private static MoraleVoice DefaultConfident()
            {
                return new MoraleVoice
                {
                    Sample = "morale-confident.wav",
                    ChordMidi = new[] { 50, 57, 65 },
                    MelodyMidi = new[] { 62, 65, 69, 71, 74 },
                    StartMilliseconds = 60,
                    NoteMilliseconds = 160,
                    GapMilliseconds = 30,
                };
            }

            /// <summary>A bare fifth, D and A, unhurried and without a third.</summary>
            private static MoraleVoice DefaultSteady()
            {
                return new MoraleVoice
                {
                    Sample = "morale-steady.wav",
                    ChordMidi = new[] { 50, 57, 62 },
                    MelodyMidi = new[] { 62, 69 },
                    StartMilliseconds = 100,
                    NoteMilliseconds = 380,
                    GapMilliseconds = 60,
                };
            }

            /// <summary>A minor, A-B-C-B circling back onto the second degree and
            /// staying there, trembling.</summary>
            private static MoraleVoice DefaultWavering()
            {
                return new MoraleVoice
                {
                    Sample = "morale-wavering.wav",
                    ChordMidi = new[] { 45, 52, 60 },
                    MelodyMidi = new[] { 69, 71, 72, 71 },
                    StartMilliseconds = 80,
                    NoteMilliseconds = 190,
                    GapMilliseconds = 40,
                    VibratoHertz = 5.5,
                    VibratoSemitones = 0.35,
                };
            }

            /// <summary>Dm voiced close and dark, with Eb-C#-D over it: the flat second
            /// of phrygian falling a diminished third onto harmonic minor's leading note,
            /// then an octave down to the tonic.</summary>
            private static MoraleVoice DefaultBreaking()
            {
                return new MoraleVoice
                {
                    Sample = "morale-breaking.wav",
                    ChordMidi = new[] { 50, 53, 57 },
                    MelodyMidi = new[] { 75, 73, 62 },
                    StartMilliseconds = 20,
                    NoteMilliseconds = 300,
                    GapMilliseconds = 40,
                };
            }

            /// <summary>D locrian over the diminished triad D-F-Ab: D-Eb-F-Ab-G, fast,
            /// reaching the flat fifth and refusing to come back down to the tonic.
            /// </summary>
            private static MoraleVoice DefaultFleeing()
            {
                return new MoraleVoice
                {
                    Sample = "morale-fleeing.wav",
                    ChordMidi = new[] { 50, 53, 56 },
                    MelodyMidi = new[] { 74, 75, 77, 80, 79 },
                    StartMilliseconds = 0,
                    NoteMilliseconds = 130,
                    GapMilliseconds = 45,
                    VibratoHertz = 7.0,
                    VibratoSemitones = 0.30,
                };
            }

            /// <summary>Map the engine's Const.MoraleState index onto its voice.</summary>
            internal MoraleVoice? MoraleVoiceFor(string morale)
            {
                return morale switch
                {
                    "0" => MoraleFleeing,
                    "1" => MoraleBreaking,
                    "2" => MoraleWavering,
                    "3" => MoraleSteady,
                    "4" => MoraleConfident,
                    _ => null,
                };
            }

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

                if (string.IsNullOrWhiteSpace(CorpseSample)) CorpseSample = string.Empty;
                CorpseSample = CorpseSample.Trim();
                CorpseSampleGain = Math.Clamp(CorpseSampleGain, 0.0, 16.0);
                CorpseSampleFadeMilliseconds = ClampTime(CorpseSampleFadeMilliseconds, 0, 500);
                CorpseSampleMaxMilliseconds = ClampTime(CorpseSampleMaxMilliseconds, 40, 2_000);
                // A ground cue that started after the hex had finished speaking would be
                // heard as belonging to the next hex, so its delay is capped well short
                // of the morale phrase rather than at the same two seconds.
                CorpseDelayMilliseconds = ClampTime(CorpseDelayMilliseconds, 0, 500);
                CorpseMilliseconds = ClampTime(CorpseMilliseconds, 40, 2_000);
                CorpseHighMidi = ClampNote(CorpseHighMidi, 86);
                CorpseLowMidi = ClampNote(CorpseLowMidi, 81);
                // The fall is the message. A pair written the other way up would glide
                // upwards and say the impassable cue's line instead of this one.
                if (CorpseLowMidi > CorpseHighMidi) CorpseLowMidi = CorpseHighMidi;
                CorpseVibratoHertz = Math.Clamp(CorpseVibratoHertz, 0.0, 40.0);
                CorpseVibratoSemitones = Math.Clamp(CorpseVibratoSemitones, 0.0, 2.0);
                CorpseGrainHertz = Math.Clamp(CorpseGrainHertz, 0.0, 400.0);
                CorpseGrainDepth = Math.Clamp(CorpseGrainDepth, 0.0, 1.0);
                CorpseAttackMilliseconds = ClampTime(CorpseAttackMilliseconds, 0, 200);
                CorpseReleaseMilliseconds = ClampTime(CorpseReleaseMilliseconds, 0, 200);
                CorpseGain = Math.Clamp(CorpseGain, 0.0, 1.0);

                // The cue is context rather than navigation, so it may be pushed later
                // or made longer, but never so far that the player is still hearing the
                // last hex when they reach the next one.
                MoraleDelayMilliseconds = ClampTime(MoraleDelayMilliseconds, 0, 2_000);
                MoraleMilliseconds = ClampTime(MoraleMilliseconds, 100, 4_000);
                MoraleChordGain = Math.Clamp(MoraleChordGain, 0.0, 1.0);
                MoraleMelodyGain = Math.Clamp(MoraleMelodyGain, 0.0, 1.0);
                MoraleAttackMilliseconds = ClampTime(MoraleAttackMilliseconds, 0, 500);
                MoraleReleaseMilliseconds = ClampTime(MoraleReleaseMilliseconds, 0, 1_000);
                MoraleNoteAttackMilliseconds = ClampTime(MoraleNoteAttackMilliseconds, 0, 200);
                MoraleNoteReleaseMilliseconds = ClampTime(MoraleNoteReleaseMilliseconds, 0, 500);

                MoraleSampleGain = Math.Clamp(MoraleSampleGain, 0.0, 16.0);
                MoraleSampleFadeMilliseconds = ClampTime(MoraleSampleFadeMilliseconds, 0, 500);
                MoraleSampleMaxMilliseconds = ClampTime(MoraleSampleMaxMilliseconds, 100, 6_000);
                if (string.IsNullOrWhiteSpace(SoundsFolder)) SoundsFolder = "sounds";
                SoundsFolder = SoundsFolder.Trim();

                MoraleConfident = MoraleVoice.Normalize(MoraleConfident, DefaultConfident());
                MoraleSteady = MoraleVoice.Normalize(MoraleSteady, DefaultSteady());
                MoraleWavering = MoraleVoice.Normalize(MoraleWavering, DefaultWavering());
                MoraleBreaking = MoraleVoice.Normalize(MoraleBreaking, DefaultBreaking());
                MoraleFleeing = MoraleVoice.Normalize(MoraleFleeing, DefaultFleeing());
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

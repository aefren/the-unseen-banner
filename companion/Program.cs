using TheUnseenBanner.Companion;

const string ModName = "The Unseen Banner";
const string ModVersion = "0.1";

// TODO: read from a config file once one exists (roadmap 5.1); "en" for now.
L10n.Init(L10n.DefaultLanguage);

Console.WriteLine($"{ModName} companion — v{ModVersion}");
Console.WriteLine("Loading Tolk...");

Speech.Init();
Speech.Speak(L10n.F("companion.loaded", ModVersion));

Console.WriteLine("Press Enter to exit.");
Console.ReadLine();

Speech.Shutdown();

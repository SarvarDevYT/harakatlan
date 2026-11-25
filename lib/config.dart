/// Build switches, set with --dart-define when running or building.
///
/// By default the app plays online against real players on the game server.
///   flutter run --dart-define=ONLINE=false     # offline demo with sample rivals
///   flutter run --dart-define=SERVER=http://localhost:3000   # a local server
const bool kOnline = bool.fromEnvironment('ONLINE', defaultValue: true);
const String kServerUrl = String.fromEnvironment('SERVER', defaultValue: 'https://qadam-qala.vercel.app');
const String kCartoApiKey = String.fromEnvironment('CARTO_API_KEY');

/// Dirección de la API Laravel. Se puede reemplazar al ejecutar Flutter:
/// --dart-define=API_BASE_URL=http://localhost:8000/api
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.0.105:8000/api',
);

# Yazzoki — Flutter App

Social platform with a Japanese old-age aesthetic — **app (cliente Flutter)**.

> **Backend separado**: o servidor agora está em
> [Souzzaaxzy/ServidorYazzoki](https://github.com/Souzzaaxzy/ServidorYazzoki).
> Para rodar o backend localmente em container, clone aquele repositório
> e execute `docker compose up -d --build`.

## O que é este repositório

Apenas o app Flutter (camada de apresentação). Ele consome a API do
backend Yazzoki e **não** contém código de servidor.

## Identidade visual

- **Paleta**: preto tinta, branco/off-white (papel washi), bege e azul cor de
  gelo — tema claro e escuro em `app/lib/app/theme/`.
- **Logo**: emblema caligráfico (pincel) em `app/assets/brand/`; o lockup
  (emblema + nome) é o widget `YazzokiLogo`.
- **Tipografia**: Inter (UI), JetBrains Mono (HUD) e Zen Old Mincho (display).
- **Application ID**: `com.yazzoki.app`; label Android `Yazzoki`.

## Configurar o endereço do backend

O app fala com **UMA única API**: o ServidorYazzoki hospedado na
Bronxys/Pterodactyl. A URL oficial é resolvida em
`app/lib/data/api_config.dart`:

| Modo | Endereço |
|------|----------|
| Release (APK) | `--dart-define=API_BASE_URL=...` (o CI injeta a partir do secret `API_BASE_URL`) |
| Debug (emulador Android) | `http://10.0.2.2:3000` |

A URL de produção é o endereço público REAL da alocação do servidor no
painel da Bronxys — IP/host do node + porta alocada (ex.:
`http://123.45.67.89:4316`). HTTPS somente se o painel fornecer um
domínio com SSL válido. **Nunca** localhost, 127.0.0.1, 0.0.0.0 ou URLs de
túneis/serviços externos. Passos completos:
[CONEXAO_APP.md no ServidorYazzoki](https://github.com/Souzzaaxzy/ServidorYazzoki/blob/main/CONEXAO_APP.md).

Para apontar para um servidor diferente (dev):
```bash
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000
```

## Comandos (dentro de `app/`)

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## CI

`.github/workflows/android.yml` — usa `working-directory: app`.
Pipeline: checkout → JDK 21 → Flutter → pub get → analyze → test → build apk.

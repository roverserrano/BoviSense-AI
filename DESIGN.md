# BoviSense-AI — Sistema de diseño visual

Identidad visual aprobada para la aplicación Android (Flutter). Este documento es
la referencia de diseño; el código fuente de los tokens vive en
`frontend/lib/core/theme/` y no debe duplicarse en otras capas.

- Tokens de color: `frontend/lib/core/theme/app_colors.dart`
- Escala tipográfica: `frontend/lib/core/theme/app_typography.dart`
- Tema Material 3 y dimensiones: `frontend/lib/core/theme/app_theme.dart`
- Componentes compartidos: `frontend/lib/views/common/bovisense_ui.dart`
- Componentes del ganadero: `frontend/lib/views/ganadero/widgets/ganadero_widgets.dart`

## 1. Identidad

BoviSense combina ganadería, visión artificial y sistemas embebidos. La interfaz
comunica: tecnología confiable, simplicidad de campo y cercanía al sector
ganadero. Se evitan degradados decorativos, efectos de vidrio, ilustraciones de
relleno y animaciones innecesarias: la calidad se concentra en jerarquía,
legibilidad y estados honestos.

Contexto de uso: teléfono Android en exteriores, a pleno sol, con usuarios no
técnicos, en postura física incómoda (a veces con una sola mano). De ahí:

- Contraste alto y texto grande donde importa.
- Áreas táctiles cómodas (mínimo 48 × 48 dp).
- Mensajes con causa y solución, sin jerga técnica.
- Estados del prototipo siempre visibles y fieles al sistema real.

## 2. Paleta

| Token | Hex | Uso |
| --- | --- | --- |
| `primary` | `#185441` | Acciones principales, icono de marca, puntos de estado activo |
| `primaryDark` | `#10382E` | Barras superiores, tarjetas de marca, snackbars |
| `primaryLight` | `#E5F0E9` | Selecciones suaves, contenedores de fondo |
| `accent` | `#D4A447` | Acento decorativo y botón sobre fondo oscuro (solo relleno) |
| `accentStrong` | `#8A6220` | Texto dorado legible sobre blanco |
| `background` | `#F7F9F6` | Fondo general de pantalla |
| `surface` | `#FFFFFF` | Tarjetas y campos |
| `surfaceAlt` | `#F0F4F1` | Contenedores secundarios, chips neutros |
| `border` | `#DCE5DE` | Bordes de tarjetas y separadores suaves |
| `borderStrong` | `#788D81` | Bordes de controles (campos): ≥ 3:1 vs blanco |
| `textPrimary` | `#1B2B22` | Texto principal |
| `textSecondary` | `#46594E` | Texto secundario |
| `muted` | `#5A6E61` | Texto auxiliar y etiquetas |
| `textDisabled` | `#75887D` | Estados deshabilitados |
| `success` / `successBg` | `#1F6B47` / `#E6F4EC` | Conteo correcto, guardado, conexión lista |
| `warning` / `warningBg` | `#7A5312` / `#FBF0DA` | Faltantes, paso pendiente, atención moderada |
| `error` / `errorBg` | `#8C2B24` / `#FBE9E7` | Falla del equipo, validaciones, excedentes |
| `info` / `infoBg` | `#17556E` / `#E4F1F7` | Notas informativas |
| `danger` | `#A63A2F` | Botones destructivos (eliminar) |

Contrastes verificados (WCAG 2.2, relación ≥ 4.5:1 para texto normal):

| Combinación | Relación |
| --- | --- |
| `textPrimary` sobre `background` | 14.0:1 |
| `textSecondary` sobre `surface` | 7.5:1 |
| `muted` sobre `background` | 5.2:1 |
| `onPrimary` sobre `primary` | 8.8:1 |
| `success` sobre `successBg` | 5.7:1 |
| `warning` sobre `warningBg` | 6.0:1 |
| `error` sobre `errorBg` | 7.2:1 |
| `info` sobre `infoBg` | 7.1:1 |
| `accent` sobre `primaryDark` (relleno con texto oscuro) | 5.7:1 |

Reglas:
- Ningún color se declara dentro de una pantalla: siempre desde los tokens.
- El estado nunca se comunica solo con color: cada color va acompañado de texto
  o iconografía.
- `accent` puro jamás se usa como texto sobre superficies claras.

## 3. Tipografía

Familia: la del sistema (Roboto en Android). Sin dependencias externas.

| Estilo | Tamaño / peso | Uso |
| --- | --- | --- |
| `displayLarge` | 44 / w700 | Número del resultado de conteo |
| `displaySmall` | 28 / w700 | Métricas grandes |
| `headlineLarge` | 26 / w700 | Título de marca (splash) |
| `headlineSmall` | 19 / w600 | Títulos de pantalla dentro de la vista |
| `titleLarge` | 18 / w600 | Título en barras superiores y tarjetas de marca |
| `titleMedium` / `titleSmall` | 16–14.5 / w600 | Títulos de tarjeta y bloques |
| `bodyLarge` / `bodyMedium` | 15 / 14, w400 | Texto de párrafo |
| `bodySmall` | 12.5 / w400 | Texto auxiliar |
| `labelLarge` | 15 / w600 | Botones |
| `labelMedium` / `labelSmall` | 13 / 11.5, w600 | Etiquetas y chips |
| Sección (mayúsculas) | 12 / w700, +0.8 | Encabezados `RESUMEN`, `ALERTAS` |
| Técnico | 11.5 monoespaciada | Trazas en "Detalles técnicos" |

Los números que cambian en vivo (conteo) usan cifras tabulares para evitar
saltos de ancho.

## 4. Espaciado y formas

- Base de 4: `4 · 8 · 12 · 16 · 24 · 32`.
- Separación entre tarjetas: 10–12; entre secciones: 16.
- Radios: 12 (controles), 16 (tarjetas), 20 (diálogos), 999 (pills).
- Profundidad: tarjetas con borde de 1 px, sin sombra; sombra sol suave solo en
  elementos flotantes (barra inferior, FAB, tarjeta de próximo paso).

## 5. Componentes

| Componente | Rol | Estados |
| --- | --- | --- |
| `AppTopBar` | Barra superior unificada (`primaryDark`) | estático |
| `BoviCard` | Tarjeta base con borde suave | normal, táctil |
| `SectionTitle` | Encabezado de sección en mayúsculas | estático |
| `PrimaryButton` | Acción principal; ancho completo | normal, cargando, deshabilitado |
| `OutlineActionButton` | Acción secundaria | normal, deshabilitado |
| `StopButton` | Acción de detener conteo (tonal rojo) | normal, deshabilitado |
| `StatusBar` | Estado principal de pantalla con punto y subtítulo | pending, ready, inProgress, finished, error |
| `StatusBanner` / `AlertCard` | Mensaje con icono, título y detalle | info, success, warning, error |
| `StatusChip` | Etiqueta corta de estado | color semántico + texto |
| `StatCard` | Métrica con número y etiqueta | normal, con chip |
| `EmptyState` | Estado vacío con icono, título y acción | normal |
| `ResultHero` | Resultado del conteo con métricas | en curso, final |
| `StepFlowItem` | Paso del flujo de conteo | completado, activo, pendiente |
| `HistoryItem` | Fila del historial | exacto, faltante, excedente |
| `NextStepCard` | Siguiente acción sugerida | estático |
| `TechnicalDetails` | Trazas técnicas plegables | vacío, con líneas |
| `GanaderoBottomNavBar` | Navegación inferior del ganadero | 4 destinos |

## 6. Estados por pantalla

Toda pantalla con datos remotos contempla: cargando, vacío, error con reintento
y contenido. Toda pantalla con hardware contempla: sin conexión, conectando,
conectado, esperando confirmación, en progreso, error y recuperación.

## 7. Accesibilidad

- Texto normal ≥ 4.5:1; texto grande ≥ 3:1; bordes de control ≥ 3:1.
- Objetivos táctiles ≥ 48 × 48 dp (chips y botones incluidos).
- Iconografía siempre acompañada de etiqueta textual o semántica.
- La UI tolera escalado de texto (hasta 130 %) sin desbordes; los números
  grandes usan `FittedBox` cuando el espacio puede comprimirse.
- Mensajes con causa y acción ("Activa el Bluetooth", "Abrir ajustes").
- Las animaciones son breves (≤ 220 ms) y funcionales.

## 8. Reglas de mantenimiento

1. Un color nuevo exige token en `AppColors` y verificación de contraste.
2. Un componente usado por dos roles vive en `views/common/bovisense_ui.dart`.
3. No se crean estados simulados: la UI solo muestra lo que el sistema confirma.
4. Ninguna pantalla redefine estilos de botones, campos o tarjetas: eso vive en
   el tema.
5. El protocolo BLE/LoRa, la lógica de conteo y los contratos del backend no se
   tocan por razones visuales.

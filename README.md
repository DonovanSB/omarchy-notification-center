# Centro de notificaciones de Donovan

Plugin de Omarchy con grupos plegables por aplicación, inspirado en el centro de
notificaciones de GNOME/Fedora. Usa el servicio `omarchy.notifications` existente.

- Grupo cerrado: una tarjeta apilada, con el mensaje más reciente y el total.
  Pulsa la tarjeta o su flecha para abrir el grupo; no aparece cabecera separada.
- Grupo abierto: cabecera con nombre de la aplicación, botón para contraer y ×
  para descartar el grupo, seguida de todas sus tarjetas. Un mensaje aislado
  aparece como tarjeta normal, sin cabecera de grupo.
- Contador por aplicación, marca de no leídas y aviso de urgentes incluso plegados.
- Búsqueda por aplicación, título o mensaje; despliega los resultados automáticamente.
- Historial persistente (30 días / 1000 entradas por defecto), imágenes y vista previa.
- No molestar desde la cabecera o con clic derecho en la campana.
- Limpiar una notificación, un grupo o todo. En búsqueda, la × del grupo limpia
  solamente sus coincidencias; «Limpiar» en la cabecera siempre limpia todo.
- La flecha de una tarjeta individual expande/contrae el texto completo. Pulsar
  su contenido abre la imagen asociada o enfoca la aplicación.
- La × de una pila cerrada descarta todo el grupo; la × de una tarjeta individual
  descarta solo ese mensaje. La descripción al pasar el cursor indica el alcance.
- Teclado: `/` busca, Escape sale de búsqueda/cierra, ↑/↓ seleccionan,
  ←/→ contraen/despliegan, Enter abre la pila o actúa sobre el mensaje,
  `x` descarta la pila o tarjeta seleccionada.
- Un único servicio de archivo para todos los monitores.

## Instalación local

```bash
omarchy plugin validate .
python3 install.py
```

El instalador copia el plugin a `~/.config/omarchy/plugins/donovan.notification-center/`,
respalda `shell.json`, importa una copia del archivo de jankeesvw (si existe) y
sustituye las dos campanas anteriores. No desinstala los otros plugins.

Abrir desde un atajo o terminal:

```bash
omarchy-shell donovan.notification-center toggle
```

Ajustes en la interfaz de widgets de Omarchy, o en la entrada del plugin en
`~/.config/omarchy/shell.json`: `collapsed`, `badge` (Dot/Highlight/Count/None),
`keepDays`, `maxItems`, `showBody`, `showPreview`, `panelWidth`, `listHeight`,
`clickAction` (Auto/Focus the app/Nothing).

## Archivo y comportamiento

`~/.local/state/donovan-notification-center/` (respeta `XDG_STATE_HOME`).
Permisos 0700 para carpetas y 0600 para datos. Las acciones almacenadas nunca se
ejecutan; solo se conserva una ruta de imagen para abrirla como argumento.
Limpiar todo oculta entradas anteriores a ese instante hasta que la retención
las elimina. Descartar una entrada elimina su copia y añade una marca para no
reimportarla. No se borran archivos del servicio de notificaciones de Omarchy.

Descartar una entrada o grupo limpia su archivo; el toast activo sigue su duración
normal. «Limpiar» también descarta todos los toasts mediante el IPC oficial.
Omarchy 4.0.4 no expone descarte individual por identidad a plugins externos.
No molestar también usa IPC oficial, sin acceder a servicios privados.

El archivo observa los JSON de Omarchy con `inotifywait`; los mensajes aparecen
cuando el servicio termina de guardarlos. Las notificaciones efímeras que Omarchy
no escribe no pueden recuperarse. El historial anterior disponible se importa;
no se pueden reconstruir mensajes que los plugins anteriores ya eliminaron.

Dependencias habituales de Omarchy: bash, jq, inotify-tools, util-linux, file,
coreutils y Quickshell. ImageMagick es opcional para reducir vistas previas.
Python 3 solo se necesita para instalar y ejecutar las pruebas.

## Desarrollo y verificación

```bash
node tests/grouping.test.cjs
python3 -m unittest discover -s tests -v
omarchy plugin validate .
mkdir -p /tmp/donovan-qml-imports
ln -sfn /usr/share/omarchy/shell /tmp/donovan-qml-imports/qs
/usr/lib/qt6/bin/qmllint -I /tmp/donovan-qml-imports Panel.qml Service.qml components/*.qml
```

El lint de Qt 6 emite avisos de tipos dinámicos del host (`QObject`, `Style.font`)
y de metadatos `QProcess::ExitStatus` de Quickshell. La carga real se verifica
dentro de Omarchy. Si la recarga conserva QML antiguo, `omarchy restart shell`
actualiza la caché.

Vuelve a ejecutar `install.py` para aplicar cambios desde esta carpeta. No inicia
otra instancia de Quickshell. Para consultar el estado, sin contenido privado:

```bash
omarchy-shell donovan.notification-center.archive state
```

Para volver al diseño anterior, restaura la copia `shell.json.before-donovan-notifications-*`
que imprime el instalador. La configuración se recarga automáticamente.

## Créditos y referencias

Derivado de la UI y el archivo de **Jankees van Woezik**, con la integración del
servicio de notificaciones de **Shavanced**; ambos bajo MIT, avisos conservados
en LICENSE. Se adaptaron agrupación, teclado, idioma, actualizaciones del archivo,
retención, borrado sin modificar archivos fuente y sincronización de operaciones.

- https://github.com/jankeesvw/omarchy-notification-center
- https://github.com/Shavanced/omarchy-notification-center-plugin
- https://omarchy.org/manual/shell-plugins/
- https://plugins.omarchy.org/develop.html
- Contrato de la versión instalada: `/usr/share/omarchy/shell/README.md`.

### Referencia adicional: Omapager

Se revisó https://github.com/ryanrhughes/omapager (5cde92a, MIT) y su referencia
`njpatel.omapager` en el marketplace. Su presentación en pilas inspiró las capas
visuales. La interacción de la versión 0.2 sigue las capturas de Fedora/GNOME
proporcionadas: pila cerrada, cabecera al expandir y controles por tarjeta.
La implementación de estos controles es propia.
Omapager reemplaza el daemon; este proyecto conserva `omarchy.notifications`.
Las respuestas inline, acciones de mensajes y pausa por origen de Omapager
requieren control del daemon y no forman parte de este centro de historial.

"""Genera el informe técnico y su fuente Word a partir del mismo contenido.

Requiere el runtime documental con python-docx, ReportLab y Pillow.
No accede a Firebase ni incorpora configuración privada.
"""
from pathlib import Path
from html import escape
from io import BytesIO
import json

from PIL import Image as PILImage
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Spacer, Table,
                               TableStyle, Image, PageBreak, KeepTogether)
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Polygon
from reportlab.graphics import renderPDF
import pypdfium2 as pdfium

ROOT = Path(__file__).resolve().parents[1]
PDF = ROOT / 'output/pdf/Informe_tecnico_PetVerse.pdf'
DOCX = ROOT / 'output/doc/Informe_tecnico_PetVerse.docx'
QA = ROOT / 'tmp/report'
for folder in (PDF.parent, DOCX.parent, QA):
    folder.mkdir(parents=True, exist_ok=True)
FONT_DIR = Path('C:/Windows/Fonts')
for name, file in [('Calibri', 'calibri.ttf'), ('Calibri-Bold', 'calibrib.ttf'),
                   ('Calibri-Italic', 'calibrii.ttf')]:
    pdfmetrics.registerFont(TTFont(name, str(FONT_DIR / file)))
pdfmetrics.registerFontFamily('Calibri', normal='Calibri', bold='Calibri-Bold', italic='Calibri-Italic')
NAVY = '#233E55'
GRAY = '#56616B'
PALE = '#F2F5F7'


def diagram():
    d = Drawing(504, 192)
    def box(x, y, w, h, title, desc, fill=PALE):
        d.add(Rect(x, y, w, h, fillColor=colors.HexColor(fill), strokeColor=colors.HexColor('#B8C4CC'), strokeWidth=.6))
        d.add(String(x+w/2, y+h-19, title, textAnchor='middle', fontName='Calibri-Bold', fontSize=11, fillColor=colors.HexColor(NAVY)))
        d.add(String(x+w/2, y+12, desc, textAnchor='middle', fontName='Calibri', fontSize=9, fillColor=colors.black))
    def arrow(x1, y1, x2, y2):
        d.add(Line(x1,y1,x2,y2,strokeColor=colors.HexColor(NAVY),strokeWidth=.8))
        d.add(Polygon([x2-3,y2+5,x2+3,y2+5,x2,y2],fillColor=colors.HexColor(NAVY),strokeColor=None))
    box(0,141,245,46,'Presentación','screens · widgets · formularios')
    box(259,141,245,46,'Estado de aplicación','providers · sesión · streams · errores')
    d.add(Line(245,164,259,164,strokeColor=colors.HexColor(NAVY)))
    box(0,71,504,49,'Servicios y modelos de dominio','Contratos comunes · adaptadores Firebase o demo en memoria')
    arrow(122,141,122,120); arrow(382,141,382,120)
    for x, title, desc in [(0,'Firebase Auth','Identidad'),(172,'Cloud Firestore','Documentos y reglas'),(344,'Storage y Functions','Integración preparada')]:
        box(x,0,160,47,title,desc)
        arrow(x+80,71,x+80,47)
    return d


def p(text): return ('p', text)
def h(text): return ('h', text)
def t(headers, rows, widths): return ('t', headers, rows, widths)
def cap(text): return ('cap', text)
def image(path, width, height): return ('img', str(path), width, height)


PAGES = [
('1 Resumen del proyecto', [
 p('PetVerse es una aplicación web progresiva desarrollada con Flutter Web y Firebase para administrar perfiles y mascotas, compartir publicaciones, gestionar avisos de adopción y mantener conversaciones privadas. La solución separa la interfaz, el estado de aplicación y el acceso a los datos para poder verificar cada responsabilidad sin depender de una única sesión de producción.'),
 p('El frontend está publicado en Firebase Hosting y su acceso público por HTTPS fue comprobado el 20 de octubre de 2026. La verificación alcanzó la página de entrada y los artefactos principales del despliegue. No se realizaron nuevas operaciones con cuentas reales ni una auditoría de la configuración remota de Firebase durante la elaboración de este informe.'),
 h('Objetivo y alcance'),
 p('El objetivo general es implementar una red social de mascotas con persistencia, actualizaciones en tiempo real y una experiencia adaptable a distintos dispositivos. El trabajo desarrolla los catorce puntos de verificación de la consigna y documenta por separado el código existente, su validación local y la activación efectiva de los servicios externos.'),
 p('El alcance acordado excluye Apple como proveedor de acceso y utiliza Firebase Hosting en lugar de Vercel. Se mantiene el proyecto sin facturación. Por esa decisión, la subida a Cloud Storage permanece desactivada y el backend de notificaciones automáticas no está desplegado. Estas restricciones afectan el cumplimiento operativo de PV8 y PV10 y no se consideran resueltas por disponer del código.'),
 h('Organización del informe'),
 ('contents', [
  '2 y 3  Trazabilidad de requisitos y alcance funcional',
  '4  Arquitectura y organización del código',
  '5 y 6  Modelo de datos y consistencia transaccional',
  '7  Seguridad y privacidad',
  '8  Gamificación',
  '9  PWA y diseño adaptable',
  '10  Despliegue y operación',
  '11  Estrategia de pruebas y resultados',
  '12  Evidencia visual',
  '13  Dificultades y riesgos pendientes',
  '14  Conclusiones y fuentes de referencia']),
]),
('2 Trazabilidad de PV1 a PV7', [
 p('La matriz relaciona cada requisito con el comportamiento implementado y la evidencia disponible. “Implementado” describe el código y las verificaciones indicadas; no implica que se hayan repetido todos los escenarios sobre el backend publicado.'),
 t(['PV', 'Requisito', 'Implementación y verificación'], [
 ['PV1', 'Autenticación', 'Registro y acceso con correo y contraseña, recuperación de contraseña y Google mediante Firebase Auth. Rutas privadas protegidas por la sesión. El acceso real fue confirmado durante la configuración; las pruebas automatizadas ejercitan el adaptador demo. Apple está excluido del alcance.'],
 ['PV2', 'Perfil editable', 'Nombre, fotografía, biografía y lista de mascotas del titular. Se separa el perfil privado del directorio público mínimo. Las reglas impiden que terceros accedan al documento privado.'],
 ['PV3', 'Registro de mascotas', 'Alta y edición de nombre, tipo, raza, edad, peso, fotografías y biografía. Las mascotas quedan bajo users/{uid}/pets. Los flujos de formularios se comprueban en pruebas de widgets.'],
 ['PV4', 'Feed de publicaciones', 'Contenido con imagen o video, texto, autor, mascota asociada y fecha del servidor. Consulta ordenada por createdAt descendente y escucha mediante snapshots de Firestore. Admite medios mediante URL.'],
 ['PV5', 'Likes en tiempo real', 'Reacción por botón o doble toque, animación y contador derivado de los UID que reaccionaron. Transformaciones atómicas y transacción para el crédito de puntos. Se prueban concurrencia e idempotencia.'],
 ['PV6', 'Comentarios', 'Alta, lectura en tiempo real y eliminación exclusiva por su autor. Mensajes de hasta 1000 caracteres. Los emuladores verifican suplantación rechazada y recepción entre dos clientes.'],
 ['PV7', 'Adopciones', 'Grilla con filtros combinados por tipo, edad y ubicación; detalle y formulario de contacto. El contacto abre mensajería privada con el responsable. El propietario puede cerrar el aviso.'],
 ], [34, 106, 364]),
 h('Integración de los módulos'),
 p('La mascota registrada es la referencia para crear publicaciones y avisos de adopción. La identidad se toma de la sesión activa; no se confía únicamente en el usuario indicado por un formulario. El contacto desde una adopción reutiliza el mismo servicio de conversaciones que el directorio de usuarios, evitando mantener dos historiales independientes.'),
]),
('3 Trazabilidad de PV8 a PV14', [
 t(['PV', 'Requisito', 'Implementación y estado operativo'], [
 ['PV8', 'Subida de archivos', 'Selector local, validación, progreso y adaptador Firebase Storage implementados. Reglas y subida comprobadas en emulador. Desactivado en la configuración de producción mientras se mantenga la decisión de no habilitar facturación. Una URL externa no sustituye la subida solicitada.'],
 ['PV9', 'Mensajería privada', 'Conversaciones individuales con historial Firestore y escucha en vivo. Participantes inmutables y escritura atómica del mensaje y resumen. Las pruebas rechazan lectura por terceros y falsificación de remitente.'],
 ['PV10', 'Notificaciones push', 'Cliente FCM, clave pública VAPID, worker y funciones para likes, comentarios y mensajes preparados. Se prueban ayudantes de generación de avisos. Las funciones no están desplegadas y no se acredita una notificación automática recibida en producción.'],
 ['PV11', 'Gamificación', 'Puntos por acciones válidas, niveles e insignias derivados de créditos únicos. Reglas y pruebas impiden duplicación, edición de créditos y totales arbitrarios.'],
 ['PV12', 'PWA instalable', 'Manifest, iconos, worker propio, flujo de instalación y página sin conexión. Se prueban assets y eventos del prompt. La instalación final en el sistema operativo sobre la URL pública queda como aceptación manual.'],
 ['PV13', 'Diseño adaptable', 'Navegación inferior o lateral según el ancho, formularios flexibles y grillas adaptables. Pruebas de widgets aprobadas a 320, 768 y 1440 píxeles de ancho. No equivale a una auditoría de accesibilidad.'],
 ['PV14', 'Publicación', 'Frontend alojado en Firebase Hosting. HTTPS y artefactos principales responden HTTP 200. La publicación de Hosting no despliega por sí sola las reglas, Storage ni Cloud Functions.'],
 ], [34, 106, 364]),
 h('Criterio de cierre de la actividad'),
 p('La versión publicada permite presentar el frontend y los módulos respaldados por Firestore y Authentication. Para acreditar íntegramente la consigna todavía debe demostrarse una subida real desde el dispositivo, al menos una notificación push automática y la instalación de la PWA. También deben completarse las capturas de los módulos restantes y el video de dos a tres minutos solicitado para la entrega.'),
]),
('4 Arquitectura de la solución', [
 p('La aplicación adopta una arquitectura por capas con backend administrado. Flutter ejecuta la presentación en el navegador; Firebase Auth administra la identidad y Firestore persiste documentos y distribuye cambios. El acceso directo del cliente a Firebase hace que las reglas de seguridad sean parte del diseño del backend, no una validación opcional de la interfaz.'),
 ('diagram',),
 cap('Figura 1  Dependencias de la aplicación. Storage y Cloud Functions tienen código preparado, pero su activación productiva permanece pendiente.'),
 h('Responsabilidades del código'),
 p('models contiene las entidades y la reconstrucción desde documentos. services define contratos y concentra consultas, escrituras y transacciones. providers expone estados de carga, error y sesión a través de Provider. screens y widgets presentan esos estados y capturan acciones del usuario. main.dart compone las dependencias y decide qué adaptadores se utilizan.'),
 p('Los servicios Firebase y los servicios demo implementan contratos comunes, por ejemplo FeedService. Esto permite comprobar formularios e interacciones con datos en memoria y reservar los emuladores para validar reglas y persistencia. Los datos demo se pierden al recargar y no representan documentos existentes en el proyecto real.'),
 h('Ciclo de vida del estado'),
 p('Los providers cancelan suscripciones al cambiar de usuario o destruirse. Los flujos sensibles utilizan controles de generación para descartar respuestas de una sesión anterior. La puerta de acceso de la aplicación retira las pantallas privadas cuando finaliza la sesión. Así se evita que una respuesta tardía muestre publicaciones o puntos de otra cuenta.'),
]),
('5 Modelo de identidad y contenido', [
 p('Firestore se organiza en documentos y subcolecciones. El UID de Firebase Auth vincula la identidad con la información del dominio, pero la contraseña y las credenciales del proveedor no se guardan en los documentos de la aplicación. Las fechas de nuevas acciones sociales se generan en el servidor para no depender del reloj del dispositivo.'),
 t(['Ruta lógica', 'Datos principales', 'Relación y visibilidad'], [
 ['users/{uid}', 'Nombre, email, photoUrl, bio y createdAt.', 'Perfil privado. Lectura y escritura únicamente del titular.'],
 ['users/{uid}/pets/{petId}', 'ownerId, nombre, tipo, raza, edad, peso, photos, bio y fecha.', 'Uno a muchos desde usuario. Colección privada del propietario.'],
 ['publicProfiles/{uid}', 'Solo name y photoUrl.', 'Proyección mínima del perfil, visible a miembros autenticados. Excluye email.'],
 ['posts/{postId}', 'ownerId, autor, petId, petName, caption, imageUrl, mediaType, createdAt y likes.', 'Documento social visible a usuarios autenticados. imageUrl también referencia videos.'],
 ['posts/{postId}/comments/\n{commentId}', 'userId, nombre y foto del autor, text y createdAt.', 'Uno a muchos desde publicación. Solo el autor puede eliminar su comentario.'],
 ], [152, 185, 167]),
 h('Referencias e instantáneas'),
 p('Cada publicación conserva tanto el identificador de la mascota como una instantánea de su nombre y de los datos visibles del autor. La desnormalización reduce lecturas al construir el feed. Su contrapartida es que una modificación posterior del perfil no reescribe automáticamente los nombres y fotografías históricos ya incorporados a publicaciones o comentarios.'),
 h('Reacciones y orden cronológico'),
 p('El contador de likes se calcula a partir de la lista de UID de cada publicación; no existe un entero independiente que el cliente pueda aumentar arbitrariamente. arrayUnion y arrayRemove evitan sobrescribir las reacciones de otros usuarios. El feed consulta createdAt en orden descendente y los comentarios se presentan por orden de creación mediante escuchas de snapshots.'),
 p('Este esquema resulta adecuado para el volumen académico. Una lista de likes dentro de cada publicación y una consulta del feed sin paginación requieren revisión si aumenta la comunidad: una subcolección de reacciones y consultas paginadas permitirían reducir contención y lecturas.'),
]),
('6 Modelo de comunidad y consistencia', [
 t(['Ruta lógica', 'Contenido y regla de integridad'], [
 ['adoptions/{adoptionId}', 'Instantánea de la mascota, petId, ownerName, ubicación, requisitos y active. El propietario publica sobre una mascota propia y puede cerrar el aviso.'],
 ['chats/{chatId}', 'Dos participants, fechas y resumen lastText, lastSenderId y lastMessageId. Los participantes no pueden reemplazarse después de la creación.'],
 ['chats/{chatId}/messages/{id}', 'senderId, text y timestamp. Solo los miembros pueden leer y crear mensajes; no se habilita edición o borrado desde el cliente.'],
 ['users/{uid}/activity/{kind}_{postId}', 'kind, postId, referenceId y createdAt. Crédito privado, único e inmutable. El puntaje se deriva de la actividad.'],
 ['users/{uid}/devices/{id}', 'Token FCM, plataforma web y updatedAt. Datos privados del titular.'],
 ['users/{uid}/notifications/{id}', 'Historial privado de avisos y estado de entrega. Escritura reservada al servidor mediante Admin SDK.'],
 ['Storage\nusers/{uid}/media/{archivo}', 'Archivos de imagen o video. Escritura por propietario y lectura autenticada según reglas; las URL de descarga con token pueden compartirse. Servicio productivo desactivado.'],
 ], [190, 314]),
 h('Adopciones y contacto'),
 p('Los filtros combinan tipo, grupo etario y ubicación normalizada sin distinguir acentos. La clasificación de edad distingue menores de dos años, de dos a siete y de ocho en adelante. El formulario de interés entrega el mensaje por el chat privado con el responsable del aviso; no realiza un envío de correo electrónico.'),
 h('Atomicidad de los mensajes'),
 p('El identificador de conversación se obtiene de los dos UID ordenados y codificados, de manera que la misma pareja reutiliza su historial. Al enviar, el servicio escribe el documento del mensaje y el resumen del chat en un mismo lote. Las reglas consultan el estado posterior con getAfter para comprobar que el resumen corresponde al mensaje recién creado y a su remitente real.'),
 p('La unidad de confirmación es el lote completo: si una validación falla, no debe quedar un resumen que anuncie un mensaje inexistente. Los textos se limitan a 2000 caracteres. Las pruebas cubren la sustitución de participantes, el acceso de una tercera cuenta y los intentos de modificar el historial.'),
]),
('7 Seguridad y privacidad', [
 p('La autorización se ejecuta en Firestore y Storage, además de las comprobaciones de interfaz. Las reglas comparan request.auth.uid con el propietario o con los participantes y restringen los campos de los documentos sociales. Las fechas de creación de acciones se contrastan con request.time.'),
 t(['Amenaza', 'Control implementado', 'Evidencia o límite'], [
 ['Lectura de perfiles ajenos', 'Documento privado por UID y directorio separado con nombre y fotografía.', 'Pruebas de reglas con usuarios distintos. El feed se limita a miembros autenticados.'],
 ['Suplantación de autor', 'UID del emisor vinculado a la sesión y mascota propia al publicar.', 'Se rechazan publicaciones sobre mascotas ajenas y comentarios con otro UID.'],
 ['Manipulación de reacciones', 'Cambios limitados a agregar o quitar el UID propio.', 'Concurrencia, idempotencia y preservación de likes ajenos comprobadas.'],
 ['Acceso a conversaciones', 'Lectura por participantes y validación atómica de mensaje y resumen.', 'Se rechaza el acceso de terceros y el cambio de participantes.'],
 ['Inflación del puntaje', 'Créditos inmutables y fuente verificada; no se admite un total editable.', 'Se rechazan créditos duplicados, importes externos y referencias inválidas.'],
 ['Archivos no permitidos', 'Propiedad, tipo MIME y límites de 10 MB para imagen y 50 MB para video.', 'Pruebas en Storage Emulator. El servicio productivo está desactivado.'],
 ], [118, 203, 183]),
 h('Alcance de las garantías'),
 p('El cliente no incluye claves de cuenta de servicio. La configuración web de Firebase y la clave pública VAPID identifican el proyecto y permiten inicializar SDK; no reemplazan las reglas de autorización. Los secretos administrativos corresponden al entorno servidor. El informe no reproduce tokens de dispositivos ni credenciales de usuarios.'),
 p('Los perfiles y las mascotas privadas tienen autorización por propietario, pero no todas sus propiedades poseen validación exhaustiva de esquema en reglas. Los nombres y fotos históricos son instantáneas aportadas por el cliente. Las URL de descarga con token pueden compartirse y no deben tratarse como una garantía absoluta de confidencialidad del archivo.'),
 p('Estas pruebas validan controles concretos del repositorio. No constituyen una prueba de penetración, una certificación de seguridad ni una comprobación de que las reglas remotas coincidan con la última versión local.'),
]),
('8 Gamificación y prevención de duplicados', [
 p('La gamificación registra hechos y calcula el resultado a partir de ellos. Cada crédito se almacena bajo un identificador determinista compuesto por el tipo de acción y la publicación. El usuario no puede editar o borrar un crédito ya confirmado, ni enviar un puntaje total en su perfil.'),
 t(['Acción', 'Puntos', 'Condición para obtener el crédito'], [
 ['Publicar', '10', 'Una publicación nueva del titular con fecha del servidor. El lote crea publicación y crédito.'],
 ['Dar like', '2', 'Primera acreditación sobre una publicación ajena. No se premian las reacciones sobre contenido propio.'],
 ['Comentar', '3', 'Primer crédito por comentar una publicación ajena. El comentario debe existir en la escritura validada.'],
 ], [94, 51, 359]),
 p('El puntaje es la suma de créditos únicos: P = 10 × publicaciones + 2 × likes + 3 × comentarios acreditados. No depende de la cantidad actual de interacciones visibles.'),
 h('Niveles e insignias'),
 t(['Elemento', 'Umbral o condición'], [
 ['Explorador · Amigo', 'Explorador desde 0 puntos; Amigo desde 25 puntos.'],
 ['Embajador · Leyenda', 'Embajador desde 100 puntos; Leyenda desde 250 puntos.'],
 ['Primera huella', 'Publicar por primera vez.'],
 ['Buen compañero', 'Dar like a cinco publicaciones ajenas distintas.'],
 ['Conversador', 'Comentar cinco publicaciones ajenas distintas.'],
 ['Estrella PetVerse', 'Alcanzar 100 puntos.'],
 ], [175, 329]),
 h('Comportamiento ante acciones repetidas'),
 p('Quitar un like o eliminar un comentario no retira un crédito obtenido. Repetir la interacción tampoco genera otro crédito para la misma publicación. La política evita sumar y restar un contador con cada toque y mantiene el logro como reconocimiento histórico. Las transacciones serializan la comprobación de créditos en interacciones concurrentes.'),
 p('La incorporación de esta función no ejecuta una migración masiva de actividad anterior. Un like válido ya existente puede acreditarse una vez al interactuar nuevamente, porque la regla comprueba la existencia de la reacción y la ausencia del crédito, no necesariamente la fecha original del like. Las reglas y pruebas expresan este límite.'),
]),
('9 PWA y diseño adaptable', [
 h('Instalación e identidad de la aplicación'),
 p('El manifest declara nombre, idioma es-AR, identificador, ruta de inicio, ámbito y modo standalone. Se incluyen iconos PNG de 192 y 512 píxeles, variantes maskable y un icono de 180 píxeles para Apple Touch. Estos recursos pertenecen a la instalación web y no implican incorporar Apple como proveedor de autenticación.'),
 p('El script pwa.js conserva el evento beforeinstallprompt y solicita la instalación desde el gesto del usuario. Distingue aceptación, cancelación y el evento appinstalled. Si el navegador no expone ese mecanismo, la interfaz muestra instrucciones manuales en lugar de anunciar una instalación inexistente. La integración Dart usa un adaptador web y una implementación alternativa para pruebas.'),
 h('Caché y funcionamiento sin conexión'),
 p('app-sw.js administra una lista explícita de recursos públicos como manifest, iconos y la página offline. La navegación prioriza la red y, si falla, presenta esa página. No almacena en su caché respuestas de Auth, Firestore, chats o archivos privados, ni ofrece editar publicaciones o enviar mensajes sin conexión. Tampoco se afirma que todos los mecanismos de persistencia de los SDK queden desactivados por esta decisión.'),
 p('El bootstrap personalizado evita registrar el worker legado de Flutter sobre el mismo ámbito. El worker de Firebase Messaging mantiene un ámbito diferente. La preparación del build incorpora una versión derivada del contenido para invalidar la caché propia; la actualización espera que se cierren las pestañas anteriores para no mezclar recursos entre versiones.'),
 h('Adaptación de la interfaz'),
 t(['Condición de ancho', 'Decisión de presentación'], [
 ['Menos de 900 px', 'Navegación inferior. Por debajo de 400 px se compactan etiquetas y espacios.'],
 ['Desde 900 px', 'Barra lateral de navegación para aprovechar el ancho disponible.'],
 ['Desde 1280 px', 'Barra lateral extendida; formularios y contenido mantienen límites legibles.'],
 ['Formularios y grillas', 'Campos apilables, desplazamiento, textos con ajuste y columnas según el espacio disponible.'],
 ], [153, 351]),
 p('Las pruebas de widgets recorren perfil, feed, formularios, adopciones y chat en 320 × 740, 768 × 1024 y 1440 × 900. Esta evidencia cubre esos tamaños concretos; la instalación en dispositivos reales y una evaluación completa de accesibilidad siguen siendo verificaciones distintas.'),
]),
('10 Despliegue y operación', [
 p('La aplicación está disponible en https://petverse-29db2.web.app/. Firebase Hosting sirve el frontend compilado y reescribe las rutas de la aplicación hacia index.html. La revisión del 20 de octubre de 2026 confirmó las siguientes respuestas públicas, sin iniciar sesión ni escribir datos reales.'),
 t(['Recurso comprobado', 'Resultado'], [
 ['Página principal por HTTPS', 'HTTP 200'],
 ['manifest.json', 'HTTP 200'],
 ['app-sw.js', 'HTTP 200'],
 ['main.dart.js', 'HTTP 200'],
 ['build-info.json', 'HTTP 200 · versión 930deeb24561994c8410'],
 ], [240, 264]),
 cap('El build informa fecha 20 de octubre de 2026 a las 15:46:22 UTC. Una respuesta HTTP correcta acredita disponibilidad del recurso, no el éxito de todos los flujos autenticados.'),
 h('Proceso reproducible de publicación'),
 p('scripts/publish.ps1 prepara una copia temporal nueva fuera de OneDrive, excluye cachés y dependencias generadas y resuelve las herramientas antes de cambiar de directorio. Comprueba que la configuración del cliente corresponda al proyecto de destino. La compilación release fija una salida absoluta con --output para evitar depender de una configuración global de Flutter.'),
 p('Antes de publicar, scripts/prepare_web.mjs exige main.dart.js, valida la estructura de iconos del manifest y compara los recursos del build con las fuentes actuales. Después incorpora el hash de versión al worker y genera build-info.json. Si una comprobación falla, el proceso se detiene y no anuncia un despliegue correcto.'),
 p('La opción -Deploy ejecuta únicamente el despliegue de Hosting. No publica reglas ni funciones, no activa Storage y no habilita facturación. Los encabezados configurados incluyen no-cache para recursos que deben revalidarse, X-Content-Type-Options y Referrer-Policy. La disponibilidad del frontend no demuestra que el backend tenga activados todos los módulos.'),
 h('Configuración y mantenimiento'),
 p('La configuración local del cliente se conserva fuera del informe. Antes de presentar o actualizar la aplicación deben comprobarse los dominios autorizados de Authentication, la versión remota de las reglas y el acceso entre dos cuentas de prueba. Las copias de compilación son descartables; la fuente del proyecto sigue siendo la carpeta de trabajo y su historial de Git.'),
]),
('11 Estrategia de pruebas y resultados', [
 p('La revisión del 20 de octubre de 2026 volvió a ejecutar 45 pruebas y todas finalizaron aprobadas. Se utilizaron datos ficticios o emuladores; no se enviaron mensajes a usuarios reales ni se modificó la base productiva. La copia de verificación de Flutter evita los bloqueos de archivos de la carpeta sincronizada.'),
 t(['Grupo', 'Casos', 'Resultado y cobertura'], [
 ['Flutter', '24', 'Aprobadas. Autenticación demo, feed, comunidad, gamificación, instalación y pantallas adaptables.'],
 ['Reglas de Firestore y Storage', '9', 'Aprobadas. Propiedad, privacidad, concurrencia, créditos, chat, límites y progreso de subida emulada.'],
 ['Ayudantes de notificaciones', '4', 'Aprobadas. Eventos, identificadores estables, avisos y depuración de tokens permanentemente inválidos.'],
 ['PWA en JavaScript', '3', 'Aprobadas. Manifest e iconos, prompt de instalación y exclusión de rutas privadas del worker.'],
 ['Preparación del build', '5', 'Aprobadas. Salida explícita, build ausente, manifest antiguo, assets actuales y copia parcial rechazada.'],
 ['Total', '45', '45 aprobadas y 0 fallidas.'],
 ], [171, 48, 285]),
 h('Entorno y reproducibilidad'),
 p('La implementación fue validada con Flutter 3.47.7 y Dart 3.13.5. Los ensayos de reglas utilizan Node.js 24 y Java 21, con el proyecto ficticio demo-petverse-tests y emuladores locales de Firestore y Storage. Cloud Functions declara Node.js 22 como entorno de ejecución; probar ayudantes con Node.js 24 no acredita por sí solo un despliegue o una ejecución completa en ese entorno servidor.'),
 p('Los puntos de entrada reproducibles son flutter test, node --test test/web/*.test.cjs functions/notifications.test.cjs y npm test desde test/firestore. Los rechazos PERMISSION_DENIED producidos por los casos negativos de autorización son resultados esperados, no errores pendientes de la aplicación.'),
 h('Qué no demuestran estas pruebas'),
 p('La suite no sustituye una prueba integral con cuentas de producción, la recepción efectiva de push ni una subida al bucket real. Tampoco mide carga, latencia o accesibilidad conforme a una norma. El análisis estático y la compilación release tuvieron verificaciones previas satisfactorias; no se los contabiliza como casos adicionales dentro de las 45 pruebas.'),
]),
('12 Evidencia visual disponible', [
 p('Las capturas conservadas corresponden a verificaciones locales y se identifican como tales. Son evidencia de PV11 y del fallback sin conexión de PV12. No acreditan datos de usuarios reales ni el funcionamiento del backend de notificaciones.'),
 image(ROOT / 'docs/screenshots/pv11-logros-demo.png', 243, 227),
 cap('Figura 2  Gamificación en modo demo. La publicación acredita 10 puntos y desbloquea Primera huella. La tarjeta presenta el nivel y las condiciones de las insignias.'),
 image(ROOT / 'docs/screenshots/pv12-offline-demo.png', 243, 227),
 cap('Figura 3  Verificación local del worker. Después de detener el servidor y recargar, se muestra la página offline explícita, sin reproducir conversaciones ni contenido privado.'),
 p('El anexo visual debe ampliarse con acceso, perfil, mascotas, feed, adopciones y chat en el entorno de presentación. Para la aceptación final también se requiere la evidencia de instalación y de las integraciones pendientes.'),
]),
('13 Dificultades y riesgos pendientes', [
 t(['Dificultad observada', 'Causa técnica y solución aplicada'], [
 ['Bloqueos de compilación', 'OneDrive mantenía carpetas generadas en uso. La compilación se trasladó a una copia temporal, sin borrar la fuente ni depender de flutter clean para resolver el bloqueo.'],
 ['Herramienta no disponible', 'La terminal no encontraba Flutter en PATH. Se utilizó el SDK instalado y se documentó cómo incorporarlo al entorno de la terminal.'],
 ['Manifest antiguo y main.dart.js ausente', 'La salida efectiva de Flutter no coincidía con build/web por una configuración global. El script fija --output y verifica el archivo principal y la coherencia de los assets antes de desplegar.'],
 ['Reacciones y créditos repetidos', 'Las escrituras completas podían perder cambios concurrentes. Transformaciones atómicas, transacciones e identificadores únicos conservan los likes ajenos y evitan créditos repetidos.'],
 ['Workers con el mismo ámbito', 'El worker legado de Flutter podía competir con el worker PWA. Se adoptó un bootstrap propio y se separó el ámbito de Firebase Messaging.'],
 ['Errores en pantallas estrechas', 'Los controles y textos rígidos desbordaban en móvil. Se aplicaron restricciones flexibles y pruebas de widgets en tres tamaños.'],
 ], [151, 353]),
 h('Restricciones operativas y deuda técnica'),
 p('Storage y el envío automático de push requieren una decisión de activación independiente. El cliente FCM registra tokens con consentimiento y las funciones preparadas generan avisos para likes, comentarios y mensajes, pero ninguna prueba local permite afirmar que esos avisos lleguen al navegador en producción.'),
 p('El backend preparado mantiene un historial de avisos con identificadores estables y elimina tokens definitivamente inválidos. Existe una ventana de reintento si el proceso se interrumpe después del envío y antes de registrar la entrega; una etiqueta estable reduce duplicados visibles, pero no garantiza entrega exactamente una vez.'),
 p('Para una comunidad de mayor volumen deben evaluarse paginación del feed, consultas e índices, moderación de contenido, cuotas y monitoreo de costos. La política actual de puntos y la permanencia de los créditos también requieren mantenerse explícitas si se incorporan nuevas formas de interacción.'),
]),
('14 Conclusiones y referencias', [
 p('PetVerse integra una interfaz Flutter modular con identidad administrada, documentos en tiempo real y reglas de autorización comprobadas en emuladores. La separación entre modelos, servicios, providers y pantallas permitió reutilizar los flujos en Firebase y en demostración sin mezclar datos temporales con persistencia real.'),
 p('Los principales aprendizajes técnicos fueron la coordinación de escrituras atómicas, el diseño de controles por propietario y participante, y el manejo del ciclo de vida de los streams al cambiar de sesión. La gamificación se resolvió a partir de créditos verificables y no de un contador modificable. La PWA define de forma acotada su caché y su respuesta sin conexión, evitando prometer operaciones que requieren red.'),
 p('El frontend publicado y las 45 pruebas aprobadas aportan una base verificable para la presentación. El cierre completo de la actividad sigue condicionado a activar y demostrar PV8 y PV10, instalar la PWA en un dispositivo real y completar el anexo visual y el video. La documentación de esas restricciones permite defender el alcance efectivo sin confundir código preparado con funcionalidad operativa.'),
 h('Identificación de la entrega'),
 p('Aplicación publicada: https://petverse-29db2.web.app/\nRepositorio configurado: https://github.com/joacocop/PetVerse\nVersión declarada del proyecto: 0.1.0+1\nCorte técnico del informe: 20 de octubre de 2026.'),
 h('Fuentes del proyecto'),
 p('Consigna académica: Red Social para Mascotas con Flutter Web + Firebase, 14 de octubre de 2026, Prof. Jorge Fabián Siles Guzmán. Requisitos y entregables consultados en las páginas 15, 16, 19 y 20.'),
 p('Implementación y verificaciones: lib/models, lib/services, lib/providers, lib/screens, firestore.rules, storage.rules, functions, web, scripts/publish.ps1, scripts/prepare_web.mjs y suites de test. Las guías PV7-PV10 y PV11-PV14 conservan las instrucciones operativas complementarias.'),
 h('Documentación técnica complementaria'),
 ('links', [
  ('Arquitectura de Flutter', 'https://docs.flutter.dev/app-architecture'),
  ('Firebase Authentication para Flutter', 'https://firebase.google.com/docs/auth/flutter/start'),
  ('Reglas de Cloud Firestore', 'https://firebase.google.com/docs/firestore/security/get-started'),
  ('Transacciones y escrituras por lotes', 'https://firebase.google.com/docs/firestore/manage-data/transactions'),
  ('Firebase Hosting', 'https://firebase.google.com/docs/hosting'),
  ('Firebase Cloud Messaging para Flutter', 'https://firebase.google.com/docs/cloud-messaging/flutter/get-started'),
 ]),
]),
]


def pdf_markup(s):
    return escape(s).replace('\n', '<br/>')


def create_pdf():
    styles = {
        'body': ParagraphStyle('body', fontName='Calibri', fontSize=11.2, leading=14.4, spaceAfter=9, textColor=colors.black),
        'title': ParagraphStyle('title', fontName='Calibri-Bold', fontSize=21, leading=25, spaceAfter=15, textColor=colors.black),
        'sub': ParagraphStyle('sub', fontName='Calibri-Bold', fontSize=12.7, leading=16, spaceBefore=8, spaceAfter=6, keepWithNext=True, textColor=colors.black),
        'caption': ParagraphStyle('caption', fontName='Calibri', fontSize=9.3, leading=11.7, spaceBefore=5, spaceAfter=10, textColor=colors.HexColor(GRAY)),
        'cell': ParagraphStyle('cell', fontName='Calibri', fontSize=10.2, leading=12.7, textColor=colors.black),
        'th': ParagraphStyle('th', fontName='Calibri-Bold', fontSize=10.2, leading=12.5, textColor=colors.white),
        'small': ParagraphStyle('small', fontName='Calibri', fontSize=10.2, leading=13, spaceAfter=4, textColor=colors.black),
    }
    story = []
    def par(s, style='body'): return Paragraph(pdf_markup(s), styles[style])
    story += [Spacer(1,65), par('PetVerse', 'title'), Spacer(1,6),
              Paragraph('Informe técnico', ParagraphStyle('cover',fontName='Calibri-Bold',fontSize=32,leading=38,spaceAfter=13)),
              Paragraph('Red social para mascotas con Flutter Web y Firebase', ParagraphStyle('coverSub',fontName='Calibri',fontSize=18,leading=23,spaceAfter=26)),
              par('Arquitectura · Modelo de datos · Seguridad\nValidación · Despliegue', 'body'), Spacer(1,61),
              par('Proyecto Diseño e Implementación de Sitios Web Dinámicos', 'sub'),
              par('Docente: Prof. Jorge Fabián Siles Guzmán\nConsigna: 14 de octubre de 2026\nInforme: 20 de octubre de 2026\nVersión de la aplicación: 0.1.0+1'), Spacer(1,37),
              par('Despliegue', 'sub'),
              Paragraph('<link href="https://petverse-29db2.web.app/" color="#233E55">https://petverse-29db2.web.app/</link>', styles['body']),
              par('Repositorio', 'sub'),
              Paragraph('<link href="https://github.com/joacocop/PetVerse" color="#233E55">https://github.com/joacocop/PetVerse</link>', styles['body']), PageBreak()]
    for idx, (title, blocks) in enumerate(PAGES):
        story.append(par(title, 'title'))
        for block in blocks:
            kind = block[0]
            if kind in ('p','h','cap'):
                story.append(par(block[1], {'p':'body','h':'sub','cap':'caption'}[kind]))
            elif kind == 'contents':
                story.extend(par(entry, 'small') for entry in block[1])
            elif kind == 'links':
                for label, url in block[1]:
                    story.append(Paragraph(f'<link href="{escape(url)}" color="#233E55">{escape(label)}</link>', styles['small']))
            elif kind == 'diagram':
                story.append(diagram())
            elif kind == 'img':
                im = Image(block[1], width=block[2], height=block[3])
                im.hAlign = 'CENTER'
                story.append(im)
            elif kind == 't':
                _, headers, rows, widths = block
                cells = [[par(x, 'th') for x in headers]] + [[par(x,'cell') for x in row] for row in rows]
                tab = Table(cells, colWidths=widths, repeatRows=1, hAlign='LEFT')
                tab.setStyle(TableStyle([
                    ('BACKGROUND',(0,0),(-1,0),colors.HexColor(NAVY)),
                    ('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor(PALE)]),
                    ('GRID',(0,0),(-1,-1),.5,colors.HexColor('#D9D9D9')),
                    ('VALIGN',(0,0),(-1,-1),'TOP'),
                    ('LEFTPADDING',(0,0),(-1,-1),8),('RIGHTPADDING',(0,0),(-1,-1),8),
                    ('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7),
                ]))
                if headers[0] == 'PV':
                    tab.setStyle(TableStyle([('LEFTPADDING',(0,0),(0,-1),5),('RIGHTPADDING',(0,0),(0,-1),5)]))
                story += [tab, Spacer(1,11)]
        if idx < len(PAGES)-1: story.append(PageBreak())
    def decorate(canvas, doc):
        canvas.setTitle('PetVerse | Informe técnico')
        canvas.setAuthor('Proyecto PetVerse')
        canvas.setSubject('Arquitectura, implementación y validación de una PWA con Flutter Web y Firebase')
        if doc.page > 1:
            canvas.saveState()
            canvas.setFont('Calibri',9)
            canvas.setFillColor(colors.HexColor(GRAY))
            canvas.drawString(54,758,'PETVERSE  /  INFORME TÉCNICO')
            canvas.drawRightString(558,758,'20 OCT 2026')
            canvas.drawString(54,30,'Flutter Web y Firebase')
            canvas.drawRightString(558,30,str(doc.page))
            canvas.restoreState()
    class ReportDoc(SimpleDocTemplate):
        def afterFlowable(self, flowable):
            if isinstance(flowable, Paragraph) and flowable.style.name == 'title':
                txt = flowable.getPlainText()
                key = f'section-{self.page}'
                self.canv.bookmarkPage(key)
                self.canv.addOutlineEntry(txt,key,level=0,closed=False)
    ReportDoc(str(PDF), pagesize=(612,792), rightMargin=54,leftMargin=54,topMargin=58,bottomMargin=49,
              title='PetVerse Informe técnico', author='Proyecto PetVerse', allowSplitting=1).build(story,onFirstPage=decorate,onLaterPages=decorate)


def shade(cell, color):
    el = OxmlElement('w:shd'); el.set(qn('w:fill'),color)
    cell._tc.get_or_add_tcPr().append(el)


def link(paragraph, label, url):
    rid = paragraph.part.relate_to(url, 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink', is_external=True)
    elem=OxmlElement('w:hyperlink'); elem.set(qn('r:id'),rid)
    run=OxmlElement('w:r'); props=OxmlElement('w:rPr')
    color=OxmlElement('w:color'); color.set(qn('w:val'),'233E55'); props.append(color)
    run.append(props); txt=OxmlElement('w:t'); txt.text=label; run.append(txt); elem.append(run); paragraph._p.append(elem)


def create_docx():
    doc=Document(); sec=doc.sections[0]
    sec.page_width=Inches(8.5); sec.page_height=Inches(11)
    sec.left_margin=sec.right_margin=Inches(.75)
    sec.top_margin=Inches(.80); sec.bottom_margin=Inches(.68)
    sec.header_distance=Inches(.3); sec.footer_distance=Inches(.3)
    sec.different_first_page_header_footer=True
    for name, size, bold in [('Normal',11.2,False),('Title',32,True),('Subtitle',18,False),('Heading 1',21,True),('Heading 2',12.7,True),('Caption',9.3,False)]:
        style=doc.styles[name]; style.font.name='Calibri'; style.font.size=Pt(size); style.font.bold=bold; style.font.color.rgb=RGBColor(0,0,0)
        fmt=style.paragraph_format; fmt.space_after=Pt(9); fmt.line_spacing=Pt(14.4)
        if name in ('Title','Heading 1','Heading 2'):
            fmt.keep_with_next=True; fmt.line_spacing=1.12
    doc.styles['Heading 1'].paragraph_format.space_after=Pt(15)
    doc.styles['Heading 2'].paragraph_format.space_before=Pt(8)
    doc.styles['Heading 2'].paragraph_format.space_after=Pt(6)
    doc.styles['Caption'].font.color.rgb=RGBColor.from_string('56616B')
    doc.styles['Caption'].paragraph_format.line_spacing=Pt(11.7)
    header=sec.header.paragraphs[0]
    header.text='PETVERSE  /  INFORME TÉCNICO'
    header.runs[0].font.size=Pt(9); header.runs[0].font.color.rgb=RGBColor.from_string('56616B')
    foot=sec.footer.paragraphs[0]; foot.text='Flutter Web y Firebase'; foot.runs[0].font.size=Pt(9)
    foot.paragraph_format.tab_stops.add_tab_stop(Inches(6.8))
    foot.add_run('\t')
    field=OxmlElement('w:fldSimple'); field.set(qn('w:instr'),'PAGE'); foot._p.append(field)
    cp=doc.core_properties; cp.title='PetVerse Informe técnico'; cp.author='Proyecto PetVerse'; cp.subject='Arquitectura implementación y validación'; cp.language='es-AR'
    def paragraph(text,style=None): return doc.add_paragraph(text,style)
    blank=paragraph(''); blank.paragraph_format.space_after=Pt(56)
    paragraph('PetVerse','Heading 1')
    paragraph('Informe técnico','Title')
    paragraph('Red social para mascotas con Flutter Web y Firebase','Subtitle')
    paragraph('Arquitectura · Modelo de datos · Seguridad\nValidación · Despliegue')
    blank=paragraph(''); blank.paragraph_format.space_after=Pt(43)
    paragraph('Proyecto Diseño e Implementación de Sitios Web Dinámicos','Heading 2')
    paragraph('Docente: Prof. Jorge Fabián Siles Guzmán\nConsigna: 14 de octubre de 2026\nInforme: 20 de octubre de 2026\nVersión de la aplicación: 0.1.0+1')
    paragraph('Despliegue','Heading 2'); link(paragraph(''),'https://petverse-29db2.web.app/','https://petverse-29db2.web.app/')
    paragraph('Repositorio','Heading 2'); link(paragraph(''),'https://github.com/joacocop/PetVerse','https://github.com/joacocop/PetVerse')
    doc.add_page_break()
    diagram_path=QA/'arquitectura.png'
    diagram_pdf = pdfium.PdfDocument(renderPDF.drawToString(diagram()))
    diagram_pdf[0].render(scale=2.5).to_pil().save(diagram_path)
    for idx,(title,blocks) in enumerate(PAGES):
        paragraph(title,'Heading 1')
        for block in blocks:
            kind=block[0]
            if kind in ('p','h','cap'):
                paragraph(block[1],{'p':'Normal','h':'Heading 2','cap':'Caption'}[kind])
            elif kind=='contents':
                for entry in block[1]:
                    pp=paragraph(entry); pp.paragraph_format.space_after=Pt(4); pp.paragraph_format.line_spacing=Pt(13)
                    for rr in pp.runs: rr.font.size=Pt(10.2)
            elif kind=='links':
                for label,url in block[1]:
                    pp=paragraph(''); pp.paragraph_format.space_after=Pt(4); link(pp,label,url)
            elif kind=='diagram':
                doc.add_picture(str(diagram_path),width=Inches(7))
                doc.paragraphs[-1].paragraph_format.line_spacing=1.0
            elif kind=='img':
                pp=paragraph(''); pp.alignment=1
                pp.add_run().add_picture(block[1],width=Pt(block[2]),height=Pt(block[3]))
                pp.paragraph_format.space_after=Pt(0)
                pp.paragraph_format.line_spacing=1.0
            elif kind=='t':
                _,headers,rows,widths=block
                table=doc.add_table(rows=1, cols=len(headers)); table.autofit=False
                props=table._tbl.tblPr
                borders=OxmlElement('w:tblBorders')
                for edge in ['top','left','bottom','right','insideH','insideV']:
                    el=OxmlElement('w:'+edge); el.set(qn('w:val'),'single'); el.set(qn('w:sz'),'4'); el.set(qn('w:color'),'D9D9D9'); borders.append(el)
                props.append(borders)
                margins=OxmlElement('w:tblCellMar')
                for edge,value in [('top',110),('bottom',110),('left',140),('right',140)]:
                    el=OxmlElement('w:'+edge); el.set(qn('w:w'),str(value)); el.set(qn('w:type'),'dxa'); margins.append(el)
                props.append(margins)
                for col,width in zip(table.columns,widths): col.width=Pt(width)
                allrows=[headers]+rows
                for ri,row in enumerate(allrows):
                    rr=table.rows[0] if ri==0 else table.add_row()
                    trpr=rr._tr.get_or_add_trPr(); trpr.append(OxmlElement('w:cantSplit'))
                    if ri==0: trpr.append(OxmlElement('w:tblHeader'))
                    for ci,text in enumerate(row):
                        cell=rr.cells[ci]; cell.width=Pt(widths[ci]); cell.vertical_alignment=0
                        if ci == 0 and headers[0] == 'PV':
                            cell_margin=OxmlElement('w:tcMar')
                            for side in ['left','right']:
                                side_el=OxmlElement('w:'+side); side_el.set(qn('w:w'),'80'); side_el.set(qn('w:type'),'dxa'); cell_margin.append(side_el)
                            cell._tc.get_or_add_tcPr().append(cell_margin)
                        shade(cell,'233E55' if ri==0 else ('F2F5F7' if ri%2==0 else 'FFFFFF'))
                        pp=cell.paragraphs[0]; pp.paragraph_format.space_after=Pt(0); pp.paragraph_format.line_spacing=Pt(12.7)
                        rrn=pp.add_run(text); rrn.font.size=Pt(10.2); rrn.font.bold=ri==0
                        rrn.font.color.rgb=RGBColor.from_string('FFFFFF' if ri==0 else '000000')
                tail=paragraph(''); tail.paragraph_format.space_after=Pt(0); tail.paragraph_format.line_spacing=Pt(5)
        if idx<len(PAGES)-1: doc.add_page_break()
    doc.save(DOCX)


if __name__ == '__main__':
    create_pdf()
    create_docx()
    print(json.dumps({'pdf':str(PDF),'editable':str(DOCX),'sections':len(PAGES)},ensure_ascii=False))

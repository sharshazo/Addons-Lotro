# Addons-Lotro

Conjunto de addons de LOTRO (The Lord of the Rings Online) con soporte
y contenido en espanol.

## Descarga rapida

**[Descargar el paquete completo (.zip)](https://github.com/sharshazo/Addons-Lotro/releases/latest)**
-- incluye LOTRO_Quest_Assistant (QuestSync) + Narrador_IA listos para
instalar, con una guia paso a paso adentro (`LEEME_PRIMERO.txt`). No hace
falta git ni saber nada de submodulos: es un solo archivo.

*(El boton verde "Code > Download ZIP" de arriba de la pagina de GitHub
NO sirve para este repositorio -- cada addon vive en su propio
repositorio aparte y ese boton no trae ese contenido. Usa el link de
arriba.)*

Cada addon vive en su propio repositorio independiente y se incluye
aqui como submodulo, para poder actualizarlo por separado sin
mezclar el historial de los tres:

- [**LUI-LOTRO**](https://github.com/sharshazo/LUI-LOTRO) - interfaz
  de usuario personalizada para LOTRO (addon original de Geldahr),
  con soporte de idioma espanol para Inventario, Opciones,
  Enciclopedia y el resto de sus ventanas.
- [**LOTRO_Quest_Assistant**](https://github.com/sharshazo/LOTRO_Quest_Assistant) -
  asistente de misiones propio: traduce nombres, dialogos y
  objetivos de las misiones al espanol, con HUD de seguimiento,
  ventana de detalle tipo "libro" y ayudas de recoleccion.
- [**DeedTracker-LOTRO**](https://github.com/sharshazo/DeedTracker-LOTRO) -
  seguimiento de hazanas/deeds (addon original de Cube), con datos
  de hazanas localizados, incluido espanol.
- [**Narrador_IA**](https://github.com/sharshazo/Narrador_IA) - app de
  Windows que le pone voz a LOTRO_Quest_Assistant: boton "Narrar" para
  escuchar cualquier mision al toque, historias ambientales al azar
  mientras jugas, y boton de silenciar/activar -- todo con voces
  neuronales gratis en espanol. Instalador de un click, sin saber
  programar.
- [**WorldMap_Addon**](WorldMap_Addon) ("Mapa del Mundo") - mapa
  interactivo de la Tierra Media con las 59 zonas en espanol (nombre,
  nivel e imagen de cada zona), buscador, filtro de expansiones y
  comando `/mapa`. Con LOTRO_Quest_Assistant muestra una moneda dorada
  con tus misiones activas en cada zona, calaveras de mazmorra /
  incursion, la lista de esas misiones al hacer clic en la zona, y un
  solo icono flotante que agrupa Mapa, Libro y Lupa. A diferencia de
  los demas, vive directo en esta carpeta (no es submodulo).

## Instalacion en el juego

Cada submodulo trae su propia guia dentro de su repositorio. La
carpeta de cada addon se copia dentro de:

```
Documentos\The Lord of the Rings Online\Plugins\
```

respetando el nombre de carpeta exacto que pide cada addon (ver el
README/documentacion de cada submodulo para el detalle de cada uno,
especialmente DeedTracker que tiene una ubicacion particular dentro
de `Plugins\CubePlugins\`).

**Narrador_IA es distinto a los demas**: no va dentro de `Plugins\`,
es un programa aparte de Windows (LOTRO no le permite a ningun addon
reproducir audio). Se instala en cualquier carpeta con su propio
`Instalar.bat` de un click -- ver su README para el detalle.

## Ultima actualizacion

**2026-09-24** -- Nuevas funciones en varios addons:

- **WorldMap_Addon (v2.5.0)**, nuevo en este repositorio: moneda dorada
  con la cantidad de misiones ACTIVAS por zona, calaveras de mazmorra e
  incursion, lista de misiones activas al hacer clic en una zona (con
  logos de grupo/mazmorra/incursion) y un solo icono flotante que
  despliega Mapa, Libro y Lupa.
- **LOTRO_Quest_Assistant**: misiones de grupo con color y logo propio
  (tamano oficial y a que mazmorra/incursion ir), filtro de grupo, boton
  "Buscar grupo", etiqueta Diaria/Semanal y marca de "tu nivel".
- **LUI-LOTRO**: nombres del botin con el color de su calidad, borde
  dorado para Incomparables/Legendarios, historial de botin de la sesion
  (`/botin`) y selector de idioma.
- **DeedTracker-LOTRO**: nueva pagina "Por zona" con una pestana por
  zona que junta las hazanas de la region, sus instancias y su
  reputacion.

**2026-09-07** -- Arreglo de raiz en la recoleccion de LOTRO_Quest_Assistant
(Minero/Lenador/Granjero/Erudito): los items adquiridos en LOTRO llegan al
addon como links clickeables con metadatos incrustados, no como texto
plano -- esto hacia que la ventana de guardar ubicacion no apareciera al
recolectar practicamente nada. Tambien se corrigio un caso donde un punto
guardado en Eregion se etiquetaba con el mapa equivocado (Musgovilla) por
un limite de zona invertido en los datos de MoorMap. El paquete de
descarga de arriba ya incluye estos arreglos.

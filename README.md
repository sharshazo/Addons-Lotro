# Addons-Lotro

Conjunto de addons de LOTRO (The Lord of the Rings Online) con soporte
y contenido en espanol.

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
- [**LOTRO_Chat_Narrator**](https://github.com/sharshazo/LOTRO_Chat_Narrator) -
  addon complementario que reenvia el chat relevante del juego al
  narrador de voz (ver Narrador_IA, abajo).
- [**Narrador_IA**](https://github.com/sharshazo/Narrador_IA) - app de
  Windows que le pone voz a LOTRO_Quest_Assistant: boton "Narrar" para
  escuchar cualquier mision al toque, historias ambientales al azar
  mientras jugas, y boton de silenciar/activar -- todo con voces
  neuronales gratis en espanol. Instalador de un click, sin saber
  programar.

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

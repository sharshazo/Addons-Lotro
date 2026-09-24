-- WorldMap_Addon/worldmap.lua
--
-- Logica real del mapa de Middle-earth, ya en la API real de LOTRO (no la
-- version generica con Adapter.* de antes). Arma el fondo con los 36 tiles,
-- dibuja las 59 zonas (matematica pura punto-en-poligono, sin controles por
-- zona), muestra nombre+nivel siempre visibles, resalta la zona bajo el
-- mouse y arma la ventana flotante con su info.
--
-- DECISIONES DE DISEÑO TOMADAS CONTRA CODIGO REAL (no adivinadas), leidas
-- del propio addon LOTRO_Quest_Assistant de este usuario (ya instalado,
-- funcionando, con historial real de bugs/crashes documentado en sus
-- comentarios):
--
-- 1. Ventana principal = Turbine.UI.Lotro.Window (chrome nativo), NO un
--    Turbine.UI.Window "pelado". QuestBookWindow.lua de ese addon documenta
--    3 CIERRES REALES DEL JUEGO ("3 cierres reales del juego") al probar
--    ventanas sin chrome nativo con botones nativos de Lotro adentro. Nunca
--    se usan Turbine.UI.Lotro.Button aca (todo son Control/Label simples),
--    pero por las dudas se sigue el patron ya probado sin incidentes:
--    Lotro.Window + el arte propio como Control HIJO (como questbook.tga en
--    QuestBookWindow.lua), nunca reemplazando la ventana en si.
-- 2. La ventana flotante de info de zona SI puede ser un Turbine.UI.Window
--    "pelado" (sin chrome) -- confirmado seguro en QuestInfoTooltip.lua de
--    ese mismo addon, que usa exactamente ese patron (ventana sin chrome +
--    SetBackColor como "marco" + un Control interior como relleno) sin
--    incidentes, porque tampoco lleva ningun Lotro.Button adentro.
-- 3. No existe (no se encontro en todo el addon real) una API de relleno
--    vectorial de poligonos (algo tipo DrawFilledPolygon). Por eso el
--    resaltado de cada zona es una mascara TGA pre-generada (ver punto 9
--    mas abajo), no un dibujo vectorial en vivo.
-- 4. Deteccion de hover con POLL (Turbine.UI.Control:SetWantsUpdates(true)
--    + .Update + self:GetMousePosition()), NO con MouseMove/Enter/Leave.
--    Confirmado en QuestBookWindow.lua (self.ringHoverPoll): en este SDK,
--    un control hijo con SetMouseVisible(true) (como el que necesitariamos
--    para clicks) corta el Enter/Leave del padre. El patron de poll ya esta
--    probado sin ese problema.
--
-- CORRECCIONES DE VERSIONES ANTERIORES (reportes reales del usuario jugando
-- en su maquina, con capturas de pantalla):
--
-- 5. VIEJO: se probo un factor de escala (self.scale) para achicar todo el
--    mapa/marco y que entrara en pantalla. ROMPIA el arte del titulo
--    ("MPADELMUDO") por redondeo independiente por tile. Se revirtio a
--    tamaño nativo fijo + ventana pegada arriba de la pantalla.
-- 6. El tooltip de zona quedaba huerfano flotando en pantalla si se
--    cerraba la ventana principal del mapa (con la X nativa). Se resuelve
--    igual que QuestSyncWindow.lua resuelve el mismo problema con su
--    "pointsPopup": un hook a self.VisibleChanged (evento real confirmado
--    en ese archivo) que oculta el tooltip apenas la ventana deja de
--    estar visible.
-- 7. El fondo del tooltip se veia transparente/ilegible: al revisar
--    tooltip_data.lua se confirmo la causa -- los 2 tiles del centro
--    (r1_c1, r1_c2) se habian omitido a proposito por caer enteramente
--    dentro de los huecos de texto/imagen, dejando esa zona sin ningun
--    arte de fondo (solo el SetBackColor totalmente transparente de
--    antes). Ahora la ventana tiene un fondo solido casi opaco DETRAS de
--    los 14 tiles reales, para que el texto sea legible pase lo que pase
--    con la cobertura de los tiles.
-- 8. Fuente mas grande donde hay una constante real confirmada: titulo de
--    zona y titulo del tooltip pasan de TrajanPro14 a TrajanPro16
--    (confirmado real via el addon publico "Equendil"). El texto del
--    cuerpo se mantiene en Verdana12 (unica variante de Verdana
--    confirmada en codigo real visto hasta ahora).
-- 9. Relleno de zona CON LA FORMA REAL del poligono (no un rectangulo):
--    59 mascaras TGA pre-generadas (una por zona, recortadas a la forma
--    exacta y coloreadas), siempre visibles, semi-transparentes -- pedido
--    explicito del usuario con una imagen de referencia real (mapa
--    comunitario "Map of LOTRO zones by level"). zone.relleno trae la
--    ruta de cada mascara (worldmap_data.lua).
-- 10. REVERTIDO: fondo oscuro fijo detras de cada etiqueta de zona -- con
--     59 zonas juntas se veia como una alfombra de rectangulos oscuros
--     tapando el mapa (reporte real del usuario con captura). Se saca; el
--     relleno con forma real (punto 9) ya cumple ese rol.
-- 11. El tooltip flotante podia calcular una posicion fuera de la
--     pantalla al hacer hover cerca de un borde. Se aprieta (clamp) contra
--     Turbine.UI.Display.GetWidth()/GetHeight() para que quede siempre
--     entero visible.
--
-- 12-13, INTENTOS REVERTIDOS (reporte real del usuario: "error todo...
-- todo se rompe"): se probo (a) arrastrar la VENTANA ENTERA con el mouse, y
-- (b) un zoom que reescalaba mapa+marco+rellenos+etiquetas juntos con un
-- redondeo por bordes compartidos (matematicamente sin huecos en las
-- pruebas del arnes, pero en el juego real igual se veia todo amontonado).
-- El usuario pidio explicitamente copiar OTRO mecanismo, uno que YA
-- funciona en su maquina: UI/GatherWindow.lua (ventana "Recolección") de
-- LOTRO_Quest_Assistant. Se leyo ese archivo real completo (device_bridge)
-- y esta version implementa EXACTAMENTE su arquitectura:
--
-- 14. VIEWPORT + PAN, sin reescalar nunca nada (GatherWindow.lua, punto 4
--     de su propio historial: "la ventana cambia de tamaño pero el mapa
--     NUNCA se achica... se arrastra con el mouse para centrar la parte
--     que se quiera ver"). self.mapViewport es un Control simple (tamaño =
--     area visible, cambia con self.SizeChanged) que RECORTA a su hijo
--     self.mapContent (tamaño SIEMPRE nativo real, ver punto 17 mas abajo),
--     que se reposiciona con el arrastre (self.panX/panY, mismo mecanismo
--     de GatherWindow.mapControl) en vez de escalarse. Todo (tiles de mapa,
--     rellenos de zona, etiquetas) es HIJO de self.mapContent a sus
--     coordenadas NATIVAS de siempre, sin ninguna cuenta de escala --
--     exactamente igual que antes del punto 5, solo que ahora paneable.
--     self:SetResizable(true) + self:SetMinimumSize(...) +
--     self.SizeChanged es el mismo mecanismo real ya confirmado en
--     produccion (GatherWindow.lua Y QuestSyncWindow.lua lo usan) para
--     poder agrandar/achicar la ventana desde el borde. SE SACA el marco de
--     cuero con el hueco (Data.FrameTiles): esa pieza estaba diseñada como
--     una unica imagen fija de tamaño completo, y no tiene sentido con una
--     ventana ahora redimensionable (su hueco recortado quedaria mal con un
--     viewport de tamaño arbitrario) -- GatherWindow.lua tampoco tiene ese
--     tipo de marco, muestra el mapa directo en el viewport.
--
-- 17. BUG REAL REPORTADO POR EL USUARIO (captura real jugando): al arrastrar
--     el mapa bastante aparecia un area NEGRA enorme, como si el mapa se
--     "rompiera". Causa real encontrada releyendo worldmap_data.lua: el
--     tamaño nativo real del ARTE del mapa es Data.MapWidth x Data.MapHeight
--     (1448x1086) -- Data.FrameCanvasWidth/FrameCanvasHeight (1619x1447) es
--     el tamaño del VIEJO marco de cuero completo (ya retirado, punto 14),
--     que tenia un borde decorativo alrededor del hueco del mapa
--     (Data.FrameHoleX/Y=85,182 es donde arrancaba ese hueco dentro del
--     marco viejo). self.mapContent se creaba con el tamaño del marco
--     COMPLETO (1619x1447) pero los tiles/rellenos/etiquetas se dibujaban
--     todos desplazados +FrameHoleX/+FrameHoleY -- dejando el resto del
--     canvas (la franja que antes cubria el marco de cuero, ahora retirado)
--     completamente vacio. El clamp (_clampPan) permitia panear hasta ese
--     borde vacio del canvas viejo, mostrando esa franja negra. Arreglado:
--     self.mapContent ahora mide exactamente Data.MapWidth x Data.MapHeight
--     (el tamaño real del arte, sin el borde viejo del marco), y todos los
--     hijos (tiles, rellenos, etiquetas) se posicionan en sus coordenadas
--     NATIVAS de siempre SIN el offset FrameHoleX/FrameHoleY (esas
--     coordenadas ya estan en el espacio 0..1448 x 0..1086 del arte del
--     mapa -- confirmado revisando worldmap_data.lua, los poligonos de zona
--     y los tiles usan el mismo espacio 0-based). Con esto el mapa cubre
--     TODO self.mapContent siempre, asi que ya no hay ningun area vacia a
--     la que se pueda panear. Ademas, como red de seguridad visual (y
--     porque el usuario pidio un "marco con borde"), se agrega un fondo
--     oscuro fijo detras del viewport (self.viewportBg, mismo patron que
--     tooltipBg del punto 15) y un borde fino dorado alrededor del viewport
--     (self.viewportBorder*, 4 Controles solidos con SetBackColor, sin
--     ninguna imagen que escalar) -- asi si algun dia queda algun pixel de
--     borde por redondeo, se ve como parte del diseño (marco), nunca como
--     un error visual negro.
--
-- 18. RESALTADO DE ZONA AL PASAR EL MOUSE (pedido explicito del usuario:
--     "que sobre destaque del resto y sus bordes"): como no existe ninguna
--     API de relleno/borde vectorial en el motor real (punto 3), se
--     reutiliza el mismo mecanismo YA confirmado y en uso del relleno fijo
--     (mascara TGA con la forma exacta del poligono, Control:SetBackground
--     + BlendMode.AlphaBlend): por cada zona se crea una SEGUNDA copia
--     identica de esa misma mascara (mismo archivo, misma posicion/tamaño),
--     oculta (SetVisible(false)) por defecto. Al pasar el mouse sobre una
--     zona se muestra SOLO esa copia -- dibujar la misma mascara semi-
--     transparente DOS VECES apiladas la hace notablemente mas opaca/
--     saturada que el resto (que solo tienen una capa), lo cual resalta
--     tanto el color como el contorno exacto de esa zona (la mascara ya
--     tiene la forma real del poligono) sin necesitar ningun asset nuevo ni
--     ninguna API no confirmada.
--
-- 19. 5 MEJORAS PEDIDAS POR EL USUARIO ("dame opciones para mejorar este
--     addons" -> aprobo todas menos "ocultar etiquetas/rellenos"), cada una
--     grounded contra codigo real de otros addons YA instalados del mismo
--     usuario (TravelWindowII, CombatAnalysis, WhereToPlayV1.34, LUI):
--     a) Buscador de zonas: Turbine.UI.Lotro.TextBox + evento TextChanged
--        (confirmado real, mismo patron que QuestSyncWindow.searchBox de
--        LOTRO_Quest_Assistant), con debounce via el mismo hoverPoll de
--        siempre (no un control nuevo). Resalta las zonas que matchean
--        reusando el mecanismo del punto 18 (tercera copia apilada de la
--        mascara), y panea automaticamente a la primera coincidencia.
--     b) Recordar posicion/tamaño/pan de la ventana: Turbine.PluginData con
--        Turbine.DataScope.Character (mismo mecanismo YA en produccion en
--        worldmap_launcher.lua para la posicion del boton flotante). Como
--        no existe un evento PositionChanged confirmado, se detecta el
--        movimiento comparando posicion/tamaño/pan cuadro a cuadro dentro
--        del mismo hoverPoll, guardando (debounced) solo cuando deja de
--        cambiar.
--     c) Resaltado de zonas segun el nivel del jugador:
--        Turbine.Gameplay.LocalPlayer.GetInstance():GetLevel() (confirmado
--        real, WhereToPlayV1.34/PlayerStats.lua: "PlayerLvl =
--        Player:GetLevel()"). Reusa otra vez el mecanismo del punto 18
--        (cuarta copia apilada, permanente mientras la zona sea apropiada
--        para el nivel actual) + borde dorado en la etiqueta. Se recalcula
--        cada vez que la ventana se vuelve a mostrar (VisibleChanged).
--     d) Filtro manual de expansiones ("que DLC tenes"): NO existe ninguna
--        API real que exponga que expansiones compro el jugador (revisado
--        contra los 4 addons de referencia, ninguno lo hace) -- se le
--        pregunto directamente al usuario y eligio la opcion manual: un
--        menu (Turbine.UI.ContextMenu + Turbine.UI.MenuItem, mismo patron
--        YA en produccion en el menu del boton flotante) donde el jugador
--        tilda que expansiones tiene. Por defecto TODO visible (nada
--        oculto) hasta que el jugador destilda algo, para no sorprenderlo
--        la primera vez. Persistido con Turbine.PluginData en
--        Turbine.DataScope.Account (confirmado real, TravelWindowII/
--        Main.lua) -- una sola vez para todos sus personajes.
--     e) Atajo de teclado: revisando CombatAnalysis/Utils/KeyManager.lua y
--        WhereToPlayV1.34/MapWindow.lua se confirmo que SetWantsKeyEvents+
--        KeyDown existe, pero solo hay enums confirmados para teclas
--        especiales (Escape, F12) y capturar una tecla CUALQUIERA requiere
--        un hack de robo de foco documentado como fragil en el propio
--        addon de referencia -- demasiado riesgoso para este addon. En vez
--        de eso se agrega un comando de barra (Turbine.ShellCommand +
--        Turbine.Shell.AddCommand, confirmado real en TravelWindowII/
--        Main.lua: "trav,travel") en worldmap_launcher.lua: "/mapa" o
--        "/mapadelmundo" abre/cierra el mapa, y el jugador puede asignarle
--        una tecla el mismo creando una macro (funcion nativa del juego).
--     NO incluido (descartado explicitamente por el usuario via pregunta
--     directa): marcador de posicion en vivo del jugador / centrar en su
--     zona -- no existe ninguna API real de posicion continua (solo
--     LUI/Utils/coords.lua, que parsea a mano el TEXTO del comando nativo
--     "/loc", un valor manual de una sola vez, nunca una lectura en vivo).
--
-- 20. RONDA 2 de mejoras ("que mas podemos realizar con este addons"), el
--     usuario eligio 2 de 4 opciones ofrecidas:
--     a) Buscador mejorado: si lo que se escribe es solo numeros (ej.
--        "50"), se interpreta como NIVEL en vez de nombre (reusa
--        ParseNivelRange del punto 19c) y resalta/panea a las zonas cuyo
--        rango incluye ese nivel. Ademas el comando de barra ahora acepta
--        texto despues ("/mapa eregion" o "/mapa 50"): abre el mapa (si
--        hace falta lo crea) y deja la busqueda ya hecha, sin esperar el
--        debounce -- confirmado que Turbine.ShellCommand:Execute(command,
--        arguments) recibe el resto de la linea COMO UN SOLO STRING con
--        espacios incluidos (TravelWindowII/Main.lua compara literalmente
--        arguments == "debug on", prueba de que no se trocea en palabras).
--     b) Marcadores personalizados: click derecho en cualquier punto vacio
--        del mapa abre un dialogo chico (ventana sin chrome + TextBox real,
--        mismo patron ya probado del punto 19a) para escribir una nota
--        propia; al guardar aparece un pin (assets/worldmap/icon/
--        marker_pin.tga, generado con el mismo pipeline PIL que el resto
--        del arte). Click izquierdo en un pin muestra/oculta su nota (otra
--        ventana sin chrome + Label, mismo esqueleto de 2 piezas que ya usa
--        self.tooltip). Click derecho en un pin abre un menu de un solo
--        item ("Borrar este marcador", mismo ContextMenu/MenuItem del punto
--        19d). Se guardan con Turbine.PluginData por PERSONAJE (a
--        diferencia del filtro de expansiones, una nota como "comprar aca"
--        tiene sentido por personaje, no compartida con toda la cuenta).
--        Las coordenadas del click en un control HIJO (mapContent) llegan
--        YA en su espacio LOCAL (el mismo 0..MapWidth x 0..MapHeight nativo
--        de siempre, independiente de cuanto este paneado) -- confirmado
--        por como ya funciona el arrastre (punto 14): el delta de pan usa
--        args.X/Y de mapContent directamente sin restar nada, prueba de que
--        esas coordenadas no incluyen el pan. Para dibujar el dialogo/popup
--        en pantalla si hace falta convertir ESA coordenada nativa a
--        coordenada de ventana (sumando pan + VIEWPORT_TOP), nunca al reves.

import "Turbine"
import "Turbine.UI"
import "Turbine.UI.Lotro"
import "Turbine.Gameplay"

_G.WorldMapAddon = _G.WorldMapAddon or {}
WorldMapAddon.UI = WorldMapAddon.UI or {}

local Data = WorldMapAddon.Data
local TooltipData = WorldMapAddon.TooltipData
local Quests = WorldMapAddon.Quests

local RES_BASE = "WorldMap_Addon/assets/worldmap/"

-- Alto real del titulo nativo de una Turbine.UI.Lotro.Window, confirmado en
-- QuestBookWindow.lua/GatherWindow.lua de LOTRO_Quest_Assistant (constante
-- CHROME_TOP=40 ya validada ahi, no un numero nuevo sin probar). Todo el
-- contenido de nuestra ventana se corre este alto hacia abajo para no
-- quedar tapado por el titulo nativo.
local CHROME_TOP = 40

-- Punto 14: minimos de ventana/viewport, mismo estilo que GatherWindow.lua
-- (WINDOW_W_MIN=620/WINDOW_H_MIN_EXTRA=150 alla). Con 59 zonas + etiquetas
-- (mas densas que el mapa de recoleccion) se usa un minimo un poco mayor
-- para que siga siendo usable.
local WINDOW_W_MIN = 700
local VIEWPORT_H_MIN = 260

-- 16. BANNER DEL TITULO (pedido explicito del usuario: "el mismo nombre
--     central de Mapa del Mundo y con letra lotro"): una UNICA imagen fija
--     (title_banner.tga, generada por el usuario con el prompt que le di y
--     recortada/achicada aca de 876x170 a 480x93 -- un resize normal de UNA
--     sola imagen con PIL/LANCZOS, sin relacion con el bug de escalado del
--     punto 5: aquella vez el problema era redondear muchos tiles VECINOS
--     por separado y que quedaran desalineados entre si -- aca es una sola
--     imagen sola, sin vecinos con los que desalinearse). Se posiciona fija
--     (nunca se estira ni se re-escala con el resize de la ventana),
--     centrada horizontalmente, RECALCULANDO solo el X en SizeChanged (el
--     ancho de la ventana cambia, el banner no). Vive aparte del viewport
--     (no panea con el mapa -- es decoracion fija de la ventana, no
--     contenido del mapa), en su propia franja arriba, para no tapar
--     ninguna etiqueta de zona.
local BANNER_W = 480
local BANNER_H = 93
local BANNER_TOP_GAP = 4 -- separacion entre el chrome nativo y el banner
local BANNER_BOTTOM_GAP = 6 -- separacion entre el banner y la fila de busqueda/filtro

-- Punto 19a/19d: fila de buscador de zonas + boton de filtro de
-- expansiones, entre el banner y el viewport. SEARCH_ROW_TOP es donde
-- arrancaba antes el viewport (sin cambios de diseño ahi, solo se agrega
-- contenido nuevo en esa franja); el viewport ahora arranca mas abajo para
-- dejarle lugar.
local SEARCH_ROW_TOP = CHROME_TOP + BANNER_TOP_GAP + BANNER_H + BANNER_BOTTOM_GAP
local SEARCH_H = 24
local SEARCH_BOTTOM_GAP = 6 -- separacion entre esa fila y el viewport
local ROW_SIDE_MARGIN = 10
local ROW_GAP = 8 -- separacion horizontal entre el buscador y el boton de filtro
local FILTER_BTN_W = 150

-- Y donde arranca el viewport: debajo del chrome nativo, del banner fijo, Y
-- de la fila de buscador/filtro (punto 19).
local VIEWPORT_TOP = SEARCH_ROW_TOP + SEARCH_H + SEARCH_BOTTOM_GAP

-- Tamaño inicial de la ventana: bastante mas chico que el canvas nativo
-- completo (Data.FrameCanvasWidth x FrameCanvasHeight, ~1448x1086) para que
-- entre comodo en cualquier pantalla apenas se abre -- el jugador arrastra
-- el borde para agrandarla si quiere ver mas de una vez, o arrastra el
-- mapa (pan) para moverse.
local INITIAL_W = 900
local INITIAL_VIEWPORT_H = 620

-- Punto 17: borde/marco fino alrededor del viewport, color dorado (mismo
-- tono ya usado en el resto del addon: HexToColor("#C9A66B"), etiquetas de
-- nivel del tooltip). Simple color solido, no una imagen -- nada que
-- reescalar ni desalinear al agrandar/achicar la ventana.
local BORDER_W = 3
local BORDER_HEX = "#C9A66B"
local VIEWPORT_BG_HEX = "#141005"

-- Punto 19b/19d: claves de Turbine.PluginData. Posicion/tamaño/pan de la
-- ventana es POR PERSONAJE (Character, igual que worldmap_launcher.lua);
-- que expansiones tiene el jugador es de la CUENTA (Account, confirmado
-- real en TravelWindowII/Main.lua) -- se configura una vez y aplica a todos
-- los personajes del mismo dueño.
local WINDOW_STATE_KEY = "WorldMapAddon_WindowState"
local DLC_SAVE_KEY = "WorldMapAddon_OwnedExpansions"
local MARKERS_SAVE_KEY = "WorldMapAddon_Markers"

-- ---------------------------------------------------------------------
-- Punto-en-poligono (ray casting) y centroide real (formula del area con
-- signo) -- matematica pura, no depende del motor. Sin cambios respecto a
-- la version anterior (ya estaba probada).
-- ---------------------------------------------------------------------
local function PointInPolygon(px, py, poly)
    local inside = false
    local n = #poly
    local j = n
    for i = 1, n do
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        if ((yi > py) ~= (yj > py)) and
           (px < (xj - xi) * (py - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

local function FindZoneAt(mapX, mapY)
    for _, zone in ipairs(Data.Zones) do
        if PointInPolygon(mapX, mapY, zone.poligono) then
            return zone
        end
    end
    return nil
end

local function PolygonCentroid(poly)
    local n = #poly
    local area, cx, cy = 0, 0, 0
    for i = 1, n do
        local j = (i % n) + 1
        local xi, yi = poly[i].x, poly[i].y
        local xj, yj = poly[j].x, poly[j].y
        local cross = xi * yj - xj * yi
        area = area + cross
        cx = cx + (xi + xj) * cross
        cy = cy + (yi + yj) * cross
    end
    area = area / 2
    if area == 0 then
        local sx, sy = 0, 0
        for _, p in ipairs(poly) do sx = sx + p.x; sy = sy + p.y end
        return sx / n, sy / n
    end
    return cx / (6 * area), cy / (6 * area)
end

-- Punto 19c: zone.nivel es un string como "44-50" o un valor unico como
-- "130" (ver worldmap_data.lua) -- nunca un numero ya separado. Devuelve
-- lo/hi como numeros, o nil si no matchea ningun formato conocido.
local function ParseNivelRange(nivelStr)
    if type(nivelStr) ~= "string" then return nil, nil end
    local lo, hi = nivelStr:match("^(%d+)%s*-%s*(%d+)$")
    if lo then
        return tonumber(lo), tonumber(hi)
    end
    local single = nivelStr:match("^(%d+)$")
    if single then
        return tonumber(single), tonumber(single)
    end
    return nil, nil
end

-- "#RRGGBB" -> Turbine.UI.Color. Turbine.UI.Color(r,g,b[,a]) confirmado con
-- floats 0-1 (no 0-255) leyendo QuestInfoTooltip.lua/QuestBookWindow.lua de
-- LOTRO_Quest_Assistant (ej. Turbine.UI.Color(0.5, 0.42, 0.25)).
local function HexToColor(hex, alpha)
    local r = tonumber(hex:sub(2, 3), 16) / 255
    local g = tonumber(hex:sub(4, 5), 16) / 255
    local b = tonumber(hex:sub(6, 7), 16) / 255
    if alpha then
        return Turbine.UI.Color(r, g, b, alpha)
    end
    return Turbine.UI.Color(r, g, b)
end

-- ---------------------------------------------------------------------
-- Ventana principal del mapa
-- ---------------------------------------------------------------------

WorldMapAddon.UI.WorldMap = class(Turbine.UI.Lotro.Window)

function WorldMapAddon.UI.WorldMap:Constructor()
    Turbine.UI.Lotro.Window.Constructor(self)

    self:SetText("Mapa del Mundo")
    self:SetPosition(60, 40)
    self:SetSize(INITIAL_W, INITIAL_VIEWPORT_H + VIEWPORT_TOP)
    self:SetVisible(false)

    -- Punto 14: redimensionable desde el borde, mismo mecanismo real
    -- confirmado en produccion (GatherWindow.lua/QuestSyncWindow.lua):
    -- SetResizable(true) + SetMinimumSize + SizeChanged.
    self:SetResizable(true)
    self:SetMinimumSize(WINDOW_W_MIN, VIEWPORT_H_MIN + VIEWPORT_TOP)

    self.panX, self.panY = 0, 0
    self.dragging = false

    -- Punto 16: banner fijo del titulo, HIJO DE LA VENTANA (no del
    -- viewport/mapContent -- no panea con el mapa, es decoracion fija).
    -- Tamaño SIEMPRE BANNER_W x BANNER_H (nunca se estira); solo el X se
    -- recalcula en SizeChanged para seguir centrado.
    self.titleBanner = Turbine.UI.Control()
    self.titleBanner:SetParent(self)
    self.titleBanner:SetSize(BANNER_W, BANNER_H)
    self.titleBanner:SetPosition(math.floor((INITIAL_W - BANNER_W) / 2), CHROME_TOP + BANNER_TOP_GAP)
    self.titleBanner:SetBackground(RES_BASE .. "title_banner.tga")
    self.titleBanner:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
    self.titleBanner:SetMouseVisible(false)

    -- Punto 17: fondo fijo detras del viewport (mismo patron que tooltipBg
    -- del punto 15) -- red de seguridad visual: si alguna vez queda algun
    -- borde sin cubrir por el mapa, se ve de este color oscuro tematico en
    -- vez de negro puro (aspecto de "error"). Hijo de la ventana, DETRAS
    -- del viewport (creado antes).
    self.viewportBg = Turbine.UI.Control()
    self.viewportBg:SetParent(self)
    self.viewportBg:SetPosition(0, VIEWPORT_TOP)
    self.viewportBg:SetSize(INITIAL_W, INITIAL_VIEWPORT_H)
    self.viewportBg:SetBackColor(HexToColor(VIEWPORT_BG_HEX))
    self.viewportBg:SetMouseVisible(false)

    -- Viewport: tamaño = area visible, cambia con la ventana (SizeChanged
    -- mas abajo). Es el que RECORTA -- confirmado en vivo por el usuario
    -- con GatherWindow.lua (mismo mecanismo, ya en produccion).
    self.mapViewport = Turbine.UI.Control()
    self.mapViewport:SetParent(self)
    self.mapViewport:SetPosition(0, VIEWPORT_TOP)
    self.mapViewport:SetSize(INITIAL_W, INITIAL_VIEWPORT_H)
    self.mapViewport:SetMouseVisible(false)

    -- Contenido real del mapa -- SIEMPRE a tamaño NATIVO (nunca se achica
    -- ni se agranda), hijo del viewport, reposicionado por el arrastre
    -- (self.panX/panY) en vez de escalado. Sin SetMouseVisible(false):
    -- necesita recibir el arrastre (MouseDown/Move/Up/Leave mas abajo),
    -- igual que GatherWindow.mapControl. Punto 17: tamaño real del ARTE del
    -- mapa (Data.MapWidth x Data.MapHeight), no el viejo canvas del marco
    -- completo -- asi el mapa cubre siempre TODO el contenido paneable, sin
    -- ningun borde vacio al que se pueda panear.
    self.mapContent = Turbine.UI.Control()
    self.mapContent:SetParent(self.mapViewport)
    self.mapContent:SetPosition(0, 0)
    self.mapContent:SetSize(Data.MapWidth, Data.MapHeight)

    -- Punto 17: marco/borde fino dorado alrededor del viewport (pedido
    -- explicito del usuario: "entregame un marco con borde"). 4 Controles
    -- solidos (SetBackColor), sin ninguna imagen -- se reposicionan en
    -- SizeChanged junto con el viewport, sin nada que reescalar ni
    -- desalinear.
    self.borderTop = Turbine.UI.Control()
    self.borderTop:SetParent(self)
    self.borderTop:SetBackColor(HexToColor(BORDER_HEX))
    self.borderTop:SetMouseVisible(false)

    self.borderBottom = Turbine.UI.Control()
    self.borderBottom:SetParent(self)
    self.borderBottom:SetBackColor(HexToColor(BORDER_HEX))
    self.borderBottom:SetMouseVisible(false)

    self.borderLeft = Turbine.UI.Control()
    self.borderLeft:SetParent(self)
    self.borderLeft:SetBackColor(HexToColor(BORDER_HEX))
    self.borderLeft:SetMouseVisible(false)

    self.borderRight = Turbine.UI.Control()
    self.borderRight:SetParent(self)
    self.borderRight:SetBackColor(HexToColor(BORDER_HEX))
    self.borderRight:SetMouseVisible(false)

    self:_buildMap()
    self:_buildZoneFills()
    self:_buildLegend()
    self:_buildZoneLabels()
    self:_buildQuestBadges()
    self:_buildTooltip()
    self:_buildSearchBox()
    self:_buildDlcFilter()
    self:_buildMarkerUI()

    -- Arrastrar para centrar (clic apretado + mover), copiado tal cual del
    -- mecanismo real de GatherWindow.mapControl.MouseDown/Move/Up/Leave:
    -- delta contra la posicion del mouse al iniciar el arrastre (no la
    -- posicion absoluta), para que el mapa no "salte" al primer movimiento.
    local this = self
    self.mapContent.MouseDown = function(sender, args)
        -- Punto 20b: click derecho en el mapa = abrir el dialogo de "nuevo
        -- marcador" en vez de arrancar el arrastre. args.X/Y de un evento
        -- de mapContent ya son coordenadas NATIVAS (ver punto 20b del
        -- comentario grande): no hace falta restar el pan.
        if args.Button == Turbine.UI.MouseButton.Right then
            this:_promptNewMarker(args.X, args.Y)
            return
        end
        this.dragging = true
        this.dragMoved = false
        this.dragStartMouseX = args.X
        this.dragStartMouseY = args.Y
        this.dragStartPanX = this.panX
        this.dragStartPanY = this.panY
    end
    self.mapContent.MouseMove = function(sender, args)
        if this.dragging then
            -- v2.1: mas de 4px = arrastre; menos = clic (abre la lista de
            -- misiones de la zona, ver _onZoneClick)
            if math.abs(args.X - this.dragStartMouseX) > 4 or math.abs(args.Y - this.dragStartMouseY) > 4 then
                this.dragMoved = true
            end
            this.panX = this.dragStartPanX + (args.X - this.dragStartMouseX)
            this.panY = this.dragStartPanY + (args.Y - this.dragStartMouseY)
            this:_clampPan()
            this:_applyPan()
        end
    end
    self.mapContent.MouseUp = function(sender, args)
        local wasClick = this.dragging and not this.dragMoved
        this.dragging = false
        if wasClick and args.Button == Turbine.UI.MouseButton.Left then
            -- mapContent se mueve con el pan: args.X/Y ya son coordenadas
            -- NATIVAS del contenido (mismo criterio que el clic derecho de
            -- los marcadores, punto 20b)
            this:_onZoneClick(args.X, args.Y)
        end
    end
    -- Salvaguarda: si el mouse sale del control mientras se arrastra, se
    -- corta el arrastre en vez de arriesgar que quede "pegado" (mismo
    -- comentario/riesgo que GatherWindow.lua deja documentado).
    self.mapContent.MouseLeave = function()
        this.dragging = false
    end

    -- SizeChanged: mismo patron real de GatherWindow.lua/QuestSyncWindow.lua
    -- (definir la funcion y despues llamarla una vez a mano para el layout
    -- inicial -- la asignacion sola no dispara el evento).
    self.SizeChanged = function()
        local w, h = this:GetSize()
        if not w or not h then return end
        this.titleBanner:SetPosition(math.floor((w - BANNER_W) / 2), CHROME_TOP + BANNER_TOP_GAP)
        local viewportH = h - VIEWPORT_TOP
        if viewportH < 100 then viewportH = 100 end
        this.viewportBg:SetSize(w, viewportH)
        this.mapViewport:SetSize(w, viewportH)
        this:_layoutBorder(w, viewportH)
        this:_layoutSearchRow(w)
        this:_clampPan()
        this:_applyPan()
    end
    self.SizeChanged()

    -- Punto 19b: se intenta restaurar posicion/tamaño/pan guardados de la
    -- ultima vez (por personaje). Turbine.PluginData.Load es async (mismo
    -- patron que worldmap_launcher.lua) asi que el callback llega despues
    -- de terminar todo el Constructor -- por eso puede pedir self:SizeChanged()
    -- sin problema, ya existe para ese momento.
    Turbine.PluginData.Load(Turbine.DataScope.Character, WINDOW_STATE_KEY, function(state)
        if type(state) == "table" then
            if state.left and state.top then
                self:SetPosition(state.left, state.top)
            end
            if state.width and state.height then
                self:SetSize(state.width, state.height)
            end
            if state.panX then self.panX = state.panX end
            if state.panY then self.panY = state.panY end
            self:SizeChanged()
        end
    end)

    -- Punto 20b: restaura los marcadores guardados (por personaje). Cada
    -- uno reusa _addMarker con su id original, para no pisarlos si se
    -- agrega uno nuevo despues en la misma sesion.
    Turbine.PluginData.Load(Turbine.DataScope.Character, MARKERS_SAVE_KEY, function(data)
        if type(data) == "table" then
            for _, m in ipairs(data) do
                if type(m) == "table" and m.x and m.y and m.text then
                    self:_addMarker(m.x, m.y, m.text, m.id)
                end
            end
        end
    end)

    -- false, NUNCA nil: en un sistema de clases basado en metatablas (como
    -- el de este motor, class(Base)) asignar nil a un campo propio borra la
    -- entrada de la tabla en vez de guardar "sin valor", asi que la
    -- siguiente lectura cae al __index heredado en vez de leer el campo
    -- propio (confirmado con un arnes de prueba que simula ese
    -- comportamiento). false se guarda de verdad y evita el problema.
    self.hoveredZone = false

    -- Poll de hover (ver punto 4 en el comentario grande de arriba).
    self.hoverPoll = Turbine.UI.Control()
    self.hoverPoll:SetParent(self)
    self.hoverPoll:SetVisible(false)
    self.hoverPoll:SetWantsUpdates(true)
    self.hoverPoll.Update = function()
        this:_pollHover()
        -- v2.2: marcas doradas de misiones activas, cada 2 s con el mapa
        -- abierto (el conteo solo recorre las activas, es barato)
        local now = Turbine.Engine.GetGameTime()
        if this:IsVisible() and (this.badgesAt == nil or now - this.badgesAt > 2) then
            this.badgesAt = now
            this:_refreshQuestBadges()
        end
        -- Punto 19a: debounce del buscador -- no filtra en cada tecla, solo
        -- cuando el jugador deja de tipear un ratito (mismo patron real de
        -- QuestSyncWindow.searchDebounceControl, reusando este poll en vez
        -- de crear un control nuevo).
        if this.searchDirty and (Turbine.Engine.GetGameTime() - this.searchDirtyAt) > 0.35 then
            this.searchDirty = false
            this:_performSearch()
        end
        -- Punto 19b: detecta cambios de posicion/tamaño/pan cuadro a cuadro
        -- (no hay un evento PositionChanged confirmado) y los guarda recien
        -- cuando dejan de cambiar.
        this:_pollWindowState()
    end

    -- Punto 6 del comentario grande: si se cierra la ventana principal (con
    -- la X nativa), el tooltip flotante no puede quedar huerfano en
    -- pantalla. Mismo patron que QuestSyncWindow.lua usa para su
    -- "pointsPopup" via self.VisibleChanged. Punto 19c: cada vez que la
    -- ventana se vuelve a mostrar se recalcula el resaltado de nivel (el
    -- nivel del jugador puede haber cambiado desde la ultima vez).
    self.VisibleChanged = function()
        if not this:IsVisible() then
            this:_hideTooltip()
            this:_hideMarkerPopup()
            this.markerDialog:SetVisible(false)
            if this.questPanel then
                this.questPanel:SetVisible(false)
            end
        else
            this:_updateLevelHighlights()
            this:_refreshQuestBadges()
        end
    end
end

-- Punto 17: reposiciona los 4 Controles solidos del borde dorado alrededor
-- del rectangulo actual del viewport (w x viewportH, arrancando en (0,
-- VIEWPORT_TOP)). Se llama junto con el resize del viewport en SizeChanged.
function WorldMapAddon.UI.WorldMap:_layoutBorder(w, viewportH)
    self.borderTop:SetPosition(0, VIEWPORT_TOP - BORDER_W)
    self.borderTop:SetSize(w, BORDER_W)

    self.borderBottom:SetPosition(0, VIEWPORT_TOP + viewportH)
    self.borderBottom:SetSize(w, BORDER_W)

    self.borderLeft:SetPosition(0, VIEWPORT_TOP - BORDER_W)
    self.borderLeft:SetSize(BORDER_W, viewportH + BORDER_W * 2)

    self.borderRight:SetPosition(w - BORDER_W, VIEWPORT_TOP - BORDER_W)
    self.borderRight:SetSize(BORDER_W, viewportH + BORDER_W * 2)
end

-- Punto 19a/19d: reposiciona el buscador de zonas y el boton de filtro de
-- expansiones en su fila (entre el banner y el viewport), repartiendo el
-- ancho disponible de la ventana entre los dos.
function WorldMapAddon.UI.WorldMap:_layoutSearchRow(w)
    local filterX = w - ROW_SIDE_MARGIN - FILTER_BTN_W
    local searchW = filterX - ROW_GAP - ROW_SIDE_MARGIN
    if searchW < 80 then searchW = 80 end
    self.searchBox:SetPosition(ROW_SIDE_MARGIN, SEARCH_ROW_TOP)
    self.searchBox:SetSize(searchW, SEARCH_H)
    self.filterBtn:SetPosition(filterX, SEARCH_ROW_TOP)
    self.filterBtn:SetSize(FILTER_BTN_W, SEARCH_H)
end

-- Ajusta self.panX/panY para que el mapa nunca deje ver espacio en blanco
-- dentro del viewport (a menos que el mapa sea mas chico que el viewport en
-- ese eje, en cuyo caso se centra) -- copiado tal cual de
-- GatherWindow:ClampPan(). Punto 17: mw/mh es el tamaño REAL del arte del
-- mapa (Data.MapWidth/MapHeight), no el viejo canvas del marco completo.
function WorldMapAddon.UI.WorldMap:_clampPan()
    local vw, vh = self.mapViewport:GetSize()
    local mw, mh = Data.MapWidth, Data.MapHeight

    if mw <= vw then
        self.panX = math.floor((vw - mw) / 2)
    else
        if self.panX > 0 then self.panX = 0 end
        if self.panX < vw - mw then self.panX = vw - mw end
    end

    if mh <= vh then
        self.panY = math.floor((vh - mh) / 2)
    else
        if self.panY > 0 then self.panY = 0 end
        if self.panY < vh - mh then self.panY = vh - mh end
    end
end

function WorldMapAddon.UI.WorldMap:_applyPan()
    self.mapContent:SetPosition(self.panX, self.panY)
end

-- Los 36 tiles del mapa de fondo, a sus coordenadas NATIVAS de siempre
-- (tile.x/y, ya en el espacio 0..MapWidth x 0..MapHeight del arte del mapa
-- -- punto 17, sin el offset FrameHoleX/Y del viejo marco retirado), hijos
-- de self.mapContent (punto 14) en vez de la ventana directamente.
function WorldMapAddon.UI.WorldMap:_buildMap()
    for _, tile in ipairs(Data.Tiles) do
        local img = Turbine.UI.Control()
        img:SetParent(self.mapContent)
        img:SetPosition(tile.x, tile.y)
        img:SetSize(tile.w, tile.h)
        img:SetBackground(RES_BASE .. tile.file)
        img:SetMouseVisible(false)
    end
end

-- Relleno de zona CON LA FORMA REAL (poligono), semi-transparente y
-- SIEMPRE visible -- pedido explicito del usuario con una imagen de
-- referencia real (mapa comunitario "Map of LOTRO zones by level"): cada
-- zona coloreada con su forma exacta, dejando ver el terreno del mapa
-- atras. Como no existe una API de relleno vectorial en el motor (ver
-- punto 3 del comentario grande de arriba), se genero una mascara TGA por
-- zona (59 imagenes, RGBA, con la forma del poligono ya recortada y
-- coloreada) con el mismo pipeline que ya se uso para los tiles/iconos, y
-- aca simplemente se dibuja como Control:SetBackground(...). El campo
-- "relleno" (ruta al TGA) ya viene en worldmap_data.lua; la caja
-- delimitadora (bounding box) del poligono se calcula aca mismo.
function WorldMapAddon.UI.WorldMap:_buildZoneFills()
    self.zoneFills = {}
    self.zoneHighlights = {}
    -- Punto 19a/19c: dos capas apiladas MAS, mismo mecanismo exacto del
    -- punto 18 (misma mascara TGA, ocultas por defecto) -- una para el
    -- resultado del buscador y otra (permanente mientras aplique) para las
    -- zonas apropiadas al nivel del jugador. Independientes entre si y del
    -- resaltado de hover: cada una es su propio Control, se puede mostrar
    -- cualquier combinacion a la vez sin pisarse.
    self.zoneSearchHighlights = {}
    self.zoneLevelHighlights = {}
    for _, zone in ipairs(Data.Zones) do
        if zone.relleno then
            local minX, minY = math.huge, math.huge
            local maxX, maxY = -math.huge, -math.huge
            for _, p in ipairs(zone.poligono) do
                if p.x < minX then minX = p.x end
                if p.x > maxX then maxX = p.x end
                if p.y < minY then minY = p.y end
                if p.y > maxY then maxY = p.y end
            end
            -- Punto 17: sin el offset Data.FrameHoleX/Y (ya en el espacio
            -- nativo 0..MapWidth x 0..MapHeight del arte del mapa, igual
            -- que los tiles y los poligonos de zona).
            local fill = Turbine.UI.Control()
            fill:SetParent(self.mapContent)
            fill:SetPosition(minX, minY)
            fill:SetSize(maxX - minX, maxY - minY)
            -- zone.relleno ya trae la ruta completa (mismo patron que
            -- zone.imagen_referencia, usado igual en _showTooltipFor), no
            -- se concatena con RES_BASE de nuevo.
            fill:SetBackground(zone.relleno)
            fill:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
            fill:SetMouseVisible(false)
            self.zoneFills[zone] = fill

            -- Punto 18: segunda copia EXACTA de la misma mascara, oculta
            -- por defecto -- se muestra solo mientras el mouse esta sobre
            -- esta zona (ver _pollHover). Apilar la misma mascara semi-
            -- transparente dos veces la vuelve visiblemente mas opaca/
            -- saturada que las demas zonas (que solo tienen una capa),
            -- resaltando tanto el color como el contorno exacto del
            -- poligono (la mascara ya tiene esa forma), sin arte nuevo ni
            -- ninguna API de opacidad/borde no confirmada.
            local highlight = Turbine.UI.Control()
            highlight:SetParent(self.mapContent)
            highlight:SetPosition(minX, minY)
            highlight:SetSize(maxX - minX, maxY - minY)
            -- v2.0: imagen propia de hover (borde brillante + brillo), del
            -- MISMO tamaño que el relleno; si faltara, se usa el relleno
            -- como antes (misma mascara apilada).
            highlight:SetBackground(zone.resaltado or zone.relleno)
            highlight:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
            highlight:SetMouseVisible(false)
            highlight:SetVisible(false)
            self.zoneHighlights[zone] = highlight

            local searchHl = Turbine.UI.Control()
            searchHl:SetParent(self.mapContent)
            searchHl:SetPosition(minX, minY)
            searchHl:SetSize(maxX - minX, maxY - minY)
            searchHl:SetBackground(zone.resaltado or zone.relleno)
            searchHl:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
            searchHl:SetMouseVisible(false)
            searchHl:SetVisible(false)
            self.zoneSearchHighlights[zone] = searchHl

            local levelHl = Turbine.UI.Control()
            levelHl:SetParent(self.mapContent)
            levelHl:SetPosition(minX, minY)
            levelHl:SetSize(maxX - minX, maxY - minY)
            -- v2.0: marco dorado "zona de tu nivel" (distinto del hover
            -- para no confundir una zona resaltada por nivel con la zona
            -- que esta bajo el mouse).
            levelHl:SetBackground(zone.marco or zone.relleno)
            levelHl:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
            levelHl:SetMouseVisible(false)
            levelHl:SetVisible(false)
            self.zoneLevelHighlights[zone] = levelHl
        end
    end
end

-- Etiqueta fija de cada zona (nombre + nivel, en espanol). Coordenadas
-- NATIVAS de siempre (sin offset FrameHoleX/Y -- punto 17), hijas de
-- self.mapContent.
--
-- v2.0 -- arreglo del bug visual "se pierden textos por el porte": antes
-- era UN Label fijo de 170x38 con TrajanPro16 para nombre+nivel; dos
-- renglones de TrajanPro16 ya no entraban en 38px de alto y los nombres
-- largos no entraban en 170px de ancho -> el texto se cortaba. Ahora, igual
-- que el mapa de referencia ("Map of LOTRO zones by level"):
--   * nombre en blanco con contorno negro (Verdana12, la fuente ya usada en
--     todo el addon), partido en renglones de antemano (zone.etiqueta);
--   * nivel debajo, en un Label aparte color pergamino;
--   * el tamaño de cada Label se calcula segun la cantidad de renglones y
--     el ancho del texto (zone.etiqueta_w), con margen de sobra -- nunca se
--     recorta;
--   * el centro (zone.etiqueta_x/_y) sale del mapa de referencia y ya viene
--     ajustado para que ningun cartel se pise con el de al lado.
-- Si una zona no trae esos campos (datos viejos), se usa el nombre completo
-- en el centroide del poligono con un ancho amplio -- nunca falla.
local LABEL_LINE_H = 16
local LABEL_NAME_HEX = "#FFFFFF"
local LABEL_LEVEL_HEX = "#EEE0B4"

local function SplitLines(text)
    local lines = {}
    for line in (tostring(text) .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

function WorldMapAddon.UI.WorldMap:_buildZoneLabels()
    self.zoneLabels = {}
    self.zoneLevelLabels = {}
    for _, zone in ipairs(Data.Zones) do
        local cx, cy = zone.etiqueta_x, zone.etiqueta_y
        if not (cx and cy) then
            cx, cy = PolygonCentroid(zone.poligono)
        end
        local text = zone.etiqueta or zone.nombre or ""
        local nLines = #SplitLines(text)
        local hasLevel = zone.nivel ~= nil and tostring(zone.nivel) ~= ""
        local labelW = zone.etiqueta_w or 200
        if labelW < 60 then labelW = 60 end
        local nameH = nLines * LABEL_LINE_H + 2
        local totalH = nameH + (hasLevel and LABEL_LINE_H or 0)
        local left = math.floor(cx - labelW / 2)
        local top = math.floor(cy - totalH / 2)

        local label = Turbine.UI.Label()
        label:SetParent(self.mapContent)
        label:SetPosition(left, top)
        label:SetSize(labelW, nameH)
        label:SetFont(Turbine.UI.Lotro.Font.Verdana12)
        label:SetForeColor(HexToColor(LABEL_NAME_HEX))
        label:SetOutlineColor(Turbine.UI.Color(0, 0, 0))
        label:SetFontStyle(Turbine.UI.FontStyle.Outline)
        label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
        label:SetMultiline(true)
        label:SetMouseVisible(false)
        label:SetSelectable(false)
        label:SetText(text)
        self.zoneLabels[zone] = label

        if hasLevel then
            local levelLabel = Turbine.UI.Label()
            levelLabel:SetParent(self.mapContent)
            levelLabel:SetPosition(left, top + nameH - 2)
            levelLabel:SetSize(labelW, LABEL_LINE_H + 2)
            levelLabel:SetFont(Turbine.UI.Lotro.Font.Verdana12)
            levelLabel:SetForeColor(HexToColor(LABEL_LEVEL_HEX))
            levelLabel:SetOutlineColor(Turbine.UI.Color(0, 0, 0))
            levelLabel:SetFontStyle(Turbine.UI.FontStyle.Outline)
            levelLabel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
            levelLabel:SetMouseVisible(false)
            levelLabel:SetSelectable(false)
            levelLabel:SetText(tostring(zone.nivel))
            self.zoneLevelLabels[zone] = levelLabel
        end
    end
end

-- v2.2: marca dorada con el numero de misiones ACTIVAS de Quest Assistant
-- en cada zona (pedido del usuario). Una moneda dorada de 24x24
-- (icon/activas_24.tga, mismo formato TGA RLE 32 bits que el icono
-- flotante que ya se ve bien en el juego) justo encima del nombre de la
-- zona, con el numero encima. Hijas de mapContent, asi panean con el mapa;
-- se crean DESPUES de las etiquetas para quedar dibujadas encima. No
-- capturan el mouse (el arrastre, el clic y el hover siguen iguales). Sin
-- Quest Assistant o sin activas en la zona, no se ve nada.
local BADGE = 24
local BADGE_TOLERANCE = 72 -- px2 (1/8 de la marca)

-- ancho aproximado de un renglon en Verdana12 (~7 px por letra; los
-- bytes de continuacion UTF-8 no cuentan como letra)
local function ApproxTextW(line)
    local letters = #((line or ""):gsub("[\128-\191]", ""))
    return math.floor(letters * 7 + 0.5)
end

local function RectsOverlap(a, b)
    return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
end

-- Caja real (aproximada) del texto de cada zona: nombre en renglones +
-- nivel, centrada en etiqueta_x/etiqueta_y igual que _buildZoneLabels.
local function ZoneTextBox(zone)
    local cx, cy = zone.etiqueta_x, zone.etiqueta_y
    if not (cx and cy) then
        cx, cy = PolygonCentroid(zone.poligono)
    end
    local lines = SplitLines(zone.etiqueta or zone.nombre or "")
    local maxW = 0
    for _, line in ipairs(lines) do
        local w = ApproxTextW(line)
        if w > maxW then maxW = w end
    end
    local hasLevel = zone.nivel ~= nil and tostring(zone.nivel) ~= ""
    local totalH = #lines * LABEL_LINE_H + 2 + (hasLevel and LABEL_LINE_H or 0)
    local firstW = ApproxTextW(lines[1])
    return {
        cx = cx, cy = cy,
        x = math.floor(cx - maxW / 2), y = math.floor(cy - totalH / 2),
        w = maxW, h = totalH, firstW = firstW,
    }
end

-- v2.4: calaveras junto a la moneda (pedido del usuario, con sus propias
-- imagenes): calavera de ojos en llamas = hay una mision ACTIVA de
-- MAZMORRA de grupo en la zona; calavera de fuego = hay una de INCURSION
-- (raid). El dato de grupo es el de Quest Assistant (GroupQuestDB, ver
-- worldmap_quests.lua). Mismo tamaño (24x24) y mismo formato TGA que la
-- moneda; van en fila con ella, hacia afuera del nombre.
local SKULL_GAP = 2
local SKULL_STEP = BADGE + SKULL_GAP
local SKULL_IMAGES = {
    dungeon = "icon/calavera_mazmorra_24.tga",
    raid = "icon/calavera_incursion_24.tga",
}
local MINI = 16
local MINI_IMAGES = {
    dungeon = "icon/calavera_mazmorra_16.tga",
    raid = "icon/calavera_incursion_16.tga",
}

function WorldMapAddon.UI.WorldMap:_buildQuestBadges()
    self.questBadges = {}

    local boxes = {}
    for _, zone in ipairs(Data.Zones) do
        boxes[zone] = ZoneTextBox(zone)
    end

    -- La marca va pegada al nombre, donde no pise el texto de OTRA zona ni
    -- otra marca: a la derecha o a la izquierda del primer renglon, arriba
    -- o debajo (en ese orden), y si no, en una esquina de la etiqueta.
    -- v2.4: se calcula para 3 anchos (moneda sola, + 1 calavera, + 2); con
    -- la moneda sola da EXACTAMENTE la misma posicion que en v2.2. "rev" =
    -- la fila queda a la IZQUIERDA del nombre: la moneda va al final (la
    -- mas cercana al texto) y las calaveras hacia afuera.
    local function positionFor(zone, W, placed, strict)
        local t = boxes[zone]
        local half = math.floor(BADGE / 2)
        local firstMid = t.y + math.floor(LABEL_LINE_H / 2)
        local lastMid = t.y + t.h - math.floor(LABEL_LINE_H / 2)
        local right = math.floor(t.cx + t.w / 2)
        local left = math.floor(t.cx - t.w / 2)
        local halfW = math.floor(W / 2)
        local candidates = {
            { x = math.floor(t.cx + t.firstW / 2) + 2, y = firstMid - half },
            { x = math.floor(t.cx - t.firstW / 2) - W - 2, y = firstMid - half, rev = true },
            { x = math.floor(t.cx) - halfW, y = t.y - BADGE + 2 },
            { x = math.floor(t.cx) - halfW, y = t.y + t.h },
            { x = right + 2, y = t.y - BADGE + 6 },
            { x = left - W - 2, y = t.y - BADGE + 6, rev = true },
            { x = right + 2, y = lastMid - half },
            { x = left - W - 2, y = lastMid - half, rev = true },
            { x = right + 2, y = t.y + t.h - 6 },
            { x = left - W - 2, y = t.y + t.h - 6, rev = true },
        }
        -- con calaveras, si en fila no entra sin pisar otro nombre, se
        -- prueba en COLUMNA (moneda a la altura del nombre, calaveras hacia
        -- abajo o hacia arriba), pegada al costado del primer renglon
        if W > BADGE then
            local xr = math.floor(t.cx + t.firstW / 2) + 2
            local xl = math.floor(t.cx - t.firstW / 2) - BADGE - 2
            local down = firstMid - half
            local up = firstMid + half - W
            local extra = {
                { x = xr, y = down, vert = true },
                { x = xl, y = down, vert = true },
                { x = xr, y = up, vert = true, rev = true },
                { x = xl, y = up, vert = true, rev = true },
            }
            for _, c in ipairs(extra) do
                candidates[#candidates + 1] = c
            end
        end
        -- se queda con la primera posicion libre; si ninguna lo esta, con
        -- la que menos superficie pise (nunca encima de otra marca)
        local best, bestArea = nil, nil
        for _, c in ipairs(candidates) do
            local r = { x = c.x, y = c.y, w = W, h = BADGE, rev = c.rev == true, vert = c.vert == true }
            if r.vert then
                r.w, r.h = BADGE, W
            end
            local onBadge = false
            for _, pr in ipairs(placed) do
                if RectsOverlap(r, pr) then
                    onBadge = true
                    break
                end
            end
            if not onBadge then
                local area = 0
                for other, box in pairs(boxes) do
                    if other ~= zone and RectsOverlap(r, box) then
                        local ox = math.min(r.x + r.w, box.x + box.w) - math.max(r.x, box.x)
                        local oy = math.min(r.y + r.h, box.y + box.h) - math.max(r.y, box.y)
                        area = area + ox * oy
                    end
                end
                -- la caja de texto es aproximada (7 px por letra, algo
                -- generosa): rozar unos pocos pixeles no tapa letras
                if area <= BADGE_TOLERANCE then
                    return r
                end
                if bestArea == nil or area < bestArea then
                    best, bestArea = r, area
                end
            end
        end
        if strict then
            return nil -- sin lugar limpio pegado al nombre
        end
        return best or { x = candidates[1].x, y = candidates[1].y, w = W, h = BADGE }
    end

    -- Fila con calaveras: primero se busca lugar DENTRO del propio poligono
    -- de la zona (el centro de cada icono adentro), sin pisar ningun nombre (ni el
    -- propio) ni otra marca visible, lo mas cerca posible del nombre; en
    -- fila y, si no entra, en columna. Si la zona es muy chica para eso
    -- (zonas apretadas de Eriador/Moria), nil: se usa el modo COMPACTO --
    -- la moneda en su lugar de siempre y calaveras chicas (16 px) sobre sus
    -- esquinas de arriba, sin ocupar lugar nuevo en el mapa.
    local GRID = 4
    local function insideRect(zone, r)
        -- el centro de cada icono de la fila dentro de la zona (asi la fila
        -- "pertenece" a la zona a la vista, aunque el borde roce el limite)
        local poly = zone.poligono
        local n = math.floor((math.max(r.w, r.h) + SKULL_GAP) / SKULL_STEP)
        for i = 0, n - 1 do
            local cx = r.x + BADGE / 2 + (r.vert and 0 or i * SKULL_STEP)
            local cy = r.y + BADGE / 2 + (r.vert and i * SKULL_STEP or 0)
            if not PointInPolygon(cx, cy, poly) then
                return false
            end
        end
        return true
    end
    local function rowPositionFor(zone, W, placed)
        local t = boxes[zone]
        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        for _, p in ipairs(zone.poligono) do
            if p.x < minX then minX = p.x end
            if p.y < minY then minY = p.y end
            if p.x > maxX then maxX = p.x end
            if p.y > maxY then maxY = p.y end
        end
        local best, bestD = nil, nil
        for _, dims in ipairs({ { W, BADGE, false }, { BADGE, W, true } }) do
            local rw, rh, vert = dims[1], dims[2], dims[3]
            for y = math.floor(minY), math.floor(maxY - rh), GRID do
                for x = math.floor(minX), math.floor(maxX - rw), GRID do
                    local r = { x = x, y = y, w = rw, h = rh, vert = vert }
                    local ccx, ccy = x + rw / 2, y + rh / 2
                    local d = (ccx - t.cx) ^ 2 + (ccy - t.cy) ^ 2
                    if (bestD == nil or d < bestD) and insideRect(zone, r) then
                        local clash = false
                        for _, box in pairs(boxes) do
                            if RectsOverlap(r, box) then
                                clash = true
                                break
                            end
                        end
                        if not clash then
                            for _, pr in ipairs(placed) do
                                if RectsOverlap(r, pr) then
                                    clash = true
                                    break
                                end
                            end
                        end
                        if not clash then
                            best, bestD = r, d
                        end
                    end
                end
            end
            if best ~= nil then
                break -- en fila si entra; columna solo si no
            end
        end
        return best
    end
    -- orden: pegada al nombre (como la moneda sola) si hay lugar limpio;
    -- si no, dentro de la zona; si tampoco, nil = modo compacto
    self._badgeRowPositionFor = function(zone, W, placed)
        return positionFor(zone, W, placed, true) or rowPositionFor(zone, W, placed)
    end

    -- Moneda sola: posicion FIJA, calculada una vez para las 59 zonas
    -- juntas (identica a v2.2). Con calaveras la fila es mas ancha: su lugar
    -- se calcula al refrescar, solo contra los nombres de las otras zonas y
    -- las marcas que esten VISIBLES en ese momento (ver _refreshQuestBadges).
    local rectsByZone = {}
    local placedCoins = {}
    for _, zone in ipairs(Data.Zones) do
        local r = positionFor(zone, BADGE, placedCoins)
        placedCoins[#placedCoins + 1] = r
        rectsByZone[zone] = { r }
    end
    self._badgePositionFor = positionFor

    local function newIcon(image, size)
        local c = Turbine.UI.Control()
        c:SetParent(self.mapContent)
        c:SetSize(size or BADGE, size or BADGE)
        c:SetBackground(RES_BASE .. image)
        c:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
        c:SetMouseVisible(false)
        c:SetVisible(false)
        return c
    end

    for _, zone in ipairs(Data.Zones) do
        local rects = rectsByZone[zone]
        local r = rects[1]

        local badge = newIcon("icon/activas_24.tga")
        badge:SetPosition(r.x, r.y)

        local num = Turbine.UI.Label()
        num:SetParent(badge)
        num:SetPosition(0, 0)
        num:SetSize(BADGE, BADGE)
        num:SetFont(Turbine.UI.Lotro.Font.Verdana12)
        num:SetForeColor(HexToColor("#2A1A04"))
        num:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
        num:SetMouseVisible(false)
        num:SetSelectable(false)
        num:SetText("")

        self.questBadges[zone] = {
            badge = badge, num = num, count = 0, rects = rects,
            skulls = {
                dungeon = newIcon(SKULL_IMAGES.dungeon),
                raid = newIcon(SKULL_IMAGES.raid),
            },
            -- creadas despues de la moneda: se dibujan encima de ella
            mini = {
                dungeon = newIcon(MINI_IMAGES.dungeon, MINI),
                raid = newIcon(MINI_IMAGES.raid, MINI),
            },
            compact = false,
        }
    end
end

function WorldMapAddon.UI.WorldMap:_refreshQuestBadges()
    if not self.questBadges then
        return
    end
    local info = nil
    if Quests ~= nil and Quests.Available() then
        local ok, result = pcall(Quests.ActiveInfo)
        if ok then
            info = result
        end
    end
    -- 1) que se ve en cada zona
    local rows = {}
    for zone, b in pairs(self.questBadges) do
        local z = info and info[zone.nombre_original] or nil
        local n = z and z.count or 0
        local show = n > 0 and not (self.hiddenZones and self.hiddenZones[zone])
        if n ~= b.count then
            b.count = n
            b.num:SetText(n > 99 and "99" or tostring(n))
        end
        local wantD = show and z ~= nil and z.dungeon == true
        local wantR = show and z ~= nil and z.raid == true
        rows[zone] = { show = show, wantD = wantD, wantR = wantR,
            key = (wantD and "D" or "-") .. (wantR and "R" or "-") }
    end

    -- 2) firma de lo visible: solo se recalculan posiciones si cambio algo
    local sig = {}
    for _, zone in ipairs(Data.Zones) do
        local r = rows[zone]
        if r and r.show then
            sig[#sig + 1] = zone.nombre_original .. ":" .. r.key
        end
    end
    sig = table.concat(sig, "|")
    if sig ~= self._badgeSig then
        self._badgeSig = sig
        -- monedas solas: su lugar fijo; ocupan espacio para las filas
        local placed = {}
        for _, zone in ipairs(Data.Zones) do
            local r = rows[zone]
            if r and r.show and r.key == "--" then
                placed[#placed + 1] = self.questBadges[zone].rects[1]
            end
        end
        -- filas con calaveras: lugar libre segun lo que se ve ahora
        for _, zone in ipairs(Data.Zones) do
            local r = rows[zone]
            local b = self.questBadges[zone]
            if r and r.show then
                local ctls = { b.badge }
                if r.wantD then ctls[#ctls + 1] = b.skulls.dungeon end
                if r.wantR then ctls[#ctls + 1] = b.skulls.raid end
                local rect = b.rects[1]
                b.compact = false
                if #ctls > 1 then
                    local row = self._badgeRowPositionFor(zone, BADGE + (#ctls - 1) * SKULL_STEP, placed)
                    if row ~= nil then
                        rect = row
                        placed[#placed + 1] = rect
                    else
                        -- modo compacto: moneda en su lugar fijo + calaveras
                        -- chicas sobre sus esquinas de arriba
                        b.compact = true
                        ctls = { b.badge }
                        b.mini.dungeon:SetPosition(rect.x - 6, rect.y - 10)
                        b.mini.raid:SetPosition(rect.x + BADGE - 10, rect.y - 10)
                    end
                end
                for i, ctl in ipairs(ctls) do
                    local slot = rect.rev and (#ctls - i) or (i - 1)
                    if rect.vert then
                        ctl:SetPosition(rect.x, rect.y + slot * SKULL_STEP)
                    else
                        ctl:SetPosition(rect.x + slot * SKULL_STEP, rect.y)
                    end
                end
            end
        end
    end

    -- 3) visibilidad
    for zone, b in pairs(self.questBadges) do
        local r = rows[zone]
        b.badge:SetVisible(r.show)
        b.skulls.dungeon:SetVisible(r.wantD and not b.compact)
        b.skulls.raid:SetVisible(r.wantR and not b.compact)
        b.mini.dungeon:SetVisible(r.wantD and b.compact)
        b.mini.raid:SetVisible(r.wantR and b.compact)
    end
end

-- v2.0: leyenda de colores (volumenes epicos), imagen fija dentro del mapa
-- (esquina inferior izquierda, sobre el mar) -- mismo SetBackground +
-- AlphaBlend de los rellenos. No captura el mouse: arrastrar el mapa y el
-- clic derecho de marcadores siguen funcionando encima de ella.
function WorldMapAddon.UI.WorldMap:_buildLegend()
    local L = Data.Leyenda
    if not L then return end
    local legend = Turbine.UI.Control()
    legend:SetParent(self.mapContent)
    legend:SetPosition(L.x, L.y)
    legend:SetSize(L.w, L.h)
    legend:SetBackground(RES_BASE .. L.file)
    legend:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
    legend:SetMouseVisible(false)
    self.legend = legend
end

-- Punto 19a: buscador de zonas. Turbine.UI.Lotro.TextBox + TextChanged
-- confirmados reales (mismo patron que QuestSyncWindow.searchBox de
-- LOTRO_Quest_Assistant). No filtra en cada tecla -- solo marca "sucio" y
-- deja que el debounce de self.hoverPoll.Update dispare _performSearch()
-- un ratito despues de la ultima tecla.
function WorldMapAddon.UI.WorldMap:_buildSearchBox()
    self.searchBox = Turbine.UI.Lotro.TextBox()
    self.searchBox:SetParent(self)
    self.searchBox:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.searchBox:SetText("")
    self.searchDirty = false
    self.searchBox.TextChanged = function()
        self.searchDirty = true
        self.searchDirtyAt = Turbine.Engine.GetGameTime()
    end
end

-- Resalta (tercera capa apilada, punto 18/19a) todas las zonas que matchean
-- lo escrito, ignora las zonas ocultas por el filtro de expansiones (punto
-- 19d), y panea el mapa a la primera coincidencia para que el jugador la
-- vea sin tener que buscarla a ojo. Punto 20a: si lo escrito es SOLO
-- numeros se interpreta como un NIVEL (reusa ParseNivelRange del punto
-- 19c) en vez de nombre -- "50" resalta todas las zonas cuyo rango de
-- nivel incluye el 50, no las que se llamen "50".
function WorldMapAddon.UI.WorldMap:_performSearch()
    for _, ctrl in pairs(self.zoneSearchHighlights) do
        ctrl:SetVisible(false)
    end

    local query = self.searchBox:GetText()
    if not query then return end
    query = query:gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then
        return
    end

    local levelQuery = tonumber(query:match("^(%d+)$"))
    local lowerQuery = query:lower()

    local firstMatch = nil
    for _, zone in ipairs(Data.Zones) do
        if not (self.hiddenZones and self.hiddenZones[zone]) and self.zoneSearchHighlights[zone] then
            local matches
            if levelQuery then
                local lo, hi = ParseNivelRange(zone.nivel)
                matches = lo and levelQuery >= lo and levelQuery <= hi
            else
                matches = zone.nombre and string.find(zone.nombre:lower(), lowerQuery, 1, true) ~= nil
            end
            if matches then
                self.zoneSearchHighlights[zone]:SetVisible(true)
                if not firstMatch then firstMatch = zone end
            end
        end
    end

    if firstMatch then
        self:_panToZone(firstMatch)
    end
end

-- Punto 20a: usado por el comando de barra "/mapa <texto>" -- pone el texto
-- en el buscador y filtra YA MISMO (sin esperar el debounce de 0.35s: un
-- comando escrito a mano ya es una accion explicita del jugador, no hace
-- falta amortiguarla como al tipear letra por letra).
function WorldMapAddon.UI.WorldMap:_setSearchQuery(text)
    self.searchBox:SetText(text)
    self.searchDirty = false
    self:_performSearch()
end

-- Centra el viewport sobre el centroide de una zona (mismo _clampPan/
-- _applyPan de siempre, punto 14 -- nunca reescala, solo cambia panX/panY).
function WorldMapAddon.UI.WorldMap:_panToZone(zone)
    local cx, cy = PolygonCentroid(zone.poligono)
    local vw, vh = self.mapViewport:GetSize()
    self.panX = math.floor(vw / 2 - cx)
    self.panY = math.floor(vh / 2 - cy)
    self:_clampPan()
    self:_applyPan()
end

-- Punto 19c: resaltado (cuarta capa apilada) de las zonas cuyo rango de
-- nivel incluye el nivel actual del jugador, mas borde dorado en la
-- etiqueta. Turbine.Gameplay.LocalPlayer.GetInstance():GetLevel() esta
-- confirmado real (WhereToPlayV1.34/PlayerStats.lua) pero como es la
-- primera vez que se llama desde ESTE addon en particular, se envuelve en
-- pcall por las dudas -- si algo falla, simplemente no se resalta ninguna
-- zona por nivel (nunca rompe el resto del mapa).
function WorldMapAddon.UI.WorldMap:_updateLevelHighlights()
    local level = nil
    local ok, player = pcall(function() return Turbine.Gameplay.LocalPlayer.GetInstance() end)
    if ok and player then
        local ok2, lvl = pcall(function() return player:GetLevel() end)
        if ok2 and type(lvl) == "number" then
            level = lvl
        end
    end
    self.playerLevel = level

    for _, zone in ipairs(Data.Zones) do
        local appropriate = false
        if level and zone.nivel and not (self.hiddenZones and self.hiddenZones[zone]) then
            local lo, hi = ParseNivelRange(zone.nivel)
            if lo and level >= lo and level <= hi then
                appropriate = true
            end
        end
        if self.zoneLevelHighlights[zone] then
            self.zoneLevelHighlights[zone]:SetVisible(appropriate)
        end
        -- v2.0: el nombre Y el nivel (dos Labels) cambian de contorno juntos.
        local outline = appropriate and HexToColor(BORDER_HEX) or Turbine.UI.Color(0, 0, 0)
        if self.zoneLabels[zone] then
            self.zoneLabels[zone]:SetOutlineColor(outline)
        end
        if self.zoneLevelLabels and self.zoneLevelLabels[zone] then
            self.zoneLevelLabels[zone]:SetOutlineColor(outline)
        end
    end
end

-- Punto 19d: filtro manual de expansiones ("que DLC tenes"). No existe
-- ninguna API real de ownership (investigado contra 4 addons reales
-- instalados, ninguno lo hace) -- el usuario eligio explicitamente la
-- opcion manual via AskUserQuestion. Menu con un MenuItem tildable por
-- expansion (mismo Turbine.UI.ContextMenu/MenuItem YA en produccion en el
-- menu del boton flotante), persistido por CUENTA (no por personaje).
function WorldMapAddon.UI.WorldMap:_buildDlcFilter()
    -- Por defecto TODO visible (nada oculto) hasta que el jugador destilde
    -- algo -- para no sorprenderlo escondiendole zonas la primera vez que
    -- abre el mapa, antes de haber configurado nada.
    self.ownedExpansions = {}
    for _, exp in ipairs(Data.Expansions) do
        self.ownedExpansions[exp.key] = true
    end

    self.filterMenu = Turbine.UI.ContextMenu()
    self.filterMenuItems = {}
    for _, exp in ipairs(Data.Expansions) do
        local expKey = exp.key
        local item = Turbine.UI.MenuItem(self:_dlcItemText(exp))
        item.Click = function()
            self.ownedExpansions[expKey] = not self.ownedExpansions[expKey]
            item:SetText(self:_dlcItemText(exp))
            self:_applyDlcFilter()
            self:_saveDlcFilter()
        end
        self.filterMenu:GetItems():Add(item)
        self.filterMenuItems[expKey] = item
    end

    -- Boton (Label clickeable, mismo estilo/tecnica que ya se usa para el
    -- icono del launcher -- nunca Lotro.Button dentro de esta ventana, ver
    -- punto 1 del comentario grande) que abre el menu de arriba.
    self.filterBtn = Turbine.UI.Label()
    self.filterBtn:SetParent(self)
    self.filterBtn:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.filterBtn:SetForeColor(HexToColor(BORDER_HEX))
    self.filterBtn:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.filterBtn:SetText("Expansiones...")
    self.filterBtn:SetMouseVisible(true)
    self.filterBtn:SetSelectable(false)
    self.filterBtn.MouseClick = function()
        self.filterMenu:ShowMenu()
    end

    Turbine.PluginData.Load(Turbine.DataScope.Account, DLC_SAVE_KEY, function(data)
        if type(data) == "table" then
            for _, exp in ipairs(Data.Expansions) do
                if data[exp.key] ~= nil then
                    self.ownedExpansions[exp.key] = data[exp.key] == true
                end
            end
            for _, exp in ipairs(Data.Expansions) do
                if self.filterMenuItems[exp.key] then
                    self.filterMenuItems[exp.key]:SetText(self:_dlcItemText(exp))
                end
            end
        end
        self:_applyDlcFilter()
    end)
end

function WorldMapAddon.UI.WorldMap:_dlcItemText(exp)
    return (self.ownedExpansions[exp.key] and "[X] " or "[ ] ") .. exp.nombre
end

-- Oculta/muestra relleno + etiqueta de cada zona segun si su expansion
-- (zone.dlc_key) esta tildada como propia -- "base" (contenido gratuito)
-- nunca se filtra. Tambien apaga cualquier resaltado (hover/busqueda/nivel)
-- de una zona que quede oculta, y limpia el hover/tooltip si la zona bajo
-- el mouse justo desaparecio.
function WorldMapAddon.UI.WorldMap:_applyDlcFilter()
    self.hiddenZones = self.hiddenZones or {}
    for _, zone in ipairs(Data.Zones) do
        local visible = true
        if zone.dlc_key and zone.dlc_key ~= "base" then
            visible = self.ownedExpansions[zone.dlc_key] ~= false
        end
        self.hiddenZones[zone] = not visible
        if self.zoneFills[zone] then self.zoneFills[zone]:SetVisible(visible) end
        if self.zoneLabels[zone] then self.zoneLabels[zone]:SetVisible(visible) end
        if self.zoneLevelLabels and self.zoneLevelLabels[zone] then self.zoneLevelLabels[zone]:SetVisible(visible) end
        if not visible then
            if self.zoneHighlights[zone] then self.zoneHighlights[zone]:SetVisible(false) end
            if self.zoneSearchHighlights[zone] then self.zoneSearchHighlights[zone]:SetVisible(false) end
            if self.zoneLevelHighlights[zone] then self.zoneLevelHighlights[zone]:SetVisible(false) end
        end
    end

    if self.hoveredZone and self.hiddenZones[self.hoveredZone] then
        self.hoveredZone = false
        self:_hideTooltip()
    end

    self:_updateLevelHighlights()
    if self.questBadges then
        self:_refreshQuestBadges()
    end
end

function WorldMapAddon.UI.WorldMap:_saveDlcFilter()
    Turbine.PluginData.Save(Turbine.DataScope.Account, DLC_SAVE_KEY, self.ownedExpansions)
end

-- Punto 20b: marcadores personalizados. self.markers es un array de
-- { id, x, y (coordenadas NATIVAS del mapa, iguales a las de zone.poligono/
-- tile.x/y), text, control (el pin visual, hijo de self.mapContent -- panea
-- solo junto con el resto del mapa, sin cuenta nueva). Arma las 2 ventanas
-- chicas sin chrome que hacen falta (dialogo para escribir una nota nueva,
-- popup para mostrar la de un pin existente) + el menu de borrado, todo con
-- el mismo esqueleto ya probado del tooltip de zona (punto 2/15).
function WorldMapAddon.UI.WorldMap:_buildMarkerUI()
    self.markers = {}
    self.nextMarkerId = 1

    self.markerPopup = Turbine.UI.Window()
    self.markerPopup:SetSize(220, 90)
    self.markerPopup:SetBackColor(Turbine.UI.Color(0.06, 0.05, 0.03))
    self.markerPopup:SetZOrder(0x7FFFFFFF)
    self.markerPopup:SetVisible(false)

    self.markerPopupBg = Turbine.UI.Control()
    self.markerPopupBg:SetParent(self.markerPopup)
    self.markerPopupBg:SetPosition(0, 0)
    self.markerPopupBg:SetSize(220, 90)
    self.markerPopupBg:SetBackColor(Turbine.UI.Color(0.06, 0.05, 0.03))
    self.markerPopupBg:SetMouseVisible(false)

    self.markerPopupText = Turbine.UI.Label()
    self.markerPopupText:SetParent(self.markerPopup)
    self.markerPopupText:SetPosition(8, 8)
    self.markerPopupText:SetSize(204, 74)
    self.markerPopupText:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.markerPopupText:SetForeColor(HexToColor("#CFCFCF"))
    self.markerPopupText:SetMultiline(true)
    self.markerPopupText:SetMouseVisible(false)

    self.markerDialog = Turbine.UI.Window()
    self.markerDialog:SetSize(260, 110)
    self.markerDialog:SetBackColor(Turbine.UI.Color(0.06, 0.05, 0.03))
    self.markerDialog:SetZOrder(0x7FFFFFFF)
    self.markerDialog:SetVisible(false)

    self.markerDialogBg = Turbine.UI.Control()
    self.markerDialogBg:SetParent(self.markerDialog)
    self.markerDialogBg:SetPosition(0, 0)
    self.markerDialogBg:SetSize(260, 110)
    self.markerDialogBg:SetBackColor(Turbine.UI.Color(0.06, 0.05, 0.03))
    self.markerDialogBg:SetMouseVisible(false)

    self.markerDialogLabel = Turbine.UI.Label()
    self.markerDialogLabel:SetParent(self.markerDialog)
    self.markerDialogLabel:SetPosition(8, 6)
    self.markerDialogLabel:SetSize(244, 18)
    self.markerDialogLabel:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.markerDialogLabel:SetForeColor(HexToColor(BORDER_HEX))
    self.markerDialogLabel:SetText("Nota del marcador:")
    self.markerDialogLabel:SetMouseVisible(false)

    self.markerDialogInput = Turbine.UI.Lotro.TextBox()
    self.markerDialogInput:SetParent(self.markerDialog)
    self.markerDialogInput:SetPosition(8, 26)
    self.markerDialogInput:SetSize(244, 24)
    self.markerDialogInput:SetFont(Turbine.UI.Lotro.Font.Verdana12)

    -- Botones "Guardar"/"Cancelar" como Labels clickeables (mismo truco que
    -- self.filterBtn -- nunca Lotro.Button dentro de esta ventana, punto 1).
    self.markerDialogSave = Turbine.UI.Label()
    self.markerDialogSave:SetParent(self.markerDialog)
    self.markerDialogSave:SetPosition(8, 60)
    self.markerDialogSave:SetSize(115, 30)
    self.markerDialogSave:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.markerDialogSave:SetForeColor(HexToColor(BORDER_HEX))
    self.markerDialogSave:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.markerDialogSave:SetText("Guardar")
    self.markerDialogSave:SetMouseVisible(true)
    self.markerDialogSave:SetSelectable(false)

    self.markerDialogCancel = Turbine.UI.Label()
    self.markerDialogCancel:SetParent(self.markerDialog)
    self.markerDialogCancel:SetPosition(137, 60)
    self.markerDialogCancel:SetSize(115, 30)
    self.markerDialogCancel:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.markerDialogCancel:SetForeColor(HexToColor("#CFCFCF"))
    self.markerDialogCancel:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.markerDialogCancel:SetText("Cancelar")
    self.markerDialogCancel:SetMouseVisible(true)
    self.markerDialogCancel:SetSelectable(false)

    self.markerDialogSave.MouseClick = function()
        self:_saveNewMarker()
    end
    self.markerDialogCancel.MouseClick = function()
        self.markerDialog:SetVisible(false)
    end

    self.markerDeleteMenu = Turbine.UI.ContextMenu()
    self.markerDeleteMenuItem = Turbine.UI.MenuItem("Borrar este marcador")
    self.markerDeleteMenuItem.Click = function()
        if self.markerContextTarget then
            self:_deleteMarker(self.markerContextTarget)
            self.markerContextTarget = nil
        end
    end
    self.markerDeleteMenu:GetItems():Add(self.markerDeleteMenuItem)
end

-- Convierte una coordenada NATIVA del mapa (mismo espacio que
-- zone.poligono/tile.x/y, 0..MapWidth x 0..MapHeight) a coordenada de
-- PANTALLA absoluta -- necesario para posicionar el dialogo/popup, que son
-- ventanas top-level (sin SetParent posible entre Windows, igual que el
-- tooltip de zona, punto 696 del comentario original).
function WorldMapAddon.UI.WorldMap:_mapToScreen(mapX, mapY)
    local winLeft, winTop = self:GetPosition()
    return winLeft + self.panX + mapX, winTop + VIEWPORT_TOP + self.panY + mapY
end

-- Mismo clamp contra pantalla que _showTooltipFor, factorizado aca para
-- reusarlo con el dialogo y el popup de marcadores.
function WorldMapAddon.UI.WorldMap:_clampToScreen(x, y, w, h)
    local maxX = Turbine.UI.Display.GetWidth() - w
    local maxY = Turbine.UI.Display.GetHeight() - h
    if x > maxX then x = maxX end
    if y > maxY then y = maxY end
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    return x, y
end

-- Click derecho en un punto VACIO del mapa (mapX/mapY ya son coordenadas
-- nativas, ver punto 20b): abre el dialogo para escribir la nota.
function WorldMapAddon.UI.WorldMap:_promptNewMarker(mapX, mapY)
    self.pendingMarkerX = mapX
    self.pendingMarkerY = mapY
    self.markerDialogInput:SetText("")
    self:_hideMarkerPopup()
    local sx, sy = self:_mapToScreen(mapX, mapY)
    sx, sy = self:_clampToScreen(sx, sy, 260, 110)
    self.markerDialog:SetPosition(sx, sy)
    self.markerDialog:SetVisible(true)
end

function WorldMapAddon.UI.WorldMap:_saveNewMarker()
    local text = self.markerDialogInput:GetText()
    self.markerDialog:SetVisible(false)
    if not text or text:match("^%s*$") then
        return -- nota vacia: no crea nada
    end
    self:_addMarker(self.pendingMarkerX, self.pendingMarkerY, text)
    self:_saveMarkers()
end

-- Crea el pin visual + su entrada en self.markers. "id" se pasa solo al
-- restaurar marcadores guardados (para no pisar ids ya usados); si no se
-- pasa, se genera uno nuevo con self.nextMarkerId.
function WorldMapAddon.UI.WorldMap:_addMarker(mapX, mapY, text, id)
    local markerId = id or self.nextMarkerId
    if id and id >= self.nextMarkerId then
        self.nextMarkerId = id + 1
    elseif not id then
        self.nextMarkerId = self.nextMarkerId + 1
    end

    local icon = Turbine.UI.Control()
    icon:SetParent(self.mapContent)
    icon:SetSize(20, 20)
    -- La "punta" del pin (ver marker_pin.tga, generado con la cola abajo)
    -- apunta exactamente al punto clickeado, no la esquina del icono.
    icon:SetPosition(mapX - 10, mapY - 17)
    icon:SetBackground(RES_BASE .. "icon/marker_pin.tga")
    icon:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
    icon:SetMouseVisible(true)

    local marker = { id = markerId, x = mapX, y = mapY, text = text, control = icon }
    self.markers[#self.markers + 1] = marker

    icon.MouseUp = function(sender, args)
        if args.Button == Turbine.UI.MouseButton.Left then
            self:_toggleMarkerPopup(marker)
        elseif args.Button == Turbine.UI.MouseButton.Right then
            self.markerContextTarget = marker
            self.markerDeleteMenu:ShowMenu()
        end
    end

    return marker
end

function WorldMapAddon.UI.WorldMap:_toggleMarkerPopup(marker)
    if self.activeMarkerPopup == marker and self.markerPopup:IsVisible() then
        self:_hideMarkerPopup()
        return
    end
    self.markerPopupText:SetText(marker.text)
    local sx, sy = self:_mapToScreen(marker.x, marker.y)
    sx, sy = self:_clampToScreen(sx + 12, sy + 12, 220, 90)
    self.markerPopup:SetPosition(sx, sy)
    self.markerPopup:SetVisible(true)
    self.activeMarkerPopup = marker
end

function WorldMapAddon.UI.WorldMap:_hideMarkerPopup()
    self.markerPopup:SetVisible(false)
    self.activeMarkerPopup = nil
end

-- No hay ningun Destroy()/RemoveChild() confirmado en ningun addon real
-- leido en toda esta sesion -- "borrar" un marcador lo oculta y le saca el
-- mouse para siempre (mismo criterio ya usado en todo el resto del addon:
-- ocultar, nunca asumir una API de destruccion no confirmada).
function WorldMapAddon.UI.WorldMap:_deleteMarker(marker)
    for i, m in ipairs(self.markers) do
        if m == marker then
            table.remove(self.markers, i)
            break
        end
    end
    marker.control:SetVisible(false)
    marker.control:SetMouseVisible(false)
    if self.activeMarkerPopup == marker then
        self:_hideMarkerPopup()
    end
    self:_saveMarkers()
end

function WorldMapAddon.UI.WorldMap:_saveMarkers()
    local data = {}
    for _, m in ipairs(self.markers) do
        data[#data + 1] = { id = m.id, x = m.x, y = m.y, text = m.text }
    end
    Turbine.PluginData.Save(Turbine.DataScope.Character, MARKERS_SAVE_KEY, data)
end

-- Ventana flotante de info de zona: Turbine.UI.Window sin chrome (ver punto
-- 2 del comentario grande de arriba), con el marco real (14 piezas) como
-- fondo y los 5 campos de texto/imagen en las coordenadas exactas medidas
-- sobre ese marco (TooltipData.Holes). Ventana top-level, no cambia con el
-- viewport/pan del mapa.
function WorldMapAddon.UI.WorldMap:_buildTooltip()
    self.tooltip = Turbine.UI.Window()
    self.tooltip:SetSize(TooltipData.CanvasWidth, TooltipData.CanvasHeight)
    -- 15. SIGUE SIN VERSE EL FONDO (reporte real del usuario, otra vez):
    --     el intento anterior (punto 7) le ponia SetBackColor a la VENTANA
    --     con un color de 4 numeros (r,g,b,ALPHA). Releyendo
    --     QuestInfoTooltip.lua de LOTRO_Quest_Assistant con mas cuidado
    --     (la referencia real que ya se uso para el patron "ventana sin
    --     chrome"), su SetBackColor usa SOLO 3 numeros (r,g,b, SIN alpha) --
    --     "self:SetBackColor(Turbine.UI.Color(0.5, 0.42, 0.25))" -- y
    --     ademas agrega un Control HIJO aparte ("self.inner") con su PROPIO
    --     SetBackColor solido para el area de texto, en vez de confiar
    --     solo en el color de la ventana. El 4to numero (alpha) en
    --     SetBackColor de una Window nunca estuvo confirmado en ningun
    --     archivo real -- era una suposicion. Se corrige copiando el
    --     patron exacto: SetBackColor de la ventana con 3 numeros (sirve
    --     de "marco"), MAS un Control solido aparte (self.tooltipBg,
    --     mismo rol que "inner") del tamaño COMPLETO del tooltip, creado
    --     ANTES que los tiles/etiquetas para quedar atras de todo.
    self.tooltip:SetBackColor(Turbine.UI.Color(0.06, 0.05, 0.03))
    self.tooltip:SetZOrder(0x7FFFFFFF)
    self.tooltip:SetVisible(false)

    self.tooltipBg = Turbine.UI.Control()
    self.tooltipBg:SetParent(self.tooltip)
    self.tooltipBg:SetPosition(0, 0)
    self.tooltipBg:SetSize(TooltipData.CanvasWidth, TooltipData.CanvasHeight)
    self.tooltipBg:SetBackColor(Turbine.UI.Color(0.06, 0.05, 0.03))
    self.tooltipBg:SetMouseVisible(false)

    for _, tile in ipairs(TooltipData.Tiles) do
        local img = Turbine.UI.Control()
        img:SetParent(self.tooltip)
        img:SetPosition(tile.x, tile.y)
        img:SetSize(tile.w, tile.h)
        img:SetBackground(RES_BASE .. tile.file)
        img:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
        img:SetMouseVisible(false)
    end

    local H = TooltipData.Holes

    self.tooltipTitle = Turbine.UI.Label()
    self.tooltipTitle:SetParent(self.tooltip)
    self.tooltipTitle:SetPosition(H.nombre.x, H.nombre.y)
    self.tooltipTitle:SetSize(H.nombre.w, H.nombre.h)
    self.tooltipTitle:SetFont(Turbine.UI.Lotro.Font.TrajanPro16)
    self.tooltipTitle:SetForeColor(HexToColor("#F0D9A0"))
    self.tooltipTitle:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.tooltipTitle:SetMouseVisible(false)

    self.tooltipImage = Turbine.UI.Control()
    self.tooltipImage:SetParent(self.tooltip)
    self.tooltipImage:SetPosition(H.imagen.x, H.imagen.y)
    self.tooltipImage:SetSize(H.imagen.w, H.imagen.h)
    self.tooltipImage:SetMouseVisible(false)

    self.tooltipQuestInfo = Turbine.UI.Label()
    self.tooltipQuestInfo:SetParent(self.tooltip)
    self.tooltipQuestInfo:SetPosition(H.intro.x, H.intro.y)
    self.tooltipQuestInfo:SetSize(H.intro.w, H.intro.h)
    self.tooltipQuestInfo:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.tooltipQuestInfo:SetForeColor(HexToColor("#CFCFCF"))
    self.tooltipQuestInfo:SetMultiline(true)
    self.tooltipQuestInfo:SetMouseVisible(false)

    self.tooltipLevel = Turbine.UI.Label()
    self.tooltipLevel:SetParent(self.tooltip)
    self.tooltipLevel:SetPosition(H.nivel.x, H.nivel.y)
    self.tooltipLevel:SetSize(H.nivel.w, H.nivel.h)
    self.tooltipLevel:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.tooltipLevel:SetForeColor(HexToColor("#C9A66B"))
    self.tooltipLevel:SetMouseVisible(false)

    self.tooltipDlc = Turbine.UI.Label()
    self.tooltipDlc:SetParent(self.tooltip)
    self.tooltipDlc:SetPosition(H.dlc.x, H.dlc.y)
    self.tooltipDlc:SetSize(H.dlc.w, H.dlc.h)
    self.tooltipDlc:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.tooltipDlc:SetForeColor(HexToColor("#C9A66B"))
    self.tooltipDlc:SetMouseVisible(false)

    -- v2.1: renglon de Quest Assistant sobre el cuero de abajo (entre los
    -- dos adornos de las esquinas, fuera de los 5 huecos del marco)
    self.tooltipQuests = Turbine.UI.Label()
    self.tooltipQuests:SetParent(self.tooltip)
    self.tooltipQuests:SetPosition(40, 288)
    self.tooltipQuests:SetSize(TooltipData.CanvasWidth - 80, 30)
    self.tooltipQuests:SetMultiline(true)
    self.tooltipQuests:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.tooltipQuests:SetForeColor(HexToColor("#F0D9A0"))
    self.tooltipQuests:SetFontStyle(Turbine.UI.FontStyle.Outline)
    self.tooltipQuests:SetOutlineColor(Turbine.UI.Color(0, 0, 0))
    self.tooltipQuests:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.tooltipQuests:SetMouseVisible(false)
    self.tooltipQuests:SetText("")
end

-- La ventana del tooltip es independiente (top-level, sin SetParent posible
-- entre Windows), asi que su posicion se calcula en espacio de pantalla
-- absoluto: posicion de la ventana del mapa + coordenadas locales del mouse
-- DENTRO DE LA VENTANA (localX/localY, sin restar pan -- son coordenadas de
-- pantalla, no del contenido paneado). Se aprieta (clamp) contra
-- Turbine.UI.Display.GetWidth/Height para que el tooltip completo quede
-- siempre visible.
function WorldMapAddon.UI.WorldMap:_showTooltipFor(zone, localX, localY)
    local winLeft, winTop = self:GetPosition()
    local tx = winLeft + localX + 16
    local ty = winTop + localY + 16
    local maxX = Turbine.UI.Display.GetWidth() - TooltipData.CanvasWidth
    local maxY = Turbine.UI.Display.GetHeight() - TooltipData.CanvasHeight
    if tx > maxX then tx = maxX end
    if ty > maxY then ty = maxY end
    if tx < 0 then tx = 0 end
    if ty < 0 then ty = 0 end
    self.tooltip:SetPosition(tx, ty)
    self.tooltip:SetVisible(true)

    local nombreTxt = zone.nombre
    local nivelTxt = "Nivel " .. tostring(zone.nivel)
    if zone.estimado then
        nivelTxt = nivelTxt .. "  (contenido nuevo, ubicacion estimada)"
    end
    local introTxt = zone.descripcion or "Info de la zona no disponible todavia."
    local dlcTxt = zone.dlc and ("Requiere: " .. tostring(zone.dlc)) or "DLC requerido: pendiente"

    self.tooltipTitle:SetText(nombreTxt)
    self.tooltipLevel:SetText(nivelTxt)
    self.tooltipQuestInfo:SetText(introTxt)
    self.tooltipDlc:SetText(dlcTxt)

    -- v2.1: resumen de Quest Assistant; se recalcula solo al cambiar de
    -- zona (esta funcion corre en cada cuadro del hover)
    if self.tooltipQuestsZone ~= zone then
        self.tooltipQuestsZone = zone
        local summary = ""
        if Quests ~= nil and Quests.Available() then
            summary = Quests.SummaryText(zone)
            if summary == "" then
                summary = "Sin misiones activas en esta zona"
            else
                summary = summary .. "\nClic en la zona: verlas"
            end
        end
        self.tooltipQuests:SetText(summary)
    end

    if zone.imagen_referencia then
        self.tooltipImage:SetBackground(zone.imagen_referencia)
    end
end

function WorldMapAddon.UI.WorldMap:_hideTooltip()
    self.tooltip:SetVisible(false)
    -- al volver a entrar a la misma zona se refresca el resumen (pudo
    -- cambiar el progreso de misiones mientras tanto)
    self.tooltipQuestsZone = nil
end

-- Punto 19b: no existe un evento PositionChanged confirmado (solo
-- SizeChanged), asi que la posicion se vigila a mano, cuadro a cuadro,
-- desde el mismo hoverPoll de siempre. Cualquier cambio de posicion,
-- tamaño o pan marca "sucio"; recien se guarda cuando pasa un segundo sin
-- ningun cambio nuevo (evita guardar en cada cuadro mientras se arrastra o
-- se redimensiona).
function WorldMapAddon.UI.WorldMap:_pollWindowState()
    local left, top = self:GetPosition()
    local w, h = self:GetSize()
    if left ~= self.lastLeft or top ~= self.lastTop
        or w ~= self.lastW or h ~= self.lastH
        or self.panX ~= self.lastPanX or self.panY ~= self.lastPanY then
        self.lastLeft, self.lastTop = left, top
        self.lastW, self.lastH = w, h
        self.lastPanX, self.lastPanY = self.panX, self.panY
        self.stateDirty = true
        self.stateDirtyAt = Turbine.Engine.GetGameTime()
    elseif self.stateDirty and (Turbine.Engine.GetGameTime() - self.stateDirtyAt) > 1.0 then
        self.stateDirty = false
        self:_saveWindowState()
    end
end

function WorldMapAddon.UI.WorldMap:_saveWindowState()
    local left, top = self:GetPosition()
    local w, h = self:GetSize()
    Turbine.PluginData.Save(Turbine.DataScope.Character, WINDOW_STATE_KEY, {
        left = left, top = top,
        width = w, height = h,
        panX = self.panX, panY = self.panY,
    })
end

function WorldMapAddon.UI.WorldMap:_pollHover()
    -- Si la ventana esta oculta (se acaba de cerrar con la X nativa) no
    -- hay nada que resaltar ni ningun tooltip que mostrar -- evita que un
    -- poll que llegue a dispararse igual reabra el tooltip huerfano
    -- (ver punto 6 del comentario grande de arriba).
    if not self:IsVisible() then
        return
    end

    local mx, my = self:GetMousePosition()

    -- No hacer hover mientras se esta arrastrando el mapa (el usuario esta
    -- moviendolo, no señalando una zona) ni fuera del viewport (arriba de
    -- VIEWPORT_TOP: chrome nativo + banner del titulo, punto 16).
    if self.dragging or my < VIEWPORT_TOP then
        if self.hoveredZone then
            if self.zoneHighlights[self.hoveredZone] then
                self.zoneHighlights[self.hoveredZone]:SetVisible(false)
            end
            self.hoveredZone = false
            self:_hideTooltip()
        end
        return
    end

    -- Punto 14: mx/my son coordenadas de VENTANA; el mapa esta paneado
    -- (self.panX/panY) dentro de self.mapViewport (que arranca en (0,
    -- VIEWPORT_TOP)), y los poligonos de zona estan en el espacio NATIVO del
    -- contenido. Hay que deshacer el offset del viewport Y el pan antes de
    -- comparar. Punto 17: sin el offset Data.FrameHoleX/Y (retirado, el
    -- contenido ya arranca en (0,0) = esquina del arte real del mapa).
    local mapX = mx - self.panX
    local mapY = (my - VIEWPORT_TOP) - self.panY
    local zone = FindZoneAt(mapX, mapY) or false -- normaliza nil -> false, ver Constructor

    -- Punto 19d: una zona oculta por el filtro de expansiones no tiene
    -- relleno visible bajo el mouse -- no debe generar hover ni tooltip.
    if zone and self.hiddenZones and self.hiddenZones[zone] then
        zone = false
    end

    if zone == self.hoveredZone then
        if zone then
            self:_showTooltipFor(zone, mx, my)
        end
        return
    end

    -- Punto 18: al cambiar de zona resaltada, oculta el resaltado de la
    -- zona anterior (si tenia) y muestra el de la nueva (si hay).
    if self.hoveredZone and self.zoneHighlights[self.hoveredZone] then
        self.zoneHighlights[self.hoveredZone]:SetVisible(false)
    end
    if zone and self.zoneHighlights[zone] then
        self.zoneHighlights[zone]:SetVisible(true)
    end

    self.hoveredZone = zone

    if zone then
        self:_showTooltipFor(zone, mx, my)
    else
        self:_hideTooltip()
    end
end

-- ---------------------------------------------------------------------
-- v2.1: lista de misiones de una zona (datos de LOTRO_Quest_Assistant,
-- ver worldmap_quests.lua). Ventana con chrome nativo (Lotro.Window, punto
-- 1 del comentario grande) y SOLO Labels clickeables adentro, nunca
-- Lotro.Button -- mismo criterio que el resto de este addon.
-- ---------------------------------------------------------------------
local QP_W = 420
local QP_H = 500
local QP_PAD = 20
local QP_TOP = 40
local QP_ROW_H = 20
local QP_MAX_ROWS = 400

function WorldMapAddon.UI.WorldMap:_onZoneClick(mapX, mapY)
    if Quests == nil or not Quests.Available() then
        return
    end
    local zone = FindZoneAt(mapX, mapY)
    if zone == nil or (self.hiddenZones and self.hiddenZones[zone]) then
        return
    end
    local ok, err = pcall(function() self:_showQuestPanel(zone) end)
    if not ok then
        Turbine.Shell.WriteLine("<rgb=#FF0000>Mapa del Mundo: no se pudo abrir la lista de misiones -- " .. tostring(err) .. "</rgb>")
    end
end

function WorldMapAddon.UI.WorldMap:_buildQuestPanel()
    local panel = Turbine.UI.Lotro.Window()
    panel:SetSize(QP_W, QP_H)
    panel:SetText("Misiones activas")
    panel:SetVisible(false)
    self.questPanel = panel

    local innerW = QP_W - QP_PAD * 2

    self.qpTitle = Turbine.UI.Label()
    self.qpTitle:SetParent(panel)
    self.qpTitle:SetPosition(QP_PAD, QP_TOP)
    self.qpTitle:SetSize(innerW, 22)
    self.qpTitle:SetFont(Turbine.UI.Lotro.Font.TrajanPro16)
    self.qpTitle:SetForeColor(HexToColor("#F0D9A0"))
    self.qpTitle:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.qpTitle:SetMouseVisible(false)

    self.qpSummary = Turbine.UI.Label()
    self.qpSummary:SetParent(panel)
    self.qpSummary:SetPosition(QP_PAD, QP_TOP + 24)
    self.qpSummary:SetSize(innerW, 18)
    self.qpSummary:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.qpSummary:SetForeColor(HexToColor("#CFCFCF"))
    self.qpSummary:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.qpSummary:SetMouseVisible(false)

    local listTop = QP_TOP + 48
    local listH = QP_H - listTop - 44

    self.qpList = Turbine.UI.ListBox()
    self.qpList:SetParent(panel)
    self.qpList:SetPosition(QP_PAD, listTop)
    self.qpList:SetSize(innerW - 14, listH)

    self.qpScroll = Turbine.UI.Lotro.ScrollBar()
    self.qpScroll:SetOrientation(Turbine.UI.Orientation.Vertical)
    self.qpScroll:SetParent(panel)
    self.qpScroll:SetPosition(QP_PAD + innerW - 10, listTop)
    self.qpScroll:SetSize(10, listH)
    self.qpList:SetVerticalScrollBar(self.qpScroll)

    self.qpHint = Turbine.UI.Label()
    self.qpHint:SetParent(panel)
    self.qpHint:SetPosition(QP_PAD, QP_H - 38)
    self.qpHint:SetSize(innerW, 18)
    self.qpHint:SetFont(Turbine.UI.Lotro.Font.Verdana12)
    self.qpHint:SetForeColor(HexToColor("#9A9A9A"))
    self.qpHint:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter)
    self.qpHint:SetMouseVisible(false)
end

function WorldMapAddon.UI.WorldMap:_showQuestPanel(zone)
    if self.questPanel == nil then
        self:_buildQuestPanel()
    end
    self.qpZone = zone
    self:_fillQuestPanel()

    -- al lado del mapa si entra en pantalla; si no, encima (apretado contra
    -- los bordes con el mismo helper que los marcadores)
    local left, top = self:GetPosition()
    local w = self:GetWidth()
    local x = left + w + 4
    if x + QP_W > Turbine.UI.Display.GetWidth() then
        x = left + w - QP_W - 30
    end
    x, top = self:_clampToScreen(x, top + 60, QP_W, QP_H)
    self.questPanel:SetPosition(x, top)
    self.questPanel:SetVisible(true)
    self.questPanel:Activate()
end

function WorldMapAddon.UI.WorldMap:_fillQuestPanel()
    local zone = self.qpZone
    if zone == nil or self.questPanel == nil then
        return
    end
    self.qpTitle:SetText(zone.nombre)
    self.questPanel:SetText("Misiones activas: " .. zone.nombre)

    self.qpSummary:SetText(Quests.SummaryText(zone))

    local canOpen = _G.MainWindow ~= nil and _G.MainWindow.FocusQuest ~= nil
    self.qpHint:SetText(canOpen and "Clic en una misi\195\179n para abrirla en Quest Assistant" or "")

    self.qpList:ClearItems()
    local rows = Quests.Rows(zone)
    local rowW = self.qpList:GetWidth()
    local shown = math.min(#rows, QP_MAX_ROWS)

    if #rows == 0 then
        local empty = Turbine.UI.Label()
        empty:SetSize(rowW, 40)
        empty:SetFont(Turbine.UI.Lotro.Font.Verdana12)
        empty:SetForeColor(HexToColor("#9A9A9A"))
        empty:SetMultiline(true)
        empty:SetText("No tienes misiones activas en esta zona.")
        self.qpList:AddItem(empty)
        return
    end

    for i = 1, shown do
        local row = rows[i]
        -- v2.5: fila = iconos de grupo a la IZQUIERDA del titulo (pedido
        -- del usuario): logo de grupo de Quest Assistant (el mismo que usa
        -- en sus ventanas) si la mision es de grupo, y la calavera de
        -- mazmorra o de incursion si corresponde (las mismas del mapa, en
        -- 16 px). Mision normal = sin iconos, igual que antes.
        local icons = {}
        local GQ = _G.GroupQuest
        local isGroup = false
        if GQ ~= nil and type(GQ.Get) == "function" then
            local okG, g = pcall(GQ.Get, row.quest)
            isGroup = okG and type(g) == "table"
        end
        if isGroup and type(GQ.ICON_16) == "string" then
            icons[#icons + 1] = GQ.ICON_16
        end
        local kind = Quests.GroupKind and Quests.GroupKind(row.quest) or nil
        if kind ~= nil and MINI_IMAGES[kind] ~= nil then
            icons[#icons + 1] = RES_BASE .. MINI_IMAGES[kind]
        end

        local item = Turbine.UI.Control()
        item:SetSize(rowW, QP_ROW_H)
        item:SetMouseVisible(false)
        local iconsW = 0
        for _, image in ipairs(icons) do
            local ic = Turbine.UI.Control()
            ic:SetParent(item)
            ic:SetSize(MINI, MINI)
            ic:SetPosition(iconsW, math.floor((QP_ROW_H - MINI) / 2))
            ic:SetBackground(image)
            ic:SetBlendMode(Turbine.UI.BlendMode.AlphaBlend)
            ic:SetMouseVisible(false)
            iconsW = iconsW + MINI + 2
        end
        if iconsW > 0 then
            iconsW = iconsW + 2
        end

        local lbl = Turbine.UI.Label()
        lbl:SetParent(item)
        lbl:SetPosition(iconsW, 0)
        lbl:SetSize(rowW - iconsW, QP_ROW_H)
        lbl:SetFont(Turbine.UI.Lotro.Font.Verdana12)
        lbl:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft)
        lbl:SetSelectable(false)
        local text = "[" .. Quests.LevelText(row.quest) .. "]  " .. Quests.QuestName(row.ndx, row.quest)
        lbl:SetForeColor(HexToColor("#F0D060"))
        lbl:SetText(text)
        if canOpen then
            local ndx = row.ndx
            lbl:SetMouseVisible(true)
            lbl.MouseClick = function()
                Quests.OpenQuest(ndx)
            end
        else
            lbl:SetMouseVisible(false)
        end
        item.lbl = lbl
        item.iconCount = #icons
        self.qpList:AddItem(item)
    end

    if #rows > shown then
        local more = Turbine.UI.Label()
        more:SetSize(rowW, QP_ROW_H)
        more:SetFont(Turbine.UI.Lotro.Font.Verdana12)
        more:SetForeColor(HexToColor("#9A9A9A"))
        more:SetText("... y " .. (#rows - shown) .. " m\195\161s (b\195\186scalas en Quest Assistant)")
        self.qpList:AddItem(more)
    end
end

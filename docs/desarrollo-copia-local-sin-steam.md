# Desarrollar sobre una copia local del juego (sin Steam)

Receta general para probar mods sobre una **copia local** del juego en lugar de la
instalación de Steam. Ya se ha aplicado dos veces con éxito — a *Fear & Hunger*
(RPG Maker MV / NW.js / Greenworks) y a *Graveyard Keeper* (Unity / Steamworks.NET) —
así que vale para cualquier juego que use la Steamworks API, sea cual sea el motor.

## Por qué una copia local

El bucle de prueba de un mod de accesibilidad es: editar, instalar en el juego,
lanzar con lector de pantalla y escuchar. Hacerlo sobre la instalación de Steam es
incómodo:

- Steam puede revalidar los archivos y machacar el mod, o forzar el lanzamiento
  desde su cliente.
- Se quiere abrir y cerrar el juego muchas veces sin el cliente de por medio.
- La carpeta de Steam es la instalación «de verdad»; mejor no tocarla al desarrollar.

## El problema

Un build de Steam ejecutado directamente (doble clic en el `.exe`, sin pasar por el
cliente) dispara la comprobación de propiedad de la Steamworks API
(`SteamAPI.RestartAppIfNecessary` o equivalente): el proceso intenta **relanzarse a
través del cliente de Steam** y se cierra — el clásico «rebote» hacia Steam, que
además abre la copia original en vez de la local.

Da igual cómo llegue la llamada al API (plugin JS con Greenworks en NW.js, código C#
con Steamworks.NET en Unity...): el síntoma y la solución son los mismos.

## La solución: `steam_appid.txt`

Crear un archivo de texto llamado `steam_appid.txt` **junto al ejecutable del
juego** (en la raíz de la copia local), cuyo único contenido sea el **App ID** del
juego en Steam. Ejemplos ya usados:

| Juego            | App ID    |
|------------------|-----------|
| Fear & Hunger    | `1002300` |
| Graveyard Keeper | `599140`  |

El App ID se saca de la URL de la tienda de Steam
(`store.steampowered.com/app/<APPID>/...`) o de SteamDB.

Con el archivo presente, la API encuentra el App ID en el directorio de trabajo, la
comprobación de reinicio devuelve «ya está» y el arranque continúa en el sitio. La
inicialización de Steamworks falla de forma silenciosa (sin logros ni guardado en la
nube, irrelevante para probar) y el juego corre **por completo sin Steam**.

Es el método estándar y **no destructivo**: no se parchea el binario, no se borran
DLLs ni se tocan los plugins/archivos del juego. La copia queda idéntica a la de
Steam salvo por este `.txt` y el mod.

## Pasos para una copia nueva

1. Copiar la carpeta del juego desde `steamapps\common\` a una carpeta local junto
   al repositorio (añadirla al `.gitignore` si no lo está).
2. Crear en la raíz de esa copia (junto al `.exe`) un `steam_appid.txt` con el App
   ID como único contenido, sin nada más.
3. Instalar el mod en la copia (en este repo, `dev-install.bat`).
4. Lanzar el `.exe` directamente, sin abrir Steam, con el lector de pantalla activo.

## A tener en cuenta

- `steam_appid.txt` **no se versiona ni se distribuye**: es solo para la copia de
  desarrollo. El instalador de usuario final apunta a la instalación real de Steam,
  donde el juego se lanza desde el cliente y el archivo no hace falta.
- Al ser la copia local ignorada por git, este ajuste **se reproduce a mano** cada
  vez que se prepara una copia nueva — de ahí este documento.
- Si el juego sigue rebotando a Steam con el archivo presente, comprobar que está
  exactamente junto al ejecutable que se lanza y que el App ID es correcto; algunos
  juegos con DRM adicional (Denuvo, etc.) pueden requerir más, pero ninguno de los
  dos casos vistos lo necesitó.

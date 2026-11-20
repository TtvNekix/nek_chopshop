# Nekix ChopShop

Trabajo de desguace para FiveM: roba un vehículo, llévalo al desguace, despiézalo y vende las piezas. Funciona con ESX, QBCore y Qbox. Todas las decisiones (trabajo, vehículo, piezas, botín, pago, XP) las toma el servidor.

**Documentación en otros idiomas:** [English](../../README.md) | Español | [Português (Brasil)](README.pt-br.md) | [Français](README.fr.md) | [Deutsch](README.de.md)

## Características

- **Frameworks:** ESX, QBCore y Qbox, detectados automáticamente (`Config.Framework = 'auto'`).
- **Inventarios:** ox_inventory, qs-inventory, core_inventory, ps-inventory y qb-inventory, detectados automáticamente, más un adaptador `custom` para cualquier otro inventario.
- **Trabajos con autoridad del servidor:** el servidor elige el vehículo, lo genera, valida distancias, tiempos y ganzúa, y decide todas las recompensas. Un cliente modificado no puede darse objetos, dinero ni XP.
- **Categorías de vehículo y botín:** vehículos de categoría baja, media y alta, cada una con su pago, calidad de objeto y tabla de botín.
- **Reputación:** XP y niveles por personaje (oxmysql) que desbloquean categorías de vehículo y ventajas.
- **Más piezas:** puertas, capó, maletero, motor, asientos delanteros y ruedas, con un orden de "quita esto primero" validado por el servidor.
- **Policía:** mínimo de agentes en servicio y aviso de despacho con 9 scripts compatibles más `custom`.
- **Llaves de vehículo:** el dueño del trabajo recibe las llaves del vehículo tras la ganzúa, con 7 scripts compatibles más `custom`.
- **Sistema de compañero:** el dueño puede invitar a un compañero antes de desguazar; el compañero comparte el trabajo y una parte de la XP.
- **Límites de tiempo:** temporizadores de recogida y desguace; un trabajo caducado se cancela y su plaza del desguace se libera.
- **Cooldown persistente:** guardado en el KVP del recurso (sin SQL), por personaje y por licencia, con un comando de reinicio para administradores.
- **NUI de orden de trabajo:** tablón de trabajos, hoja de trabajo con notas, notas sueltas, invitación de compañero y comprador de piezas. Se puede desactivar.
- **10 idiomas** mediante los locales de ox_lib: en, es, fr, de, it, pt-br, pl, nl, tr, cs.
- **Logs de Discord** y comprobador de versión.

## Requisitos

| Recurso | Notas |
| :--- | :--- |
| [ox_lib](https://github.com/overextended/ox_lib) | obligatorio |
| [ox_target](https://github.com/overextended/ox_target) | obligatorio |
| [oxmysql](https://github.com/overextended/oxmysql) | obligatorio (dependencia del manifest). Con `Config.Reputation.Enabled = false` no se ejecuta ningún SQL |
| OneSync | obligatorio (el servidor genera los vehículos) |
| `qbx_core`, `es_extended` o `qb-core` | uno de ellos |
| Un inventario | `ox_inventory`, `qs-inventory`, `core_inventory`, `ps-inventory`, `qb-inventory` o un adaptador custom |

Opcional: un script de llaves de vehículo y un script de despacho policial (ver "Llaves de vehículo" y "Policía y despacho").

## Instalación

1. **Descarga** el recurso y coloca la carpeta en tu directorio de recursos. Mantén el nombre de carpeta `nek_chopshop`: los exports lo usan (`exports.nek_chopshop`).
2. **Añade los objetos** a tu inventario. Abre la guía de tu inventario, copia el bloque y reinicia el inventario:

   | Inventario | Guía |
   | :--- | :--- |
   | ox_inventory | [docs/items/ox_inventory.md](../items/ox_inventory.md) |
   | qb-inventory | [docs/items/qb-inventory.md](../items/qb-inventory.md) |
   | ps-inventory | [docs/items/ps-inventory.md](../items/ps-inventory.md) |
   | qs-inventory | [docs/items/qs-inventory.md](../items/qs-inventory.md) |
   | core_inventory | [docs/items/core_inventory.md](../items/core_inventory.md) |
   | cualquier otro | [docs/items/custom.md](../items/custom.md) |

3. **Copia las imágenes de los objetos** de la carpeta `[assets]` al directorio de imágenes de tu inventario (`ox_inventory/web/images/`, `qb-inventory/html/images/`, ...; cada guía indica la carpeta). Cada imagen se llama como su objeto.
4. **Añade el recurso a `server.cfg`**, después de sus dependencias:

   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure oxmysql
   ensure qbx_core            # o es_extended / qb-core
   ensure ox_inventory        # o tu inventario
   ensure qbx_vehiclekeys     # opcional: tu script de llaves
   ensure ps-dispatch         # opcional: tu script de despacho
   ensure nek_chopshop
   ```

5. **Base de datos:** no hay nada que importar. La tabla `nek_chopshop_reputation` se crea en el primer arranque.
6. **Configuración:** deja `Config.Framework = 'auto'` y `Config.Inventory = 'auto'` salvo que necesites forzar uno. Revisa [`shared/config.lua`](../../shared/config.lua).
7. **Idioma (opcional):** añade `setr ox:locale "es"` a `server.cfg` (ver "Idiomas").
8. **Arranca el servidor** y mira la consola: imprime el framework y el inventario que ha encontrado, y avisa de cualquier objeto que no esté registrado.

## Cómo funciona un trabajo

1. El jugador pide un trabajo al ped (opción de target o tablón de trabajos). El servidor comprueba cooldown, policías en servicio, categoría según reputación y una plaza libre en el desguace; después genera el vehículo y lo marca en el mapa.
2. El jugador fuerza el vehículo con ganzúa (necesita uno de `Config.LockpickItems` y superar el minijuego). El servidor da las llaves y envía el aviso a la policía.
3. El jugador lo conduce hasta el desguace.
4. En el desguace el jugador puede invitar a un compañero y después empieza a despiezar.
5. Cada pieza retirada va al inventario. Cuando no quedan piezas, el dueño recibe `Config.FinishReward` y, si está activado, dinero. El vehículo se destruye.
6. El jugador vende las piezas al ped de venta.

## Resumen de configuración

Todas las opciones están en [`shared/config.lua`](../../shared/config.lua), cada una con su comentario. Agrupadas por áreas:

### General

| Opción | Descripción |
| :--- | :--- |
| `Config.Framework` | `'auto'` (por defecto), `'esx'`, `'qbcore'` o `'qbox'`. Orden en auto: `qbx_core` > `es_extended` > `qb-core`. Un framework forzado que no está iniciado pasa a la autodetección. |
| `Config.Inventory` | `'auto'` (por defecto), `'ox_inventory'`, `'qs-inventory'`, `'core_inventory'`, `'ps-inventory'`, `'qb-inventory'` o `'custom'`. Ver "Inventario". |
| `Config.LockpickItems` | Objetos que permiten forzar el vehículo del trabajo (basta uno). Por defecto `lockpick`, `advancedlockpick`, `advanced_lockpick`. |
| `Config.UseNUI` | `true` usa la NUI; `false` recurre a los menús y notificaciones de ox_lib. |
| `Config.Debug` | Mensajes de depuración. |
| `Config.AdminAce` | ACE autorizado a usar el comando de administración. Ver "Administración". |

### Trabajos, recompensas y tiempo

| Opción | Descripción |
| :--- | :--- |
| `Config.Cooldown` | Segundos entre trabajos (por defecto 3600). Las ventajas de reputación pueden acortarlo. |
| `Config.TimeLimit` | `Pickup` y `Scrap`, en minutos (por defecto 20 y 10). Pickup va desde aceptar el trabajo hasta que empieza el desguace; Scrap, desde que empieza hasta que se retiran todas las piezas. Un trabajo que supera cualquiera de los dos se cancela. |
| `Config.Payment` | `Enable`, `Min`, `Max`: dinero opcional por trabajo (desactivado por defecto). Se multiplica por el `payout` de la categoría. |
| `Config.FinishReward` | Objeto entregado al dueño cuando se retiran todas las piezas (por defecto `veh_suspension`), o `false`. |
| `Config.ChopParts` | Piezas que se pueden retirar. Es la lista blanca de recompensas: el servidor solo recompensa las piezas que figuran aquí. Ver "Piezas". |
| `Config.Coords` | `Spawns` (puntos de aparición de vehículos) y `Scrap` (plazas del desguace). |
| `Config.Tiers` | Categorías de vehículo. Ver "Categorías de vehículo y botín". |
| `Config.Reputation` | XP, niveles, ventajas, desgaste. Ver "Reputación". |

### Peds y venta

| Opción | Descripción |
| :--- | :--- |
| `Config.Ped` | Ped del trabajo: `Model`, `Coords`, `Scenario`, `Target` (opciones de ox_target), `Blip`. |
| `Config.SellPed` | Ped de venta: `Enable`, `Model`, `Coords`, `Scenario`, `Items` (objeto, precio base, etiqueta), `QualityMultiplier`, `Blip`. |

Las etiquetas (`label`, `Label` del blip, `label` del target) aceptan una clave de locale; un texto literal también funciona.

### Policía y llaves de vehículo

| Opción | Descripción |
| :--- | :--- |
| `Config.Police` | `MinOnDuty`, `JobType`, `Jobs`, `Dispatch`. Ver "Policía y despacho". |
| `Config.VehicleKeys` | `System`, `RemoveOnEnd`. Ver "Llaves de vehículo". |

### Seguridad (antiexploits)

`Config.Security` contiene los umbrales del servidor (distancias en metros, tiempos en milisegundos):

| Opción | Por defecto | Descripción |
| :--- | :--- | :--- |
| `PedDistance` | 10.0 | Distancia máxima al ped del trabajo para pedir un trabajo. |
| `SellDistance` | 10.0 | Distancia máxima al ped de venta para vender. |
| `ScrapDistance` | 15.0 | Distancia máxima entre el vehículo y el punto de desguace para empezar a desguazar. |
| `PartDistance` | 6.0 | Distancia máxima entre el jugador y el vehículo para retirar una pieza. |
| `PartnerDistance` | 20.0 | Distancia máxima entre dueño y compañero al asignarlo. |
| `PartInterval` | 2000 | Tiempo mínimo entre dos retiradas de pieza del mismo jugador. |
| `SpawnClearRadius` | 3.0 | Un punto de aparición se descarta si hay un vehículo dentro de este radio. |
| `MaxAverageSpeed` | 60.0 | m/s. Una entrega del punto de aparición al desguace más rápida que esto se trata como teletransporte y se rechaza. |
| `WarnThrottle` | 30 | Segundos entre logs de peticiones sospechosas del mismo jugador. |
| `DispatchDistance` | 10.0 | Distancia máxima al vehículo del trabajo cuando llega el informe de la ganzúa. |

### Logs

| Opción | Descripción |
| :--- | :--- |
| `Config.Discord` | `Username`, `AvatarUrl`, `Color` de los embeds. La URL del webhook **no** está aquí: define `Editable.Webhook` en `editable/server.lua`. |
| `Config.Logs` | `EnableItem`, `EnablePay`, `EnableFinish`, `EnableWarn`, `EnableReputation`, `Compact`. |

Los logs de Discord usan el idioma del servidor.

## Inventario

`Config.Inventory = 'auto'` usa el primer inventario iniciado de esta lista:

| # | Recurso | Frameworks | Notas |
| :--- | :--- | :--- | :--- |
| 1 | `ox_inventory` | ESX, QBCore, Qbox | Compatibilidad completa. |
| 2 | `qs-inventory` | ESX, QBCore, Qbox | Escrito a partir de la documentación del proveedor. |
| 3 | `core_inventory` | ESX, QBCore, Qbox | Escrito a partir de la documentación del proveedor; la venta por calidad está degradada. |
| 4 | `ps-inventory` | QBCore | La comprobación de espacio es una estimación; la venta por calidad está degradada. |
| 5 | `qb-inventory` | QBCore | La venta por calidad está degradada. |

- **Arranque tardío:** si no hay ningún inventario en marcha cuando arranca el recurso, espera y elige uno en cuanto se inicie un recurso de la lista. Aun así, inicia tu inventario antes que nek_chopshop.
- **Forzar uno:** indica el nombre del recurso. Si no está iniciado, se imprime un aviso en la consola y se usa la autodetección.
- **Cualquier otro inventario:** `Config.Inventory = 'custom'` y rellena `Editable.Inventory` en `editable/server.lua`. Ver [docs/items/custom.md](../items/custom.md).
- **Metadatos de calidad:** ox_inventory guarda la calidad de la categoría en `metadata.quality`; los demás inventarios usan `chopQuality`.
- Las limitaciones conocidas de cada inventario figuran al final de su guía de objetos.

## Policía y despacho

### Mínimo de policías en servicio

`Config.Police.MinOnDuty` es el número de agentes que deben estar en servicio para repartir un trabajo (`0` lo desactiva). La petición se rechaza en el servidor y el tablón muestra "Not enough police on duty" (texto según el idioma).

- **Qbox / QBCore:** cuenta jugadores en servicio cuyo tipo de trabajo es `Config.Police.JobType` (por defecto `'leo'`). Con `JobType = false` se cuentan en su lugar los nombres de trabajo de `Config.Police.Jobs`.
- **ESX:** cuenta jugadores con un trabajo de `Config.Police.Jobs` cuyo `job.onDuty` no es `false` (un ESX antiguo sin servicio cuenta a todos los del trabajo).
- Una categoría puede añadir `minPolice`; el requisito efectivo es el mayor de los dos.

### Aviso

Un aviso por trabajo, enviado por el servidor (desde su barrido de trabajos, o al entregar el vehículo) para que un cliente modificado no pueda saltárselo. El cliente del ladrón puede dispararlo antes, justo tras la ganzúa; el servidor comprueba que quien llama es el dueño del trabajo, está en la fase de recogida, está junto al vehículo (`Config.Security.DispatchDistance`) y no ha avisado ya. Ubicación, matrícula y modelo siempre vienen del servidor.

`Config.Police.Dispatch.System`:

| Valor | Comportamiento |
| :--- | :--- |
| `'auto'` | Primer script iniciado de la lista siguiente. |
| un nombre de script | Fuerza ese script. |
| `'custom'` | Llama a tu propio código (ver abajo). |
| `false` | Sin aviso. |

Scripts compatibles, en orden de autodetección:

| # | Recurso | Se ejecuta en |
| :--- | :--- | :--- |
| 1 | `ps-dispatch` | cliente |
| 2 | `cd_dispatch` | cliente |
| 3 | `qs-dispatch` | cliente |
| 4 | `rcore_dispatch` | cliente |
| 5 | `core_dispatch` | servidor |
| 6 | `tk_dispatch` | cliente |
| 7 | `origen_police` | cliente |
| 8 | `lb-tablet` | servidor |
| 9 | `linden_outlawalert` | cliente |

Otras opciones de `Config.Police.Dispatch`: `Code` (código de radio, por defecto `10-35`), `CodeName` (solo ps-dispatch), `Title` y `Message` (claves de locale `dispatch_title` / `dispatch_message`; el mensaje recibe el modelo y la matrícula) y `Blip` (`Sprite`, `Color`, `Scale`, `Time` en segundos).

**Custom:** define `System = 'custom'` y rellena `Editable.Client.DispatchAlert(data)` (`editable/client.lua`) y/o `Editable.Server.DispatchAlert(data, source)` (`editable/server.lua`). `data` es `{ coords, plate, model, code, title, message, jobs, jobType }`; la versión de cliente recibe además `modelLabel` y `vehicle` (entidad).

## Llaves de vehículo

Los scripts de llaves (por ejemplo `qbx_vehiclekeys`) no dejan arrancar un vehículo del que no se tienen llaves. Tras una ganzúa correcta, el servidor da al dueño las llaves del vehículo del trabajo, una vez por trabajo y solo si lleva una ganzúa. Los compañeros nunca reciben llaves.

`Config.VehicleKeys`:

| Opción | Comportamiento |
| :--- | :--- |
| `System = 'auto'` | Primer script iniciado de la lista siguiente. |
| `System = '<resource>'` | Fuerza ese script (sin llaves si no está iniciado). |
| `System = 'custom'` | Llama a `Editable.Server.GiveVehicleKeys(src, vehicle, plate, model)` y `Editable.Server.RemoveVehicleKeys(...)` en `editable/server.lua`. |
| `System = false` | No se dan llaves (ESX sin script de llaves, por ejemplo). |
| `RemoveOnEnd = true` | Retira las llaves cuando termina el trabajo, antes de borrar el vehículo. |

Scripts compatibles, en orden de autodetección: `qbx_vehiclekeys`, `qs-vehiclekeys`, `wasabi_carlock`, `MrNewbVehicleKeys`, `ak47_vehiclekeys`, `vehicles_keys`, `qb-vehiclekeys`.

No integrados (usa `'custom'`): Renewed-Vehiclekeys, llaves de cd_garage, t1ger_keys, okokGarage / okokVehicleKeys.

## Categorías de vehículo y botín

El servidor elige el vehículo. `Config.Tiers` agrupa los modelos en categorías (`low`, `mid`, `high` por defecto):

| Campo | Descripción |
| :--- | :--- |
| `label` | Clave de locale (o texto) mostrada al empezar el trabajo. |
| `weight` | Probabilidad relativa de la categoría entre las que el jugador cumple. |
| `minLevel` | Nivel de reputación necesario. Se ignora si la reputación está desactivada. |
| `minPolice` | Opcional. Agentes en servicio necesarios para esta categoría. |
| `payout` | Multiplicador del pago final (`Config.Payment`). |
| `quality` | Calidad que reciben los objetos de pieza de esta categoría: `standard`, `premium` o `exotic`. Los objetos de distinta calidad no se apilan. |
| `models` | Nombres de modelo de vehículo; se elige uno al azar. |
| `loot` | Tiradas extra por cada pieza retirada: `{ item, chance (0-100), min, max, parts = { bones }, quality = true }`. |

- La categoría, el modelo y el botín se sortean en el servidor.
- Antes de retirar una pieza, el servidor comprueba que caben a la vez la pieza, sus objetos extra y todo el botín. Si no caben, no se da nada y la pieza se queda en el coche.
- **Venta:** el ped de venta paga `price x QualityMultiplier[quality] x sellMultiplier de la reputación` por cada pila. Valores por defecto de `Config.SellPed.QualityMultiplier`: standard 1.0, premium 1.5, exotic 2.5.
- Los objetos que solo salen como botín (`scrap_metal`, `sport_wheel`, `turbo_kit`) deben estar registrados en tu inventario y figurar en `Config.SellPed.Items` para poder venderse.
- Una configuración que aún tenga la antigua lista plana `Config.Vehicles` y no tenga `Config.Tiers` sigue funcionando como una única categoría `low`.

## Reputación

Se guarda por personaje en la tabla oxmysql `nek_chopshop_reputation` (`identifier`, `xp`, `jobs`, `last_job`), creada automáticamente. `identifier` es el id de personaje del framework (`identifier` en ESX, `citizenid` en QBCore/Qbox).

- **Ganar XP (solo servidor):** un trabajo terminado da al dueño `Base + PerPart x piezas retiradas + TimeBonusMax x (fracción de tiempo de desguace que quedaba)`. El compañero recibe `PartnerShare` (0-1) de eso. Un trabajo fuera de tiempo o con el vehículo perdido cuesta al dueño `PenaltyExpired`; salir del servidor con un trabajo activo cuesta `PenaltyAbandoned`. La XP nunca baja de 0.
- **Niveles** (`Config.Reputation.Levels`): la primera entrada es el nivel 0 (`xp = 0`). Cada nivel indica sus propias ventajas:

| Ventaja | Efecto |
| :--- | :--- |
| `sellMultiplier` | Multiplica el precio del ped de venta (además del multiplicador de calidad). |
| `cooldownMultiplier` | Multiplica `Config.Cooldown` al coger un trabajo (0-1). |
| `extraPartChance` | Probabilidad (0-100) de una copia extra de cada pieza retirada. |
| categorías de vehículo | Se desbloquean con `Config.Tiers[].minLevel` (por defecto: media en el nivel 2, alta en el nivel 4). |

- **Desgaste** (`Config.Reputation.Decay`, desactivado por defecto): cada semana completa sin un trabajo terminado resta `PerWeek` de XP. Se calcula al leer la reputación; no hay temporizador.
- **Desactivada** (`Enabled = false`): sin XP, sin ventajas, todas las categorías disponibles, sin SQL.
- El tablón muestra el nivel y el progreso; una subida de nivel envía una notificación y, con `Config.Logs.EnableReputation`, un log de Discord.

## Piezas

Entradas de `Config.ChopParts`: `bone`, `part` (índice de puerta o rueda), `item`, `label` (clave de locale), `isDoor` / `isWheel`, `bonus` (objetos extra), `anim` (`'repair'` para la animación bajo el capó), `optional` y `requires`.

- Piezas por defecto: 4 puertas, capó (da `car-battery`), maletero, motor (requiere quitar el capó), 2 asientos delanteros (requieren quitar su puerta) y 4 ruedas.
- Solo las 4 ruedas son obligatorias. Todas las demás piezas son opcionales: forman parte del trabajo solo si el modelo del vehículo tiene ese hueso, de modo que un modelo sin un hueso nunca deja el trabajo imposible de terminar.
- `requires` se aplica en el servidor. Si la pieza requerida no forma parte del trabajo, el requisito se da por cumplido.

## Idiomas

Todo el texto visible para el jugador está en `locales/<lang>.json`, cargado con el módulo de locale de ox_lib.

Incluidos: inglés (`en`), español (`es`), francés (`fr`), alemán (`de`), italiano (`it`), portugués de Brasil (`pt-br`), polaco (`pl`), neerlandés (`nl`), turco (`tr`) y checo (`cs`).

- **Cambiar de idioma:** añade `setr ox:locale "es"` a `server.cfg` (por defecto `en`). Los jugadores también pueden elegir idioma en el menú de ajustes de ox_lib; la NUI se actualiza cuando lo hacen.
- **Respaldo:** una clave que falte recurre al inglés; un archivo que falte recurre al inglés.
- **Añadir un idioma:** copia `locales/en.json` a `locales/<code>.json` (mismo código que en `ox_lib/locales`, por ejemplo `ru`, `zh-cn`), traduce los valores y conserva las claves. Mantén `%s` / `%d` en el mismo orden y los `{placeholders}` de la sección `nui` sin cambios. No uses `${...}` dentro de los textos.
- No edites `ChopLocale` / `LoadChopLocale` en la configuración.

## Administración

| Comando | Descripción |
| :--- | :--- |
| `chopshop_resetcd all` | Borra el cooldown de trabajo de todos los personajes y licencias. |
| `chopshop_resetcd <player id>` | Borra el cooldown de un jugador conectado (personaje actual y licencia). |
| `chopshopui` | Comando de jugador: cierra todas las vistas de la NUI y libera el foco del ratón si un error de la página lo deja bloqueado. |

Los cooldowns viven en el almacenamiento KVP de este recurso (la carpeta `db/` del servidor), no en MySQL.

`Config.AdminAce` (por defecto `'admin'`):

- Los jugadores con este ACE pueden ejecutar `chopshop_resetcd` en el juego (el ACE `command.chopshop_resetcd` también sirve). La consola del servidor siempre puede ejecutarlo.
- Los jugadores con este ACE se saltan la comprobación antiteletransporte de la entrega, de modo que el personal puede probar con teletransportes.

```cfg
add_ace group.admin admin allow
```

## Exports

Usa el nombre de la carpeta del recurso en `exports[...]`.

### Cliente

```lua
-- Devuelve { active = boolean, pedCoords = vector4 }
-- active: el jugador local tiene un trabajo de desguace activo. pedCoords: Config.Ped.Coords.
local status = exports.nek_chopshop:GetJobStatus()
if status.active then
    print('Working on a chop job')
end
```

### Servidor

```lua
-- GetReputation(identifier: string) -> { xp = number, level = number, jobs = number } | nil
-- nil si la reputación está desactivada, el identificador no es válido o no se pudo leer la base de datos.
-- Puede esperar a la base de datos la primera vez que se lee un identificador: llámalo desde un hilo.
CreateThread(function()
    local rep = exports.nek_chopshop:GetReputation(citizenid)
    if rep then print(rep.xp, rep.level, rep.jobs) end
end)

-- AddReputation(identifier: string, amount: number, reason?: string) -> boolean
-- amount: distinto de cero; positivo suma y negativo resta (las fracciones se truncan, máximo 1000000).
-- reason: texto para el log (se corta a 100 caracteres, por defecto 'export').
-- Se guarda de forma asíncrona, se imprime en la consola y se registra en Discord (Config.Logs.EnableReputation).
-- Devuelve false si el identificador o la cantidad no son válidos, si la reputación está desactivada o si
-- no se pudo leer la fila (el cambio queda en cola y se aplica una vez en la siguiente lectura correcta).
-- Puede esperar a la base de datos la primera vez que se usa un identificador: llámalo desde un hilo.
CreateThread(function()
    exports.nek_chopshop:AddReputation(citizenid, 50, 'event reward')
    exports.nek_chopshop:AddReputation(citizenid, -25, 'admin correction')
end)
```

## Funciones editables

Estos archivos están pensados para editarse:

| Archivo | Función | Para qué sirve |
| :--- | :--- | :--- |
| `editable/server.lua` | `Editable.Webhook` | URL del webhook de Discord. |
| `editable/server.lua` | `Editable.Server.SendDiscordLog(title, description, color)` | Envío de logs personalizado. |
| `editable/server.lua` | `Editable.Server.CustomReward(source)` | Recompensa extra al terminar un trabajo (cripto, XP, objetos...). |
| `editable/server.lua` | `Editable.Server.DispatchAlert(data, source)` | Despacho personalizado (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Server.GiveVehicleKeys` / `RemoveVehicleKeys` | Llaves personalizadas (`System = 'custom'`). |
| `editable/server.lua` | `Editable.Inventory` | Adaptador de inventario personalizado (`Config.Inventory = 'custom'`). |
| `editable/client.lua` | `Editable.Client.MiniGame()` | Minijuego de la ganzúa; devuelve `true` si se supera. Por defecto `lib.skillCheck`. |
| `editable/client.lua` | `Editable.Client.DispatchAlert(data)` | Despacho personalizado en el cliente del ladrón. |
| `editable/client.lua` | `Editable.Client.Notify(data)` | Estilo de notificación (se usa cuando la NUI está desactivada o no está lista). |

Cada función incluye ejemplos comentados y la forma exacta de sus argumentos.

## Personalización de la NUI

La NUI está en `web/` (Web Components simples, sin paso de compilación). El lado Lua y la página comparten un único contrato: [web/CONTRACT.md](../../web/CONTRACT.md) (mensajes, callbacks, payloads de las vistas, claves de locale).

- **Colores, fuentes, espaciado y posición** son variables CSS en `web/styles/tokens.css`: colores de papel y tinta (`--paper-original`, `--ink`, `--stamp`...), fuentes (`--font-print`, `--font-hand`, `--font-num`) y la posición de la hoja de trabajo (`--tracker-top`, `--tracker-right`).
- **Los textos** salen de la sección `nui` de `locales/<lang>.json`.
- `Config.UseNUI = false` elimina la NUI y usa menús y notificaciones de ox_lib.

## Objetos e iconos

Cada pieza, objeto extra, recompensa final y objeto de botín de categoría se comprueba contra la lista de objetos del inventario al arrancar y cada vez que el inventario se reinicia (se omite si el inventario no tiene un export con la lista de objetos). Las entradas de botín desconocidas se descartan con un aviso en la consola; las piezas, objetos extra y recompensas desconocidos solo se informan.

| Objeto | Origen |
| :--- | :--- |
| `vehicle_door`, `vehicle_hood`, `vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `veh_wheels` | Piezas |
| `car-battery` | Extra del capó |
| `veh_suspension` | `Config.FinishReward` por defecto |
| `scrap_metal`, `sport_wheel`, `turbo_kit` | Botín de categoría |

Los iconos están en `[assets]`, con el nombre de su objeto. Proceden de la galería de imágenes de RAINMAD (https://items.rainmad.com/).

## Solución de problemas

| Problema | Causa y solución |
| :--- | :--- |
| `No such export getSharedObject in resource es_extended` (o similar) | `Config.Framework` está forzado a un framework que no está iniciado. Pon `'auto'`. Desde la 2.0.0 un framework forzado que no está iniciado pasa a la autodetección y se imprime un aviso. |
| `... item "x" is not registered in <inventory>` en la consola | Falta el objeto en tu inventario. Añádelo desde [docs/items](../items/). |
| `No supported inventory detected` | No hay iniciado ningún inventario de la lista. Inícialo antes que nek_chopshop, o usa `'custom'`. |
| El jugador no tiene llaves tras la ganzúa | Revisa `Config.VehicleKeys.System`: tu script de llaves puede no ser compatible (usa `'custom'`) o no estar iniciado. |
| No hay aviso a la policía | Revisa `Config.Police.Dispatch.System`: el script puede no estar iniciado o no ser compatible (usa `'custom'`). |
| "Not enough police on duty" | `Config.Police.MinOnDuty` (o el `minPolice` de la categoría) es mayor que los agentes en servicio. Ponlo a `0` para desactivarlo. |
| "You have to wait N minutes before working again." | Cooldown del trabajo. El personal puede ejecutar `chopshop_resetcd <id>` o `chopshop_resetcd all`. |
| "Nobody drives here that fast. Wait N s and try again." | La comprobación antiteletransporte rechazó una entrega más rápida que `Config.Security.MaxAverageSpeed`. Espera los segundos indicados. El personal con `Config.AdminAce` se salta la comprobación. |
| El ratón se queda en pantalla | Ejecuta `/chopshopui`. |
| `Could not check for updates.` | El servidor no puede conectar con GitHub. Es inofensivo. |
| Errores de la tabla de reputación | oxmysql no funciona. Revisa su cadena de conexión. |

Pon `Config.Debug = true` para obtener más salida en la consola.

Nota: los mensajes citados son los textos en inglés; en el juego aparecen en el idioma configurado.

## Actualizar desde la v1

Cambios incompatibles:

- **Objetos:** 6 objetos nuevos (`vehicle_trunk`, `vehicle_engine`, `vehicle_seat`, `scrap_metal`, `sport_wheel`, `turbo_kit`). Regístralos y copia sus imágenes (ver "Instalación").
- **Imagen renombrada:** `[assets]/vehicle_wheel.png` ahora es `[assets]/veh_wheels.png` (el nombre del objeto `veh_wheels` no cambió). Renómbrala en las imágenes de tu inventario si copiaste la antigua.
- **Locales:** `Config.Locales` ya no existe. Los textos pasaron a `locales/*.json` (ox_lib). Si editaste textos, cópialos a tu archivo de idioma.
- **Vehículos:** la lista plana `Config.Vehicles` pasó a ser `Config.Tiers` (la lista antigua sigue funcionando como una categoría `low`).
- **Secciones de configuración nuevas:** `Config.Inventory`, `Config.Police`, `Config.VehicleKeys`, `Config.TimeLimit`, `Config.Reputation`, `Config.Tiers`, `Config.AdminAce`, `Config.UseNUI`, `Config.SellPed.QualityMultiplier`. `Config.Framework` ahora vale `'auto'` por defecto. Combínalas desde el nuevo `shared/config.lua`.
- **Funciones editables:** `Editable.Client.DispatchAlert` ahora recibe una tabla `data` en lugar del vehículo (`data.vehicle` es la entidad). Funciones nuevas: `Editable.Server.DispatchAlert`, `Editable.Server.GiveVehicleKeys`, `Editable.Server.RemoveVehicleKeys`, `Editable.Inventory`.
- **Dependencias:** `oxmysql` ahora es obligatorio. `ox_inventory` ya no es obligatorio.
- **Exports:** el export de cliente es `exports.nek_chopshop:GetJobStatus()` (usa el nombre real de la carpeta del recurso); nuevos exports de servidor `GetReputation` y `AddReputation`.

Haz una copia de seguridad de tu `shared/config.lua` y de los archivos de `editable/` antes de reemplazar el recurso, y vuelve a aplicar tus cambios sobre los archivos nuevos. Lista completa de cambios: [CHANGELOG.md](../../CHANGELOG.md).

## Documentación en otros idiomas

- [English](../../README.md)
- [Português (Brasil)](README.pt-br.md)
- [Français](README.fr.md)
- [Deutsch](README.de.md)

## Licencia

Consulta [LICENSE](../../LICENSE).

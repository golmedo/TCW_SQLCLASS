# tcwDriverMariaDB - la SQLClass directo a MariaDB / MySQL

`SQLMariaClass` es la SQLClass (SQLClass6) de siempre, con los mismos métodos, las mismas firmas y los mismos
códigos de retorno, pero sin archivo de trabajo ni driver de Clarion: manda el SQL directo al servidor con
`libmariadb.dll` (MariaDB Connector/C, API pública, LGPL).

**SQLClass6.INC / .clw no se tocan.** `SQLMariaClass` hereda de `SQLOdbcClass` y reimplementa sus métodos en
archivos propios. Las apps que usan `SQLMsClass` siguen exactamente igual; la elección entre una y otra es la
opción que después va al template.

## Uso
```clarion
  INCLUDE('SQLClass6Maria.inc'),ONCE
CLASSQ   &SQLMariaClass                    ! el tipo tiene que ser SQLMariaClass (no SQLMsClass)
  CODE
  CLASSQ &= NEW SQLMariaClass
  IF CLASSQ.InitMaria('Server=srv;Port=3306;Database=base;User=u;Password=p') THEN ...error....
  ! o, sin cambiar el codigo existente: CLASSQ.Init(Sqlclass,Sqlclass:Record,'Server=...')  (el archivo se ignora)
  IF CLASSQ.Exec('SELECT codigo, nombre FROM articulos WHERE activo = 1') THEN RETURN.
  LOOP UNTIL CLASSQ.Next()
     Q:Codigo = CLASSQ.Col(1)
     Q:Nombre = CLASSQ.ColByName('nombre')
     ADD(Q)
  END
  CLASSQ.Exec('INSERT INTO clientes (nombre) VALUES (' & CLASSQ.Quote(Nombre) & ')')
  NuevoId = CLASSQ.InsertId()
```

| Igual que SQLClass6 | Init, Kill, Exec, ExecEx, ExecSP, SP, Parse, ServerExec, ServerExecEx, Next, Col, Col_Format, Columns, Field, Fetch (2), Records, LoadQueue, RegisterUpdate, UpdateBuffer, Take*, WriteLog; propiedades SilentMode, LogFile, ShowProgress, ProgressTitle/Text, Debug/Debug_Limit, MaxReads, FreeQueue, Records, Records_Done, PK_Col |
|---|---|
| Nuevos | `InitMaria(conexion)`, `ColByName(nombre)`, `IsNull(n)`, `Escape(texto)`, `Quote(texto)`, `InsertId()`, `AffectedRows()`, `ErrorText()`, `ErrorCode()`, `ServerVersion()`, `BeginTransaction/Commit/Rollback()`, propiedad `KeepCase` (Exec sin pasar a minúsculas) y `Db` (la conexión `TCWMariaDB`) |

Cadena de conexión: `Server` (o Host, Data Source), `Port` (3306), `Database`, `User` (Uid), `Password` (Pwd),
`Charset` (por defecto `latin1`: los textos de Clarion viajan sin conversión), `Timeout` (segundos, 10).

### Diferencias a favor
- Sin límite de columnas ni de largo por valor (la SQLClass con archivo se limitaba a los campos del registro, 20 × 50 en Nautilus).
- `Records()` cuenta el resultado ya leído: exacto también con GROUP BY / DISTINCT.
- `Field(n)` devuelve el nombre real de la columna que manda el servidor; `Columns()` es exacto.
- `ExecSP('EXEC sp p1, p2')` se manda como `CALL sp(p1, p2)` y descarta el resultado extra del CALL (no da "Commands out of sync").
- Si se cae la conexión (error 2006/2013), reconecta y reintenta una vez.
- `Parse` acepta las sentencias de MariaDB (SHOW, DESCRIBE, EXPLAIN, REPLACE, USE, WITH, LOCK…) y `SELECT` sin FROM.
- `LoadQueue` corrige el porcentaje de la ventana de avance (estaba invertido).

### A tener en cuenta
- `Exec` pasa la consulta a minúsculas, igual que SQLClass6. En MariaDB sobre Linux los nombres de tabla distinguen mayúsculas: usar `KeepCase = 1` o `ExecEx(q,1)`.
- Un objeto tiene un resultado abierto por vez (igual que antes): no anidar lecturas sobre el mismo objeto.

## Archivos
| Carpeta | Contenido |
|---|---|
| `clarion\` | `SQLClass6Maria.inc/.clw` (SQLMariaClass), `TCWMariaDB.inc/.clw` (conexión directa, se puede usar sola) |
| `sqlclass6\` | copia sin cambios de SQLClass6.INC/.clw (Clarion 11, versión con ExecSP/LogFile) |
| `lib\libmariadb.lib` | librería de importación (las exportaciones de la DLL) para linkear |
| `bin\libmariadb.dll` | MariaDB Connector/C 3.4.9, 32 bits: va junto al .exe |
| `tests\TestMaria.clw` | prueba de todos los métodos sobre una tabla temporal |

Requisitos del proyecto: `libmariadb.lib` en Libraries, SQLClass6 + StringClass + StringTheory (como siempre) y `libmariadb.dll` junto al .exe.

La cadena de conexión acepta también la de ODBC tal cual (`DRIVER={MySQL ODBC 5.1 Driver};SERVER=...;OPTION=3`):
las claves que no conoce (DRIVER, OPTION) se ignoran. `SSL=1` exige TLS y verifica el certificado; por defecto
(0) usa TLS solo si el servidor lo ofrece, porque Connector/C 3.4 lo exige de fábrica y servidores viejos
(MySQL 5.0) no lo tienen.

## Prueba
```powershell
.\build-test.ps1 -Conexion 'Server=127.0.0.1;Port=3306;Database=test;User=u;Password=p'
```
Compila con Clarion 11 (`C:\clarion11Col`) y prueba todo sobre una tabla **TEMPORARY** (no deja nada en la base).
Con un segundo parámetro `SP` al ejecutar `TestMaria.exe` también crea, usa y borra un procedimiento `tcw_prueba_sp`.
Resultado en `tests\.build\resultados.txt`; el SQL enviado queda en `tests\.build\sql.log`.
Verificado el 2026-10-27 contra MySQL 5.0.67 (base `gestion`): TODO OK.

## Comparación de tiempos (2026-10-28, MySQL 5.0.67 local, tabla `cbtes`)
30.000 filas (9 columnas), `ExecEx` + `Col_Format` + `LoadQueue`, 3 corridas alternando el orden:

| Motor | Consulta | Carga a la cola | Total |
|---|---|---|---|
| SQLMariaClass directo | 60 ms | 370 ms | **430 ms** |
| SQLClass6 + driver ODBC (MySQL ODBC 5.1) | 60 ms | 576 ms | **636 ms** |

ODBC tarda ~1,5 veces más. Las dos traen las mismas filas y la misma suma de importes, pero **ODBC pierde
4.045 caracteres de razón social**: la tabla de trabajo `sqlclass` tiene campos de 49 y corta los valores
más largos (`Descripcion` es `char(70)`). SQLMariaClass no tiene ese límite.

### Con filtros (promedio de 5 corridas + 1 de calentamiento, total en ms)
| Escenario | Filas | Consulta (igual en los dos) | MariaDB | ODBC | ODBC / Maria |
|---|---|---|---|---|---|
| Sin filtro (últimas 30.000) | 30.000 | 60 | 430 | 644 | 1,50 |
| Fecha: 1er semestre (índice) | 22.579 | 46 | 326 | 494 | 1,52 |
| Tipo FC del año | 10.166 | 1.180 | 1.310 | 1.384 | 1,06 |
| Razón social `LIKE '%SRL%'` | 17.716 | 1.530 | 1.770 | 1.866 | 1,05 |
| Razón social `LIKE '%GARCIA%'` | 3.848 | 1.490 | 1.532 | 1.576 | 1,03 |
| Un cliente (índice) | 2.325 | 10 | 40 | 54 | 1,35 |
| Mes actual | 460 | 0-2 | 8 | 12 | ~1,5 |
| Un comprobante por Id | 1 | 0-2 | 2 | 2 | - |

La consulta tarda lo mismo con los dos motores (es el servidor); la diferencia está toda en traer las filas
(MariaDB directo ~1,5 veces más rápido por fila). Con filtros por índice la proporción se mantiene, pero en
pocos milisegundos. Cuando el servidor tarda (`LIKE '%x%'` recorre las 500 mil filas) la diferencia queda en 5 %.
"Tipo FC" tarda 1,2 s porque MySQL elige el índice `PorTipoCbte` y ordena 46.200 filas: con
`FORCE INDEX (PorFecha)` baja a 168 ms. El índice pesa mucho más que el motor.

## App de ejemplo (`demo\`)
Menú *Comprobantes*: **MariaDB directo** (SQLMariaClass), **ODBC** (SQLClass6 + `FILE,DRIVER('ODBC')` sobre la
tabla `sqlclass` que ya existe en la base: no se crea nada) y **Comparar tiempos** (8 escenarios con y sin
filtro, máximo de filas y corridas elegibles, promedio por motor y control de que los dos traen lo mismo).
`build-demo.ps1 -Carpeta .build2` compila en otra carpeta (si la demo está abierta tiene tomadas las DLL).
`TCWMariaDemo.exe comparar` corre la comparación sola y deja el resultado en `comparacion.txt`.
El TXA se genera con `demo\make-demo-txa.py` (lo llama `build-demo.ps1`).

### Pantalla MariaDB directo
`demo\TCWMariaDemo.txa`: una ventana sobre la tabla `cbtes` con filtros (fecha desde/hasta, tipo, texto de la razón
social con `LIKE`, máximo de filas), botón Buscar que arma el SELECT con `Quote()`, lo ejecuta con `ExecEx(q,1)` y lo
carga al LIST con `Col_Format` + `LoadQueue`; abajo muestra cantidad, tiempo, total y versión del servidor.
```powershell
demo\build-demo.ps1 -Conexion 'Server=localhost;Port=3306;Database=gestion;User=root;Password=...' -Run
```
Genera la app con ClarionCL (TXA → .app → .clw), la compila y deja en `demo\.build\` el .exe, `libmariadb.dll` y
`TCWMariaDemo.ini` con la conexión (no queda en el código). Resultado real: 1.000 comprobantes en 30 ms.
Para abrir el `.app` en el IDE hay que agregar `libmariadb.lib` a las Libraries del proyecto y los defines de StringTheory.

### Parámetros, varios resultados, sentencias preparadas e INSERT por campo (2026-10-29)
Lo mismo que `SQLMsDirectClass` (tcwDriverMSSQL), con la misma interfaz:
```clarion
  SQL.AddParam(Cliente) ; SQL.AddParam(FORMAT(Desde,@d10-))           ! '?': cada valor va escapado y entre comillas
  SQL.ExecEx('SELECT ... FROM cbtes WHERE IdCliente = ? AND Fecha >= ?',1)
  SQL.ExecEx('SELECT ...; SELECT ...',1) ; ... ; SQL.NextResult()      ! o ExecSP('CALL sp(?)') con varios SELECT
  SQL.Campo('Nombre',Nombre) ; SQL.CampoFecha('Fecha',Fecha) ; SQL.CampoNulo('Nota')
  SQL.Insertar('clientes')                                             ! una fila
  SQL.InsertarLote('clientes') ... SQL.EnviarLote()                   ! muchas filas
  SQL.Prepare('UPDATE t SET a = ? WHERE id = ?') ; SQL.AddParam(..) ; SQL.ExecPrepared()
```
MySQL 5.0 no tiene arreglos de parámetros: los `?` se reemplazan del lado del cliente con `mysql_real_escape_string`
(un `?` entre comillas no se toca) e `InsertarLote` arma un `INSERT ... VALUES (...),(...)` de 500 filas (y lo manda
antes de pasar 512 KB: `max_allowed_packet` de MySQL 5.0 es 1 MB). La conexión habilita `CLIENT_MULTI_STATEMENTS`
para `SELECT ...; SELECT ...`; con `UPDATE ...; SELECT ...` la consulta queda directamente en el resultado del `SELECT`.

Escritura medida en la pantalla *Ejemplos de uso* (2.000 filas, MySQL 5.0.67 local):

| Forma | Filas/s |
|---|---|
| `INSERT` armado como texto (como `PROP:SQL`) | 401 |
| `Insertar` (una fila por viaje) | 426 |
| **`InsertarLote`** (`INSERT` de 500 filas) | **40.000** (100 veces) |

`tests\TestMaria.clw` prueba todo esto (parámetros con `'`, `\` y NULL, `?` entre comillas, dos resultados, `UPDATE; SELECT`,
`Prepare`, `Insertar`, lote de 1.235 filas, texto de 20.000, resultado pendiente): TODO OK el 2026-10-29.
La demo tiene la pantalla **Ejemplos de uso** (`demo\ejemplos.py`, tablas `TEMPORARY ... ENGINE=InnoDB`: no tocan la
base); `TCWMariaDemo.exe ejemplos` la corre sola y deja `ejemplos.txt`.

### Avance en la ventana (barra + texto)
`SQLMariaClass` puede mostrar el avance en dos controles de la propia ventana (sin la ventanita de `ShowProgress`):
```clarion
  SQL.ProgressFeq     = ?SQLBarra      ! PROGRESS,RANGE(0,100)
  SQL.ProgressTextFeq = ?SQLTexto      ! STRING
  SQL.ProgressDelay   = 10             ! centesimas entre refrescos durante la carga (por defecto 10)
```
El texto va diciendo *Conectando al servidor...*, *Ejecutando consulta...*, *Consulta lista: n filas en x ms*,
*Cargando 8018 de 30000 filas (26%)* y al final *30000 filas - consulta 70 ms + carga 370 ms*. La barra avanza
durante `LoadQueue` con el total exacto del resultado. Con los dos en 0 (por defecto) todo queda como antes.
Repinta con `DISPLAY(control)` + `YIELD()` (el `ACCEPT` no corre mientras se consulta y se carga) y como mucho
cada 100 ms: la carga de 30.000 filas tarda lo mismo con y sin avance (370 ms). Mientras el servidor procesa la
consulta la ventana no responde: se ve el texto, pero la barra no se mueve. Las dos pantallas MariaDB de la demo
lo usan (`TCWMariaDemo.exe maria` abre directo la de MariaDB).

Medido con capturas el 2026-10-29: con `SERVER=localhost` conectar tarda **~1,8 s** (Windows prueba primero
IPv6 `::1` y MySQL 5.0 escucha solo en IPv4); con `SERVER=127.0.0.1` es inmediato.

### Pantalla MariaDB por páginas
Menú *Comprobantes → MariaDB por páginas* (`ComprobantesPaginas`): mismos filtros, pero trae de a una página
(200 filas por defecto, campo *Página*) y pide la siguiente cuando el final de lo cargado entra en pantalla
(un `TIMER` cada 250 ms y `EVENT:NewSelection` miran `?Lista{PROP:YOrigin} + ?Lista{PROP:Items}`; anda con
la rueda, la barra y el teclado, sin `IMM`). La página siguiente continúa desde la última fila cargada:
`Fecha <= 'ult' AND (Fecha < 'ult' OR IdTransaccion < ultId)`, con el mismo `ORDER BY Fecha DESC, IdTransaccion DESC`.
No usa `OFFSET`: cada página cuesta lo mismo aunque se esté en la fila 30.000. `SQL.FreeQueue = False` hace que
`LoadQueue` agregue a la cola en vez de vaciarla. La fecha de la última fila se guarda como la manda el servidor
(`CBQ:FechaSql`, columna extra que no se muestra). *Contar* hace un `COUNT(*)` aparte para mostrar "N de total".

`TCWMariaDemo.exe paginas` lo prueba solo: carga unas 5.000 filas en páginas de 137 y las compara, fila por fila,
con una sola consulta del mismo orden. Resultado en `paginas.txt`. Verificado el 2026-10-29: 5.069 de 33.764
en 37 páginas, 0 diferencias, cada página de 137 filas en menos de 10 ms y el conteo en 10 ms.

## Template (`template\sqlclass6.tpl`)
Es el `sqlclass6.tpl` de siempre ("SqlClass para Clarion6") con una opción más en cada instancia de
**Objetos SQL Globales**: **Motor** = `Driver de la app` (como hasta ahora) o `MariaDB directo`.

- Una instancia en `MariaDB directo` (por ejemplo `SQLM`) se genera como `SQLM &SQLMariaClass` y
  `Hide:SQLM CLASS(SQLMariaClass)`, con los mismos embeds de métodos. Las demás siguen con el padre del driver.
- Solo si alguna instancia usa MariaDB se agregan `INCLUDE('SQLClass6Maria.inc')` y `libmariadb.lib` al proyecto.
- El `Init(archivo, registro, cadena)` y el resto de los métodos se llaman igual; la cadena puede ser la de ODBC.
- Para pasar un procedimiento a MariaDB se cambia `SQL.` por `SQLM.`; en `TCW_Display`, "Instancia SQLClass" = `SQLM`.
- Check **Usar StringTheory (log de la SQLClass)**, tildado por defecto. Destildado agrega `SQLClass6SinStringTheory=>1`
  al proyecto: `sqlclass6\SQLClass6.clw` (la SQLClass6 extendida del 13/19-10-2026) no incluye StringTheory y
  `WriteLog` escribe la misma línea con la API de Windows (`CreateFileA` en modo append + `WriteFile`).

`template\sqlclass6.original.tpl` es la copia sin cambios. Verificado el 2026-10-28:
- una app con una sola instancia (sin MariaDB) genera **exactamente los mismos archivos** con el template original y con el nuevo;
- `template\test\build-test-tpl.ps1` genera y corre `SqlTest` con `SQL` (ODBC) y `SQLM` (MariaDB) sobre `cbtes`:
  misma cantidad (33.764), razón social más larga 49 caracteres con ODBC y 70 con MariaDB.
  La prueba usa `template\.test` con su propio `Clarion110.red` y una copia del registro de templates: no toca la instalación.
  Compila con `sqlclass6\SQLClass6.*` del proyecto; `-SinStringTheory` prueba el check destildado (mismo resultado, log escrito sin StringTheory).

La SQLClass6 instalada no es la misma en todos lados: `C:\clarion11Col` tiene la extendida (ExecEx, ExecSP, LogFile,
ShowProgress, WriteLog); `C:\clarion11_DESAB` y `C:\Clarion12` tienen la original de 2011, contra la que
`SQLMariaClass` **no compila** (usa esos agregados).

Para instalarlo: respaldar y reemplazar `accessory\template\win\sqlclass6.tpl`, copiar `clarion\*.inc/.clw` a
`accessory\libsrc\win`, `lib\libmariadb.lib` a `accessory\lib` y `bin\libmariadb.dll` a `accessory\bin`
(y junto al .exe al distribuir).

## Documentación (`doc\`)
`doc\make-doc.py` genera la ayuda (47 páginas: guía, ejemplos de la demo, una página por método, TCWMariaDB) como
proyecto HTML Help estándar en `doc\html\` (`TCWMariaDB.hhp`, `toc.hhc`, `index.hhk`, HTML en windows-1252).
El contenido se edita en `make-doc.py`; después:
```powershell
python -I doc\make-doc.py
python -I ..\TCWChm\html2chm.py doc\html\TCWMariaDB.hhp -o doc\TCWMariaDB.chm
```
El .hhp también se compila con HTML Help Workshop o se importa en TCWHelp.

## Pendiente
- Conexión compartida por hilo (hoy cada objeto abre la suya).
- Sentencias preparadas con parámetros.

# tcwDriverMSSQL - la SQLClass directo a SQL Server

`SQLMsDirectClass` es la SQLClass (SQLClass6) de siempre, con los mismos métodos, las mismas firmas y los mismos
códigos de retorno, pero sin el driver MSSQL de Clarion ni la tabla de trabajo `SQLClass`: manda el SQL con la API
de ODBC (`odbc32.dll`) al driver nativo de Microsoft (**ODBC Driver 17/18 for SQL Server**, TDS 7.4).
Es el mismo esquema que `tcwDriverMariaDB` (`SQLMariaClass`).

**SQLClass6.INC / .clw no se tocan.** `SQLMsDirectClass` hereda de `SQLOdbcClass` y reimplementa sus métodos en
archivos propios. No hay DLL propia para distribuir: el motor está en `tcwmss.c`, que Clarion compila dentro del exe
(`PRAGMA('compile(tcwmss.c)')`), y `odbc32.dll` se carga en tiempo de ejecución.

## Uso
```clarion
  INCLUDE('SQLClass6MsDirect.inc'),ONCE
CLASSQ   &SQLMsDirectClass                 ! el tipo tiene que ser SQLMsDirectClass (no SQLMsClass)
  CODE
  CLASSQ &= NEW SQLMsDirectClass
  IF CLASSQ.InitDirect('PC\INSTANCIA,base,usuario,clave') THEN ...error....   ! el owner de siempre
  ! o, sin cambiar el codigo existente: CLASSQ.Init(Sqlclass,Sqlclass:Record,'PC\INSTANCIA,base,usuario,clave')
  IF CLASSQ.Exec('SELECT codigo, nombre FROM articulos WHERE activo = 1') THEN RETURN.
  LOOP UNTIL CLASSQ.Next()
     Q:Codigo = CLASSQ.Col(1)
     Q:Nombre = CLASSQ.ColByName('nombre')
     ADD(Q)
  END
  CLASSQ.AddParam(Cliente)                                     ! parametros '?': sin comillas ni escape
  CLASSQ.ExecEx('SELECT ... FROM Cbtes WHERE IdCliente = ?',1)
  CLASSQ.Exec('INSERT INTO clientes (nombre) VALUES (' & CLASSQ.Quote(Nombre) & ')')
  NuevoId = CLASSQ.InsertId()                                  ! SCOPE_IDENTITY() del mismo lote
```

| Igual que SQLClass6 | Init, Kill, Exec, ExecEx, ExecSP, SP, Parse, ServerExec, ServerExecEx, Next, Col, Col_Format, Columns, Field, Fetch (2), Records, LoadQueue, RegisterUpdate, UpdateBuffer, Take*, WriteLog; propiedades SilentMode, LogFile, ShowProgress, MaxReads, FreeQueue, Records, Records_Done, PK_Col |
|---|---|
| Nuevos | `InitDirect(conexion)`, `AddParam(valor)` / `AddNullParam()`, `NextResult()`, `ColByName(nombre)`, `IsNull(n)`, `Escape`, `Quote`, `InsertId()`, `AffectedRows()`, `ErrorText()`, `ErrorCode()` (número de SQL Server: 208, 2627...), `ServerVersion()`, `BeginTransaction/Commit/Rollback()`, `KeepCase`, avance en la ventana (`ProgressFeq`, `ProgressTextFeq`, `ProgressDelay`) y `Db` (la conexión `TCWMsSQL`) |

Conexión, tres formas:
- el **owner del driver MSSQL de Clarion**: `servidor,base,usuario,clave` (así un `Init` existente no cambia);
- `Server=PC\INSTANCIA;Database=base;User=u;Password=p;Timeout=15;Encrypt=0` (sin `User` = seguridad de Windows);
- una cadena ODBC completa (`Driver={...};Server=...`), que se usa tal cual.

Sin cadena ODBC prueba, en orden, `ODBC Driver 17 for SQL Server`, `ODBC Driver 18 for SQL Server` y el viejo
`SQL Server` (pasa al siguiente solo si el driver no está instalado). `SQL.Db.ClientVersion()` dice cuál usó.

### Cómo trabaja
- Cada consulta se lee **entera al ejecutarla** (como `mysql_store_result`), por bloques de 500 filas: `Records()` es
  exacto y la barra de avance tiene total. Las columnas largas (`varchar(max)`, `text`, `xml`) se leen completas con
  `SQLGetData`, sin cortar.
- Todo viaja como texto: fechas `aaaa-mm-dd` (`Col_Format(n,'@d10-')`), decimales con punto.
- Un procedimiento que hace `UPDATE` antes del `SELECT` funciona igual: los conteos intermedios se saltean.
  Si devuelve varios `SELECT`, `NextResult()` pasa al siguiente.
- `ExecSP('EXEC sp p1, p2')` va tal cual; `ExecSP('CALL sp(p1)')` se manda con el escape de ODBC `{CALL sp(p1)}`.
- Si se cae la conexión (SQLSTATE 08xxx), reconecta y reintenta una vez (fuera de una transacción).

### A tener en cuenta
- `Exec` pasa la consulta a minúsculas, igual que SQLClass6 (también los valores entre comillas): para escribir datos
  usar `ExecEx(q,1)`, `KeepCase = 1` o parámetros.
- Un objeto tiene un resultado abierto por vez (igual que antes). Como el resultado se lee entero, una consulta de
  millones de filas ocupa esa memoria: paginar con `TOP` (ver la demo).
- Los textos `nvarchar` llegan en la página de códigos de Windows (1252): un carácter fuera de ella llega como `?`.

## Velocidad (2026-10-29, SQL Server 2022 local, base psnamen, tabla `dbo.Cbtes`)
Misma consulta (9 columnas, `ORDER BY Fecha DESC, IdTransaccion DESC`), carga a la cola con `Col_Format` + `LoadQueue`,
1 corrida más 1 de calentamiento (`bench\build-bench.ps1`). Mismas filas y misma suma de importes en todos.

| Escenario | Filas | SQLMsClass (driver MSSQL) | **SQLMsDirectClass** | Veces |
|---|---|---|---|---|
| Toda la tabla | 101.798 | 26,2 s | **1,74 s** | 15 |
| Últimos 30.000 | 30.000 | 9,7 s | **0,41 s** | 24 |
| Año 2025 | 25.820 | 16,8 s | **1,54 s** | 11 |
| `LIKE '%SRL%'` | 893 | 0,66 s | **0,20 s** | 3,3 |
| Un cliente | 551 | 394 ms | **40 ms** | 10 |
| Un comprobante | 1 | 14,5 ms | **6,2 ms** | 2,3 |

El driver MSSQL de Clarion 11 se conecta con **TDS 7.1** (el driver `SQL Server` de Windows, de la época de SQL
Server 2000) y, sin `BUFFER`, espera al servidor fila por fila: 56 s de reloj con 15 s de CPU.

### Con `BUFFER` (2026-10-29, 1 corrida: los tiempos varían bastante entre corridas)
`BUFFER(vista o archivo, n)` después del `OPEN` hace que el driver traiga n filas por viaje. Cambia mucho:

| Escenario | `VIEW` sin / con `BUFFER(500)` | `FILE`+`PROP:SQL` sin / con `BUFFER(500)` | SQLMsDirectClass |
|---|---|---|---|
| Toda la tabla (101.798) | 27,4 s / **4,4 s** | 22,9 s / **5,1 s** | 1,72 s |
| Últimos 30.000 | 4,3 s / **1,3 s** | 4,2 s / **1,4 s** | 0,60 s |
| Año 2025 (25.820) | 7,0 s / **1,0 s** | 8,1 s / **1,7 s** | 0,47 s |
| Un cliente (551) | 80 ms / **20 ms** | 74 ms / **26 ms** | 16 ms |

Con `BUFFER` el driver de Clarion queda **2 a 3 veces** más lento que la clase directa (sin `BUFFER`, 15 a 50).
`SQLMsClass` no lo puede aprovechar sin cambiar SQLClass6: `ServerExecEx` hace `CLOSE` + `OPEN` de su archivo de
trabajo en cada consulta y el `BUFFER` se pierde (la prueba que imita a SQLMsClass con `BUFFER` todavía no trae filas).

### Escritura (5.000 filas en `tempdb.dbo.tcw_bench`, 3 corridas, filas por segundo)
| Forma | Corrida 1 / 2 / 3 |
|---|---|
| Driver MSSQL: `ADD` sin `LOGOUT` | 1.781 / 2.110 / 2.835 |
| Driver MSSQL: `LOGOUT` + `ADD` + `COMMIT` | 1.927 / 2.841 / 2.329 |
| SQLMsClass: un `INSERT` armado por fila | 1.526 / 1.241 / 1.190 |
| SQLMsDirectClass: un `INSERT` armado por fila | 1.422 / 1.400 / 1.381 |
| SQLMsDirectClass: `Insertar` (preparado) | 2.338 / 1.940 / 2.404 |
| **SQLMsDirectClass: `InsertarLote` (500 filas por viaje)** | **5.746 / 6.900 / 7.325** |

- Armar el `INSERT` como texto en cada fila (`PROP:SQL` o `Exec`) es lo más lento: el servidor analiza el texto cada vez.
- `Insertar` prepara la sentencia una vez y manda solo los valores: rinde como el driver de Clarion con `ADD`.
- `InsertarLote` manda 500 filas en un viaje (arreglos de parámetros de ODBC): **unas 3 veces el driver de Clarion**.
- En `tempdb` SQL Server no espera a grabar el log en cada confirmación: el efecto de `LOGOUT` / transacción en una
  base normal es mayor que el que se ve acá.
- La consulta de SQLClass6 tiene un límite de 20.480 caracteres (`Query CSTRING(20480)`); `Campo`/`Insertar` no.

### INSERT por nombre de campo (en vez de armar el texto con `PROP:SQL`)
```clarion
  SQL.Campo('IdTransaccion',Loc:IdTransaccion)
  SQL.Campo('TipoCbte',Loc:TipoCbte)                 ! texto: sin comillas ni Clip; una ' o una " adentro no rompe nada
  SQL.Campo('Descripcion',Loc:RazonSocial)
  SQL.Campo('ImporteTotal',Loc:TTotal)
  SQL.CampoFecha('Fecha',Loc:Fecha)                  ! fecha de Clarion; 0 = NULL (en vez de Fun_Date)
  SQL.CampoFechaHora('Aud_Fecha',glo:hoy,CLOCK())    ! en vez de Fun_DateTime
  SQL.CampoNulo('FecVencOri')
  IF SQL.Insertar('cbtes') THEN ...error: SQL.ErrorText()...
```
`Insertar` arma `INSERT INTO cbtes (...) VALUES (?,?,...)`, lo prepara la primera vez y lo reutiliza mientras los
campos sean los mismos. Para muchas filas, `InsertarLote('cbtes')` en el ciclo y `EnviarLote()` al final
(`SQL.Db.BatchSize`, por defecto 500). Para otras sentencias: `Prepare('UPDATE t SET a = ? WHERE id = ?')`, `AddParam`
por valor y `ExecPrepared()`; o `AddRow()` por fila y `ExecPrepared()` para mandar el lote.

Los textos entre comillas dobles (`"texto"`) del `PROP:SQL` armado a mano funcionan con el driver de Clarion porque
conecta con `QUOTED_IDENTIFIER` apagado; con el ODBC Driver 17/18 viene encendido y `"texto"` es un nombre de columna.

## Archivos
| Carpeta | Contenido |
|---|---|
| `clarion\` | `SQLClass6MsDirect.inc/.clw` (SQLMsDirectClass), `TCWMsSQL.inc/.clw` (conexión directa, se puede usar sola), `tcwmss.c` (motor ODBC) |
| `tests\TestMsSQL.clw` | prueba de todos los métodos sobre una tabla y un procedimiento `#temporales` (no deja nada en la base) |
| `bench\` | prueba de velocidad: 6 motores contra la misma consulta (`tcwodbc.c` es la lectura directa mínima) |
| `demo\` | app de ejemplo |

Requisitos del proyecto: SQLClass6 extendida (la de `tcwDriverMariaDB\sqlclass6` o `C:\clarion11Col`) + StringClass;
`tcwmss.c` junto a las clases (en `accessory\libsrc\win` al instalar). En el cliente: el ODBC Driver 17 o 18
(si no está, usa el `SQL Server` de Windows, más lento).

## Prueba
```powershell
.\build-test.ps1 -Conexion 'PC\INSTANCIA,base,usuario,clave'
```
Verificado el 2026-10-29 contra SQL Server 2022 (psnamen) con ODBC Driver 17: **TODO OK** (45 controles: InsertId,
parámetros con comillas y NULL, texto de 10.000 caracteres, fechas, transacción con rollback, dos resultados en un
lote, procedimiento con conteos intermedios y dos `SELECT`, `{CALL}`, `Records()` con `GROUP BY`, errores 208 y 2627).

## App de ejemplo (`demo\`)
Menú *Comprobantes*: **SQL Server directo** (con barra de avance), **SQL Server por páginas** (carga al bajar),
**Driver MSSQL de Clarion** (`SQLMsClass` + `FILE,DRIVER('MSSQL')` sobre la tabla `SQLClass` que ya existe en la base)
y **Comparar tiempos** (8 escenarios, por defecto 5.000 filas y 2 corridas: con el driver de Clarion tarda).

**Ejemplos de uso** (`demo\ejemplos.py`): una pestaña por uso, con sus datos, el botón y el código Clarion a la vista.
Las escrituras van a `tempdb.dbo.tcw_demo` y `tempdb.dbo.tcw_demo_lote` (no se toca la base de la aplicación).

| Pestaña | Qué muestra | Resultado (2026-10-29) |
|---|---|---|
| 1. Parámetros `?` | comprobantes de un cliente desde una fecha, con `AddParam` | 188 filas en 10 ms |
| 2. Insertar | `Campo` / `CampoFecha` / `CampoFechaHora` / `CampoNulo` + `Insertar` | el texto `O'Brien "el de las comillas"` vuelve igual |
| 3. InsertarLote | las mismas 2.000 filas de tres formas, con barra de avance | texto (`PROP:SQL`) 627 f/s · `Insertar` 6.250 f/s (10×) · `InsertarLote` 15.385 f/s (24×) |
| 4. Prepare | un `UPDATE` preparado, ejecutado dos veces con otros valores | 200 filas cada vez; la suma vuelve a la original |
| 5. Transacción | `BeginTransaction` + `DELETE` + `Rollback` | 2.000 → 0 → 2.000 |
| 6. Varios resultados | un procedimiento con dos `SELECT`, leídos con `NextResult` | resumen por tipo + últimos 10 |
| 7. Texto largo | `varchar(max)` de 20.000 caracteres, grabado y leído | idéntico |

`TCWMsSQLDemo.exe ejemplos` corre las siete pestañas y deja el resultado en `ejemplos.txt`. Los tiempos varían entre
corridas (en otra, `Insertar` dio 4× y `InsertarLote` 16×).
```powershell
demo\build-demo.ps1 -Conexion 'PC\INSTANCIA,base,usuario,clave' -Run
```
La misma cadena (el owner) sirve para las dos clases; queda en `demo\.build\TCWMsSQLDemo.ini`, no en el código.
`TCWMsSQLDemo.exe directo`, `paginas` y `comparar` abren o corren cada pantalla sola (`paginas` y `comparar` dejan
el resultado en `paginas.txt` / `comparacion.txt`).

Por páginas verificado el 2026-10-29: 5.069 filas en 37 páginas de 137, **0 diferencias** con una sola consulta.
Cada página tarda ~90 ms (en MySQL < 10 ms) porque en psnamen ningún índice empieza por `(Fecha, IdTransaccion)`:
SQL Server ordena todo el filtro en cada página. Con un índice `(Fecha DESC, IdTransaccion DESC)` cada página
bajaría a pocos ms (no se creó: es la base real).

## Pendiente
- Opción **Motor = SQL Server directo** en `sqlclass6.tpl` (como "MariaDB directo").
- Cancelar una consulta larga (`SQLCancel` desde otro hilo).

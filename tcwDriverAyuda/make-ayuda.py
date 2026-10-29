"""Genera el proyecto TCWHelp de la ayuda 'SQLClass directo' (SQLMariaClass y SQLMsDirectClass).

python -I make-ayuda.py                       -> proyecto.tcwhelp + topics\\*.html
..\\TCWHelp\\app\\bin\\Release\\net8.0-windows\\TCWHelp.exe --build proyecto.tcwhelp all   -> salida\\ (chm, html, pdf)
El contenido se edita aca (o despues en el editor de TCWHelp). Las cifras son las medidas del 28 y 29/10/2026.
"""
import html
import json
from pathlib import Path

DIR = Path(__file__).parent
TOPICS = DIR / "topics"


def esc(t):
    return html.escape(t, quote=False)


def p(*parts):
    return "".join(f"<p>{x}</p>" for x in parts)


def h(t):
    return f"<h2>{t}</h2>"


def h3(t):
    return f"<h3>{t}</h3>"


def code(t):
    return f"<pre><code>{esc(t.strip(chr(10)))}</code></pre>"


def c(t):
    return f"<code>{esc(t)}</code>"


def ul(*items):
    return "<ul>" + "".join(f"<li>{i}</li>" for i in items) + "</ul>"


def table(head, *rows):
    th = "".join(f"<th>{x}</th>" for x in head)
    tr = "".join("<tr>" + "".join(f"<td>{x}</td>" for x in r) + "</tr>" for r in rows)
    return f"<table><thead><tr>{th}</tr></thead><tbody>{tr}</tbody></table>"


def nota(t, kind="nota", titulo="Nota"):
    return f'<div class="callout" data-kind="{kind}"><p><strong>{titulo}:</strong> {t}</p></div>'


def aviso(t):
    return nota(t, "aviso", "Cuidado")


def a(tid, t):
    return f'<a href="tcw:{tid}">{t}</a>'


# ------------------------------------------------------------------------------------------------ temas
T = {}

T["introduccion"] = ("Introducción", p(
    "<strong>SQLClass directo</strong> son dos clases que hacen lo mismo que la SQLClass de siempre (SQLClass6), con los "
    "mismos métodos, firmas y códigos de retorno, pero mandando el SQL <em>directo</em> al servidor, sin el driver de "
    "archivos de Clarion ni la tabla de trabajo <code>sqlclass</code>:"),
    table(["Clase", "Servidor", "Cómo llega al servidor"],
          ["<code>SQLMariaClass</code>", "MariaDB / MySQL", "<code>libmariadb.dll</code> (MariaDB Connector/C), protocolo de MySQL"],
          ["<code>SQLMsDirectClass</code>", "SQL Server", "API de ODBC (<code>odbc32.dll</code>) + ODBC Driver 17/18 de Microsoft (TDS 7.4)"]),
    h("Por qué"),
    ul("<strong>Más rápido</strong>: leyendo muchas filas, 1,5 veces (MariaDB) y 10 a 25 veces (SQL Server, contra el driver "
       "MSSQL sin <code>BUFFER</code>); escribiendo muchas filas con " + c("InsertarLote") + ", 3 veces (SQL Server) y 100 veces "
       "(MySQL) más que el <code>INSERT</code> armado como texto. Ver " + a("estadisticas", "Estadísticas") + ".",
       "<strong>Sin límites</strong> de columnas ni de largo de cada valor (la tabla <code>sqlclass</code> corta a 49 caracteres).",
       "<strong>Más cosas</strong>: parámetros <code>?</code>, varios resultados por consulta, sentencias preparadas, "
       "<code>INSERT</code> por nombre de campo, lotes, transacciones, <code>Records()</code> exacto y barra de avance en la ventana.",
       "<strong>Sin cambiar el código</strong>: <code>Init(archivo, registro, conexión)</code> sigue andando; el archivo se ignora."),
    nota("SQLClass6.INC / .clw no se modifican: las apps que usan <code>SQLMsClass</code> u ODBC siguen igual. "
         "Cada clase hereda de <code>SQLOdbcClass</code> y reimplementa sus métodos en archivos propios."),
    p("Para empezar: " + a("instalacion", "Instalación") + " y " + a("guia", "Guía rápida") + "."))

T["novedades"] = ("Novedades", h("29/10/2026") + ul(
    "<strong>SQLMsDirectClass</strong> (nueva): SQL Server directo por la API de ODBC, con lectura por bloques de 500 filas.",
    "Parámetros <code>?</code> (" + c("AddParam") + ", " + c("AddNullParam") + ") y " + c("NextResult") + " en las dos clases.",
    "Sentencias preparadas (" + c("Prepare") + ", " + c("ExecPrepared") + ", " + c("AddRow") + ") e <code>INSERT</code> por nombre "
    "de campo (" + c("Campo") + ", " + c("CampoFecha") + ", " + c("CampoFechaHora") + ", " + c("CampoNulo") + ", " + c("Insertar") +
    ", " + c("InsertarLote") + ", " + c("EnviarLote") + ").",
    "Barra de avance en la propia ventana (" + c("ProgressFeq") + ", " + c("ProgressTextFeq") + ").",
    "Demos: pantalla <em>Ejemplos de uso</em> (una pestaña por uso), <em>por páginas</em> y <em>Comparar</em> con % y barra.") +
    h("28/10/2026") + ul("<strong>SQLMariaClass</strong>: la SQLClass directo a MariaDB / MySQL; opción <em>MariaDB directo</em> en "
                         "<code>sqlclass6.tpl</code>; comparación con ODBC."))

T["instalacion"] = ("Instalación", h("Archivos") + table(
    ["Clase", "Archivos (en <code>accessory\\libsrc\\win</code>)", "Con el .exe"],
    ["SQLMariaClass", "<code>SQLClass6Maria.inc/.clw</code>, <code>TCWMariaDB.inc/.clw</code>; <code>libmariadb.lib</code> en <code>accessory\\lib</code>",
     "<code>libmariadb.dll</code> (MariaDB Connector/C 3.4, 32 bits)"],
    ["SQLMsDirectClass", "<code>SQLClass6MsDirect.inc/.clw</code>, <code>TCWMsSQL.inc/.clw</code>, <code>tcwmss.c</code> (lo compila Clarion dentro del exe)",
     "nada propio; en el cliente el <em>ODBC Driver 17 o 18 for SQL Server</em> (si no está, usa el viejo <code>SQL Server</code> de Windows)"]) +
    h("Requisitos") + ul(
    "La <strong>SQLClass6 extendida</strong> (con <code>ExecEx</code>, <code>ExecSP</code>, <code>LogFile</code>): la de "
    "<code>tcwDriverMariaDB\\sqlclass6</code> o la de <code>C:\\clarion11Col</code>. Con la original de 2011 no compila.",
    "StringClass (como siempre). StringTheory es opcional: con <code>SQLClass6SinStringTheory=&gt;1</code> el log se escribe con la API de Windows.",
    "MariaDB: agregar <code>libmariadb.lib</code> a las <em>Libraries</em> del proyecto.") +
    h("En el código") + code("""
  INCLUDE('SQLClass6MsDirect.inc'),ONCE        ! o SQLClass6Maria.inc
SQL      &SQLMsDirectClass                     ! o &SQLMariaClass (no SQLMsClass)
  CODE
  SQL &= NEW SQLMsDirectClass
  IF SQL.InitDirect('PC\\INSTANCIA,base,usuario,clave') THEN ...error: SQL.ErrorText()...
""") + p("Con el template <code>sqlclass6.tpl</code>: en <em>Objetos SQL Globales</em> elegir <strong>Motor = MariaDB directo</strong> "
         "(SQL Server directo: pendiente). Ver " + a("conexion", "Cadena de conexión") + "."))

T["conexion"] = ("Cadena de conexión", table(
    ["Forma", "Ejemplo", "Clase"],
    ["Owner del driver de Clarion", "<code>PC\\INSTANCIA,base,usuario,clave</code>", "SQLMsDirectClass (así un <code>Init</code> existente no cambia)"],
    ["Clave=valor", "<code>Server=PC\\INSTANCIA;Database=base;User=u;Password=p;Timeout=15</code>", "las dos"],
    ["Cadena ODBC", "<code>Driver={ODBC Driver 17 for SQL Server};Server=...;Uid=...;Pwd=...</code>", "las dos (MariaDB ignora DRIVER y OPTION)"]) +
    h("Claves") + table(["Clave", "Sinónimos", "Qué hace"],
                        ["Server", "Host, Data Source, Address", "servidor; en SQL Server <code>PC\\INSTANCIA</code> o <code>servidor,1433</code>"],
                        ["Port", "", "MariaDB: 3306 por defecto"],
                        ["Database", "Db, Initial Catalog", "base"],
                        ["User / Password", "Uid, User Id / Pwd", "en SQL Server, sin User = seguridad integrada de Windows"],
                        ["Timeout", "Connect Timeout", "segundos (MariaDB 10, SQL Server 15)"],
                        ["Charset", "", "MariaDB: <code>latin1</code> (los textos de Clarion viajan sin conversión)"],
                        ["Encrypt / SSL", "", "1 = conexión cifrada (con el Driver 18 confía en el certificado)"]) +
    p("SQL Server sin cadena ODBC prueba en orden <em>ODBC Driver 17</em>, <em>18</em> y <em>SQL Server</em> (solo pasa al "
      "siguiente si el driver no está instalado). " + c("SQL.Db.ClientVersion()") + " dice cuál usó.") +
    aviso("con <code>Server=localhost</code> conectar a MySQL 5.0 tardó <strong>1,8 s</strong> (Windows prueba primero IPv6 "
          "<code>::1</code> y MySQL 5.0 escucha solo en IPv4); con <code>Server=127.0.0.1</code> es inmediato."))

T["guia"] = ("Guía rápida", h("Leer") + code("""
  SQL.AddParam(Cliente)                                    ! parametros '?': sin comillas ni escape
  IF SQL.ExecEx('SELECT IdTransaccion, Fecha, Descripcion FROM cbtes WHERE IdCliente = ?',1)
    MESSAGE(SQL.ErrorText()) ; RETURN
  END
  LOOP UNTIL SQL.Next()
    Q:Id = SQL.Col(1) ; Q:Nombre = SQL.ColByName('Descripcion') ; ADD(Q)
  END
  ! o de una: SQL.Col_Format(2,'@d10-') ; SQL.LoadQueue(Q,0,0)
""") + h("Escribir") + code("""
  SQL.Campo('IdCliente',Cliente)
  SQL.Campo('Descripcion',RazonSocial)                     ! una ' o una " adentro no rompe nada
  SQL.CampoFecha('Fecha',Fecha)                            ! 0 = NULL
  IF SQL.Insertar('cbtes') THEN MESSAGE(SQL.ErrorText()).
""") + h("Muchas filas") + code("""
  LOOP ...
    SQL.Campo(...) ...
    SQL.InsertarLote('cbtes')                              ! de a 500 filas por viaje
  END
  SQL.EnviarLote()                                         ! las que quedan
""") + p("Exec y ExecEx devuelven <code>Level:Benign</code> (0) si anduvo; <code>Next()</code> devuelve 0 mientras trae filas. "
         "Los temas de " + a("leer", "Leer datos") + " y " + a("escribir", "Escribir datos") + " tienen el detalle."))

T["leer"] = ("Leer datos", table(
    ["Método", "Qué hace"],
    [c("Exec(q)"), "ejecuta (pasa la consulta a minúsculas, como SQLClass6)"],
    [c("ExecEx(q,1)"), "ejecuta respetando mayúsculas (recomendado; los valores entre comillas no se tocan)"],
    [c("Next()"), "fila siguiente: 0 = trajo una; distinto de 0 = no hay más"],
    [c("Col(n)") + " / " + c("ColByName(nombre)"), "valor como texto (fechas <code>aaaa-mm-dd</code>, decimales con punto)"],
    [c("IsNull(n)"), "1 si el valor es NULL"],
    [c("Columns()") + " / " + c("Field(n)"), "cantidad de columnas / nombre real de la columna n"],
    [c("Records()"), "filas del resultado, exacto (también con GROUP BY / DISTINCT): el resultado se lee entero al ejecutar"],
    [c("Col_Format(n,pic)") + " + " + c("LoadQueue(Q,0,0)"), "carga la cola campo por campo con DEFORMAT"],
    [c("Fetch(n,q)"), "primer valor de una consulta"]) +
    nota("cada consulta se lee <strong>entera</strong> al ejecutarla (como <code>mysql_store_result</code>): <code>Records()</code> "
         "es exacto y la barra de avance tiene total. Una consulta de millones de filas ocupa esa memoria: paginar "
         "(ver " + a("paginas", "Carga por páginas") + ")."))

T["parametros"] = ("Parámetros ?", p(
    "Cada <code>?</code> de la consulta se reemplaza, en orden, por un valor agregado con " + c("AddParam") + " (o NULL con " +
    c("AddNullParam") + "). La consulta los consume: después de ejecutar la lista queda vacía.") + code("""
  SQL.AddParam(L:Cliente)
  SQL.AddParam(FORMAT(L:Desde,@d10-))
  SQL.ExecEx('SELECT ... FROM cbtes WHERE IdCliente = ? AND Fecha >= ? ORDER BY Fecha DESC',1)
""") + table(["", "SQL Server", "MariaDB / MySQL"],
             ["Cómo viaja el valor", "aparte del SQL (<code>SQLBindParameter</code>)", "escapado y entre comillas, reemplazado del lado del cliente (<code>mysql_real_escape_string</code>)"],
             ["Un <code>?</code> entre comillas", "no es parámetro", "no se toca (<code>'a?b'</code> queda igual)"],
             ["Más de 8.000 caracteres", "va como <code>varchar(max)</code>", "sin límite (hasta <code>max_allowed_packet</code>)"]) +
    p("Ventajas: sin comillas, sin <code>CLIP</code>, sin errores por una <code>'</code> en el texto y sin inyección de SQL."))

T["varios"] = ("Varios resultados", p(
    "Un procedimiento puede devolver varios <code>SELECT</code>, y una consulta puede tener varias sentencias. "
    "Se lee el primer resultado como siempre y " + c("NextResult()") + " pasa al siguiente (devuelve <code>Level:Notify</code> cuando no hay más).") +
    code("""
  SQL.AddParam(Cliente)
  SQL.ExecSP('EXEC dbo.Resumen ?')        ! MariaDB: ExecSP('CALL Resumen(?)')
  LOOP UNTIL SQL.Next()                   ! resultado 1
  END
  IF SQL.NextResult() = Level:Benign      ! resultado 2
    LOOP UNTIL SQL.Next()
    END
  END
""") + ul("Los conteos intermedios de un procedimiento (<code>UPDATE</code> antes del <code>SELECT</code>) se saltean solos.",
          "Una consulta <code>UPDATE ...; SELECT ...</code> queda directamente en el resultado del <code>SELECT</code>.",
          "MariaDB: la conexión habilita <code>CLIENT_MULTI_STATEMENTS</code>; <code>ExecSP('EXEC sp p1, p2')</code> se manda como "
          "<code>CALL sp(p1, p2)</code> y el resultado de estado del CALL se descarta.",
          "SQL Server: <code>ExecSP('CALL sp(p)')</code> va con el escape de ODBC <code>{CALL sp(p)}</code>.") +
    nota("un resultado con resultados pendientes sin leer no traba la consulta siguiente: la clase los descarta antes de ejecutar."))

T["largos"] = ("Textos largos", p(
    "No hay límite de columnas ni de largo: la tabla de trabajo <code>sqlclass</code> del driver de Clarion tiene 20 campos de "
    "49 caracteres y corta lo que pasa de ahí (en la prueba, ODBC perdió 4.045 caracteres de razón social en 30.000 filas).") +
    ul("SQL Server: <code>varchar(max)</code>, <code>text</code>, <code>xml</code> se leen enteros con <code>SQLGetData</code>.",
       "MariaDB: <code>TEXT</code>, <code>MEDIUMTEXT</code> sin conversión.",
       "Verificado: un texto de 20.000 caracteres se graba y se lee idéntico en los dos.") +
    aviso("los textos <code>nvarchar</code> de SQL Server llegan en la página de códigos de Windows (1252): un carácter fuera de ella llega como <code>?</code>."))

T["paginas"] = ("Carga por páginas", p(
    "Para listas grandes: se trae una página (por ejemplo 200 filas) y la siguiente cuando el final de lo cargado entra en "
    "pantalla. La página siguiente <strong>continúa desde la última fila</strong> (clave), no usa <code>OFFSET</code>:") +
    code("""
  ! primera pagina
  SELECT TOP 200 ... FROM cbtes WHERE <filtro> ORDER BY Fecha DESC, IdTransaccion DESC     ! MySQL: ... LIMIT 200
  ! siguientes: desde la ultima fila cargada
  ... AND Fecha <= 'ult' AND (Fecha < 'ult' OR IdTransaccion < ultId)
""") + ul("Se detecta el final con un <code>TIMER</code> y <code>EVENT:NewSelection</code> mirando "
          "<code>?Lista{PROP:YOrigin} + ?Lista{PROP:Items}</code> (anda con la rueda, la barra y el teclado, sin <code>IMM</code>).",
          "<code>SQL.FreeQueue = False</code>: <code>LoadQueue</code> agrega a la cola en vez de vaciarla.",
          "Guardar la fecha tal como la manda el servidor (columna extra con alias: en SQL Server la misma columna dos "
          "veces con <code>ORDER BY</code> por ella da el error 209).") +
    p("Resultados en " + a("est-paginas", "Páginas y conexión") + "."))

T["avance"] = ("Barra de avance en la ventana", code("""
  SQL.ProgressFeq     = ?SQLBarra       ! PROGRESS,RANGE(0,100)
  SQL.ProgressTextFeq = ?SQLTexto       ! STRING
  SQL.ProgressDelay   = 10              ! centesimas entre refrescos (por defecto 10)
""") + p("El texto va diciendo <em>Conectando al servidor...</em>, <em>Ejecutando consulta...</em>, <em>Consulta lista: n filas en x ms</em>, "
         "<em>Cargando 8018 de 30000 filas (26%)</em> y al final <em>30000 filas - consulta 70 ms + carga 370 ms</em>.") +
    ul("Con los dos en 0 (por defecto) todo queda como antes.",
       "Repinta con <code>DISPLAY(control)</code> + <code>YIELD()</code> como mucho cada 100 ms: la carga tarda lo mismo con y sin barra (370 ms para 30.000 filas).",
       "Asignarlos <em>antes</em> de <code>Init</code> para ver también <em>Conectando...</em>.") +
    aviso("mientras el servidor procesa la consulta la ventana no responde: se ve el texto pero la barra no se mueve."))

T["escribir"] = ("Escribir datos", table(
    ["Forma", "Cuándo", "Tema"],
    [c("Campo") + " + " + c("Insertar"), "una fila", a("insertar", "Campo e Insertar")],
    [c("Campo") + " + " + c("InsertarLote") + " + " + c("EnviarLote"), "muchas filas", a("lotes", "Lotes")],
    [c("Prepare") + " + " + c("AddParam") + " + " + c("ExecPrepared"), "UPDATE / DELETE repetidos", a("preparadas", "Sentencias preparadas")],
    [c("BeginTransaction") + " / " + c("Commit") + " / " + c("Rollback"), "todo o nada", a("transacciones", "Transacciones")],
    [c("ExecEx(q,1)"), "una sentencia suelta", "—"]) +
    p("Si hoy arman los <code>INSERT</code> con <code>PROP:SQL</code>: " + a("migrar", "Pasar un INSERT de PROP:SQL a Campo/Insertar") + "."))

T["insertar"] = ("Campo e Insertar", code("""
  SQL.Campo('Nombre',L:Nombre)                    ! texto: sin comillas ni CLIP
  SQL.Campo('Importe',L:Importe)                  ! numeros: mejor DECIMAL que REAL
  SQL.CampoFecha('Fecha',L:Fecha)                 ! fecha de Clarion; 0 = NULL
  SQL.CampoFechaHora('Hora',TODAY(),CLOCK())      ! 'aaaa-mm-dd hh:mm:ss'
  SQL.CampoNulo('Nota')
  IF SQL.Insertar('clientes') THEN MESSAGE(SQL.ErrorText()).
""") + ul("<code>Insertar</code> arma <code>INSERT INTO tabla (c1,c2,...) VALUES (?,?,...)</code> con los campos agregados.",
          "SQL Server: la sentencia se prepara la primera vez y se reutiliza mientras los campos sean los mismos.",
          "El servidor convierte cada valor al tipo de la columna (texto, número, fecha <code>aaaa-mm-dd</code>).",
          "SQL Server: <code>SQL.InsertId()</code> da el IDENTITY de un <code>INSERT</code> hecho con <code>Exec</code> "
          "(agrega <code>SCOPE_IDENTITY()</code> en el mismo lote); MariaDB: <code>InsertId()</code> después de cualquier INSERT.") +
    aviso("un <code>REAL</code> convertido a texto puede salir en notación científica (<code>1.5E+20</code>) y SQL Server no lo "
          "acepta para un <code>decimal</code>: para importes usar variables <code>DECIMAL</code>."))

T["lotes"] = ("Lotes (InsertarLote)", code("""
  LOOP I = 1 TO RECORDS(Q)
    GET(Q,I)
    SQL.Campo('Id',Q:Id)
    SQL.Campo('Nombre',Q:Nombre)
    SQL.CampoFecha('Fecha',Q:Fecha)
    IF SQL.InsertarLote('clientes') THEN BREAK.
  END
  SQL.EnviarLote()                                ! las que quedan
""") + table(["", "SQL Server", "MariaDB / MySQL"],
             ["Cómo", "arreglos de parámetros de ODBC: 500 filas en una llamada", "un <code>INSERT ... VALUES (...),(...)</code> de 500 filas"],
             ["Tamaño", "<code>SQL.Db.BatchSize</code> (500)", "<code>BatchSize</code> (500) y <code>MaxBatchBytes</code> (512 KB: MySQL 5.0 acepta 1 MB por paquete)"],
             ["2.000 filas", "15.385 filas/s (24 veces el INSERT como texto)", "40.000 filas/s (100 veces)"]) +
    p("Las filas se mandan solas cada <code>BatchSize</code>; <code>SQL.Db.PendingRows()</code> dice cuántas faltan. "
      "Para otra sentencia: " + c("Prepare") + " + " + c("AddParam") + " de cada valor + " + c("AddRow") + " por fila + " + c("ExecPrepared") + "."))

T["preparadas"] = ("Sentencias preparadas", code("""
  SQL.Prepare('UPDATE lote SET Importe = Importe * ? WHERE Id % ? = 0')
  SQL.AddParam('2') ; SQL.AddParam('10')
  SQL.ExecPrepared()                              ! SQL.AffectedRows() = filas cambiadas
  SQL.AddParam('0.5') ; SQL.AddParam('10')
  SQL.ExecPrepared()                              ! misma sentencia, otros valores
""") + ul("SQL Server: <code>SQLPrepare</code> una vez, después solo viajan los valores (lo mismo que hace el driver de Clarion con <code>ADD</code>).",
          "MariaDB: MySQL 5.0 no tiene arreglos de parámetros; la sentencia se guarda y los <code>?</code> se reemplazan al ejecutar. "
          "Con un <code>INSERT ... VALUES</code>, <code>AddRow</code> arma un INSERT de varias filas."))

T["transacciones"] = ("Transacciones", code("""
  SQL.BeginTransaction()
  ... Exec / Insertar / InsertarLote ...
  IF error THEN SQL.Rollback() ELSE SQL.Commit().
""") + ul("Equivale a <code>LOGOUT</code> / <code>COMMIT</code> / <code>ROLLBACK</code> del driver de Clarion.",
          "SQL Server: con la API de ODBC (autocommit apagado hasta <code>Commit</code> / <code>Rollback</code>). Dentro de una "
          "transacción no se reconecta solo.",
          "MariaDB: la tabla tiene que ser <strong>InnoDB</strong> (en MyISAM no hay transacciones).",
          "Verificado: <code>BeginTransaction</code> + <code>DELETE</code> de 2.000 filas + <code>Rollback</code> deja las 2.000."))

T["migrar"] = ("Pasar un INSERT de PROP:SQL a Campo/Insertar", p("Hoy:") + code("""
  TemSQL{Prop:SQL} = 'INSERT INTO cbtes (IdTransaccion,IdEmpresa,IdSucursal,TipoCbte,...,IdFPagoOrig) ' &|
                     'VALUES ('&Loc:IdTransaccion&','&GLO:IdEmpresa&','&L:IdSucursal&',"'&Clip(Loc:TipoCbte)&'",' &|
                     ... Fun_Date(Loc:Fecha) ... '"'&Clip(Loc:RazonSocial)&'",' ... Fun_DateTime(glo:hoy,Clock()) ...
""") + p("Con la clase directa:") + code("""
  SQL.Campo('IdTransaccion',Loc:IdTransaccion)
  SQL.Campo('IdEmpresa',GLO:IdEmpresa)
  SQL.Campo('IdSucursal',L:IdSucursal)
  SQL.Campo('TipoCbte',Loc:TipoCbte)              ! sin "..." ni Clip
  SQL.Campo('Descripcion',Loc:RazonSocial)
  SQL.CampoFecha('Fecha',Loc:Fecha)               ! en vez de Fun_Date
  SQL.Campo('Ano',YEAR(Loc:Fecha))
  SQL.Campo('Saldo',-ABS(Loc:Deuda))
  SQL.CampoFechaHora('Aud_Fecha',glo:hoy,CLOCK()) ! en vez de Fun_DateTime
  ...
  IF SQL.Insertar('cbtes') THEN MESSAGE(SQL.ErrorText()).
""") + ul("Se lee columna por columna: no hay que contar comas para saber qué valor va en qué columna (en 90 columnas es donde se esconden los errores).",
          "Una <code>'</code> o una <code>\"</code> en la razón social no rompe nada.",
          "El servidor no vuelve a analizar el texto en cada fila (SQL Server: preparada; ver " + a("est-mssql-escritura", "escritura") + ").") +
    aviso("las <code>\"comillas dobles\"</code> para textos andan con el driver de Clarion porque conecta con "
          "<code>QUOTED_IDENTIFIER</code> apagado. Con el ODBC Driver 17/18 viene encendido y <code>\"texto\"</code> se toma como "
          "<strong>nombre de columna</strong>: ese <code>PROP:SQL</code> armado a mano falla con <code>SQLMsDirectClass</code>."))

# --- estadisticas
T["estadisticas"] = ("Estadísticas de velocidad", p(
    "Medidas el 28 y 29/10/2026 en una PC con los servidores locales: <strong>SQL Server 2022</strong> (base psnamen, tabla "
    "<code>dbo.Cbtes</code>, 101.798 filas) y <strong>MySQL 5.0.67</strong> (base gestion, tabla <code>cbtes</code>, ~500.000 filas). "
    "Misma consulta (9 columnas, <code>ORDER BY Fecha DESC, IdTransaccion DESC</code>) y misma carga a la cola en todos los motores; "
    "control de que todos traen las mismas filas y la misma suma de importes.") +
    table(["Resumen", "Directo", "Driver de Clarion"],
          ["SQL Server, leer 101.798 filas", "<strong>1,7 s</strong>", "26–30 s (SQLMsClass); 4,4 s (VIEW con <code>BUFFER(500)</code>)"],
          ["SQL Server, escribir (filas/s)", "<strong>~6.600</strong> (InsertarLote)", "~2.300 (<code>ADD</code>, con o sin <code>LOGOUT</code>)"],
          ["MySQL, leer 30.000 filas", "<strong>430 ms</strong>", "640 ms (SQLClass6 + ODBC 5.1)"],
          ["MySQL, escribir (filas/s)", "<strong>40.000</strong> (InsertarLote)", "401 (INSERT armado como texto)"]) +
    p("Detalle: " + a("est-mssql-lectura", "SQL Server: lectura") + ", " + a("est-mssql-escritura", "SQL Server: escritura") + ", " +
      a("est-maria", "MariaDB / MySQL") + ", " + a("est-paginas", "Páginas y conexión") + " y " + a("est-como", "Cómo se midió") + ".") +
    nota("los tiempos varían bastante entre corridas (una PC con otras cosas abiertas): miren las proporciones más que los milisegundos."))

T["est-mssql-lectura"] = ("SQL Server: lectura", table(
    ["Escenario", "Filas", "SQLMsClass (driver MSSQL)", "VIEW sin BUFFER", "VIEW con BUFFER(500)", "FILE+PROP:SQL con BUFFER(500)", "<strong>SQLMsDirectClass</strong>"],
    ["Toda la tabla", "101.798", "26,2 s", "27,4 s", "4,4 s", "5,1 s", "<strong>1,7 s</strong>"],
    ["Últimos 30.000", "30.000", "9,7 s", "4,3 s", "1,3 s", "1,4 s", "<strong>0,41–0,60 s</strong>"],
    ["Año 2025", "25.820", "16,8 s", "7,0 s", "1,0 s", "1,7 s", "<strong>0,47 s</strong>"],
    ["LIKE '%SRL%'", "893", "0,66 s", "1,7 s", "1,7 s", "0,18 s", "<strong>0,18–0,20 s</strong>"],
    ["Un cliente", "551", "394 ms", "80 ms", "20 ms", "26 ms", "<strong>16–40 ms</strong>"],
    ["Un comprobante", "1", "14,5 ms", "4,4 ms", "4,1 ms", "1,2 ms", "<strong>1,2–6 ms</strong>"]) +
    ul("El driver MSSQL de Clarion 11 se conecta con <strong>TDS 7.1</strong> (el driver <code>SQL Server</code> de Windows, de SQL Server 2000); "
       "el directo con TDS 7.4 (ODBC Driver 17).",
       "Sin <code>BUFFER</code> el driver espera al servidor fila por fila: 56 s de reloj con 15 s de CPU.",
       "<strong>Con <code>BUFFER(500)</code></strong> el driver queda 2 a 3 veces más lento que la clase directa (sin BUFFER, 15 a 50).",
       "<code>SQLMsClass</code> no puede aprovechar <code>BUFFER</code> sin cambiar SQLClass6: <code>ServerExecEx</code> hace "
       "<code>CLOSE</code> + <code>OPEN</code> de su archivo en cada consulta.",
       "Leer por bloques de 500 o de a una fila con el ODBC Driver 17 da casi lo mismo: el driver ya junta las filas por paquete de red."))

T["est-mssql-escritura"] = ("SQL Server: escritura", p("5.000 filas en <code>tempdb</code>, 3 corridas (filas por segundo):") +
    table(["Forma", "Corrida 1", "Corrida 2", "Corrida 3"],
          ["Driver MSSQL: <code>ADD</code> sin <code>LOGOUT</code>", "1.781", "2.110", "2.835"],
          ["Driver MSSQL: <code>LOGOUT</code> + <code>ADD</code> + <code>COMMIT</code>", "1.927", "2.841", "2.329"],
          ["SQLMsClass: un <code>INSERT</code> armado por fila", "1.526", "1.241", "1.190"],
          ["SQLMsDirectClass: un <code>INSERT</code> armado por fila", "1.422", "1.400", "1.381"],
          ["SQLMsDirectClass: <code>Insertar</code> (preparado)", "2.338", "1.940", "2.404"],
          ["<strong>SQLMsDirectClass: <code>InsertarLote</code></strong>", "<strong>5.746</strong>", "<strong>6.900</strong>", "<strong>7.325</strong>"]) +
    p("Pantalla <em>Ejemplos de uso</em>, 2.000 filas: INSERT como texto 627 filas/s, <code>Insertar</code> 6.250 (10×), "
      "<code>InsertarLote</code> 15.385 (24×).") +
    ul("Armar el <code>INSERT</code> como texto en cada fila es lo más lento: el servidor analiza el texto cada vez.",
       "<code>Insertar</code> rinde como el driver de Clarion con <code>ADD</code> (los dos preparan la sentencia).",
       "<code>InsertarLote</code>: unas 3 veces el driver de Clarion.",
       "En <code>tempdb</code> SQL Server no espera a grabar el log en cada confirmación: el efecto de <code>LOGOUT</code> / "
       "transacción en una base normal es mayor que el que se ve acá.") +
    aviso("la consulta de SQLClass6 tiene un límite de 20.480 caracteres (<code>Query CSTRING(20480)</code>): un INSERT de 500 filas "
          "armado a mano no entra. <code>InsertarLote</code> no tiene ese límite."))

T["est-maria"] = ("MariaDB / MySQL", h3("Lectura: SQLMariaClass contra SQLClass6 + ODBC 5.1") +
    table(["Escenario", "Filas", "Consulta", "MariaDB directo", "ODBC", "ODBC / Maria"],
          ["Sin filtro (últimas 30.000)", "30.000", "60 ms", "430 ms", "644 ms", "1,50"],
          ["Fecha: 1er semestre (índice)", "22.579", "46 ms", "326 ms", "494 ms", "1,52"],
          ["Tipo FC del año", "10.166", "1.180 ms", "1.310 ms", "1.384 ms", "1,06"],
          ["Razón social LIKE '%SRL%'", "17.716", "1.530 ms", "1.770 ms", "1.866 ms", "1,05"],
          ["Un cliente (índice)", "2.325", "10 ms", "40 ms", "54 ms", "1,35"],
          ["Mes actual", "460", "0–2 ms", "8 ms", "12 ms", "~1,5"]) +
    ul("La consulta tarda lo mismo con los dos (es el servidor); la diferencia está en traer las filas: el directo es ~1,5 veces más rápido por fila.",
       "ODBC perdió 4.045 caracteres de razón social en 30.000 filas (la tabla <code>sqlclass</code> corta a 49).",
       "<em>Tipo FC</em> tarda 1,2 s porque MySQL elige el índice <code>PorTipoCbte</code>: con <code>FORCE INDEX (PorFecha)</code> baja a 168 ms. "
       "El índice pesa mucho más que el motor.",
       "Con la barra de avance la carga tarda lo mismo (370 ms para 30.000 filas).") +
    h3("Escritura (2.000 filas, pantalla Ejemplos de uso)") +
    table(["Forma", "Filas/s"],
          ["<code>INSERT</code> armado como texto (como <code>PROP:SQL</code>)", "401"],
          ["<code>Insertar</code> (una fila por viaje)", "426"],
          ["<strong><code>InsertarLote</code></strong> (<code>INSERT</code> de 500 filas)", "<strong>40.000</strong> (100 veces)"]))

T["est-paginas"] = ("Páginas y conexión", h3("Carga por páginas") +
    table(["", "MySQL (gestion)", "SQL Server (psnamen)"],
          ["Primera página en pantalla", "<strong>10–20 ms</strong>", "220 ms"],
          ["5.069 filas en 37 páginas de 137", "160–200 ms", "3,6 s"],
          ["Las mismas filas de una vez", "80–90 ms", "420 ms"],
          ["Todo el filtro de una vez (hasta ver la 1ra fila)", "540–620 ms (33.764 filas)", "1,5 s (24.136 filas)"],
          ["Diferencias con una sola consulta", "0", "0"]) +
    ul("Con páginas la lista aparece unas 30 veces antes; traer todo por páginas cuesta ~2 veces más que de una (más viajes), repartido mientras el usuario baja.",
       "En SQL Server cada página tarda ~90 ms porque en psnamen ningún índice empieza por <code>(Fecha, IdTransaccion)</code>: "
       "el servidor ordena todo el filtro en cada página. Con ese índice bajaría a pocos ms.") +
    h3("Conexión") + ul("MySQL con <code>Server=localhost</code>: 1,8 s; con <code>127.0.0.1</code>: inmediato.",
                         "Con la barra asignada antes de <code>Init</code> se ve <em>Conectando al servidor...</em> y el tiempo."))

T["est-como"] = ("Cómo se midió", ul(
    "<code>tcwDriverMSSQL\\bench</code>: <code>BenchMSSQL.exe</code> con 10 motores de lectura (directo por bloques y fila por fila, "
    "SQLMsClass, driver MSSQL con <code>FILE</code>+<code>PROP:SQL</code> y <code>VIEW</code>, con y sin <code>BUFFER</code>, "
    "SQLMsDirectClass) y 8 formas de escritura. <code>build-bench.ps1 -Servidor -Base -Usuario -Clave -Run</code>; "
    "<code>bench.ini</code>: <code>Corridas</code>, <code>Motores</code>, <code>Escritura</code>.",
    "Tiempos con <code>QueryPerformanceCounter</code>; una corrida de calentamiento que no se cuenta; se rota qué motor va primero.",
    "Control en cada corrida: cantidad de filas y suma de importes iguales a las del primer motor.",
    "Escritura en <code>tempdb</code> (SQL Server) y en tablas <code>TEMPORARY</code> (MySQL): no se toca la base.",
    "MariaDB: pantalla <em>Comparar</em> de la demo (<code>TCWMariaDemo.exe comparar</code>) y <code>paginas</code> / <code>ejemplos</code>.",
    "La conexión queda solo en archivos <code>.ini</code> locales, fuera de git."))

# --- referencia
T["referencia"] = ("Referencia de métodos", table(
    ["Método", "Qué hace", "Diferencias"],
    [c("Init(archivo,registro,conexión)"), "como SQLClass6; el archivo se ignora", ""],
    [c("InitDirect(c)") + " / " + c("InitMaria(c)"), "conecta sin archivo de trabajo", ""],
    [c("Kill()"), "desconecta", ""],
    [c("Exec(q)") + ", " + c("ExecEx(q,1)"), "ejecuta (Exec pasa a minúsculas)", "<code>KeepCase = 1</code>: Exec no pasa a minúsculas"],
    [c("ExecSP(q)"), "procedimiento con resultado", "SQL Server: EXEC tal cual; MariaDB: EXEC → CALL"],
    [c("Next()") + ", " + c("Col(n)") + ", " + c("ColByName(n)") + ", " + c("IsNull(n)"), "leer", ""],
    [c("Columns()") + ", " + c("Field(n)") + ", " + c("Records()"), "estructura y cantidad (exacta)", ""],
    [c("Col_Format(n,pic)") + ", " + c("LoadQueue(Q,c,v)"), "cargar una cola", "<code>FreeQueue = 0</code>: agrega"],
    [c("Fetch(n,q)"), "primer valor", ""],
    [c("AddParam(v)") + ", " + c("AddNullParam()"), "parámetros <code>?</code> de la consulta siguiente", "MariaDB: reemplazo del lado del cliente"],
    [c("NextResult()"), "resultado siguiente", ""],
    [c("Prepare(q)") + ", " + c("ExecPrepared()") + ", " + c("AddRow()"), "sentencias preparadas y lotes", "MariaDB: lote = INSERT de varias filas"],
    [c("Campo") + ", " + c("CampoNulo") + ", " + c("CampoFecha") + ", " + c("CampoFechaHora"), "valores por nombre de columna", ""],
    [c("Insertar(t)") + ", " + c("InsertarLote(t)") + ", " + c("EnviarLote()"), "INSERT de una fila / de muchas", ""],
    [c("Escape(t)") + ", " + c("Quote(t)"), "escapa un texto / lo pone entre comillas", "SQL Server duplica <code>'</code>; MySQL también <code>\\</code>"],
    [c("InsertId()") + ", " + c("AffectedRows()"), "id generado / filas afectadas", ""],
    [c("ErrorText()") + ", " + c("ErrorCode()"), "último error", "SQL Server: 208 objeto inexistente, 2627 clave duplicada"],
    [c("ServerVersion()"), "versión del servidor", ""],
    [c("BeginTransaction()") + ", " + c("Commit()") + ", " + c("Rollback()"), "transacciones", "MariaDB: InnoDB"],
    [c("SetProgress(porc,texto)"), "mueve la barra / el texto de avance", ""]) +
    h("Propiedades") + table(["Propiedad", "Qué hace"],
                             [c("SilentMode"), "1 = sin mensajes; leer <code>ErrorText()</code>"],
                             [c("KeepCase"), "1 = Exec no pasa la consulta a minúsculas"],
                             [c("ProgressFeq") + ", " + c("ProgressTextFeq") + ", " + c("ProgressDelay"), "barra de avance en la ventana"],
                             [c("LogFile"), "nombre de archivo: anota cada SQL y su tiempo"],
                             [c("FreeQueue"), "0 = LoadQueue agrega a la cola"],
                             [c("MaxReads"), "límite de filas de LoadQueue"],
                             [c("Db"), "la conexión (<code>TCWMsSQL</code> / <code>TCWMariaDB</code>): " + a("ref-conexion", "ver")]))

T["ref-conexion"] = ("TCWMsSQL / TCWMariaDB (conexión)", p(
    "La conexión directa, que se puede usar sola. Propiedades útiles desde la SQLClass como <code>SQL.Db.xxx</code>:") +
    table(["Propiedad / método", "Qué hace"],
          [c("BatchSize"), "filas por envío de InsertarLote / AddRow (500; 0 = solo con EnviarLote)"],
          [c("MaxBatchBytes"), "MariaDB: tamaño máximo de un INSERT de varias filas (512 KB)"],
          [c("PendingRows()"), "filas del lote que faltan mandar"],
          [c("ClientVersion()"), "driver usado (SQL Server: <em>ODBC Driver 17 for SQL Server (msodbcsql17.dll 17.10)</em>)"],
          [c("IdentityAfterInsert"), "SQL Server: 1 = un INSERT por Exec deja el IDENTITY en InsertId"],
          [c("AutoReconnect"), "1 = si se cayó la conexión reconecta y reintenta una vez"],
          [c("Driver") + ", " + c("Encrypt") + ", " + c("ConnectTimeout"), "SQL Server: driver ODBC, cifrado, tiempo de conexión"],
          [c("Charset") + ", " + c("SSL") + ", " + c("Port"), "MariaDB"]) +
    p("SQL Server: el motor está en <code>tcwmss.c</code> (API de ODBC; <code>odbc32.dll</code> se carga en runtime, sin .lib). "
      "MariaDB: <code>libmariadb.dll</code> por su API pública."))

T["demo"] = ("Aplicaciones de ejemplo", table(
    ["Pantalla", "TCWMariaDemo (MySQL)", "TCWMsSQLDemo (SQL Server)"],
    ["Comprobantes directo, con barra de avance", "sí", "sí"],
    ["Por páginas (carga al bajar)", "sí", "sí"],
    ["El driver de Clarion (ODBC / MSSQL)", "SQLClass6 + ODBC 5.1", "SQLMsClass + driver MSSQL"],
    ["Comparar tiempos (8 escenarios, % más rápido, barra)", "sí", "sí (por defecto 5.000 filas, 2 corridas)"],
    ["Ejemplos de uso (7 pestañas)", "sí", "sí"]) +
    h("Ejemplos de uso") + table(["Pestaña", "Muestra"],
                                 ["1. Parámetros ?", "comprobantes de un cliente desde una fecha"],
                                 ["2. Insertar", "Campo / CampoFecha / CampoFechaHora / CampoNulo con <code>O'Brien \"el de las comillas\"</code>"],
                                 ["3. InsertarLote", "las mismas filas de tres formas, con barra; filas/s y veces más rápido"],
                                 ["4. Prepare", "un UPDATE preparado dos veces con otros valores"],
                                 ["5. Transacción", "BeginTransaction + DELETE + Rollback"],
                                 ["6. Varios resultados", "dos SELECT leídos con NextResult"],
                                 ["7. Texto largo", "20.000 caracteres grabados y leídos"]) +
    p("Cada pestaña muestra el código Clarion que ejecuta. Las escrituras van a <code>tempdb</code> (SQL Server) o a tablas "
      "<code>TEMPORARY</code> (MySQL): no se toca la base.") +
    h("Armar y probar") + code("""
  demo\\build-demo.ps1 -Conexion 'PC\\INSTANCIA,base,usuario,clave' -Run      (SQL Server)
  demo\\build-demo.ps1 -Conexion 'Server=127.0.0.1;Database=...;User=...;Password=...' -Run   (MariaDB)
  TCWMsSQLDemo.exe directo | paginas | comparar | ejemplos
  TCWMariaDemo.exe maria   | paginas | comparar | ejemplos
""") + p("<code>paginas</code>, <code>comparar</code> y <code>ejemplos</code> corren solos y dejan el resultado en "
         "<code>paginas.txt</code>, <code>comparacion.txt</code> y <code>ejemplos.txt</code>."))

T["trampas"] = ("Diferencias y trampas", table(
    ["Tema", "Qué pasa", "Qué hacer"],
    ["Comillas dobles", "SQL Server con ODBC 17/18 toma <code>\"texto\"</code> como nombre de columna", "<code>Campo</code> / parámetros, o comillas simples"],
    ["Misma columna dos veces", "SQL Server: <code>ORDER BY</code> por ella da el error 209 (ambigua)", "alias: <code>Fecha AS FechaSql</code>"],
    ["Un resultado pendiente", "SQL Server sin MARS: una sola sentencia activa por conexión", "la clase cierra el anterior sola"],
    ["Consulta de más de 20.480 caracteres", "SQLClass6 la corta (<code>Query CSTRING(20480)</code>)", "InsertarLote"],
    ["REAL en notación científica", "SQL Server no lo acepta para decimal", "DECIMAL"],
    ["<code>Exec</code> pasa a minúsculas", "también los valores entre comillas", "<code>ExecEx(q,1)</code>, <code>KeepCase</code> o parámetros"],
    ["Mayúsculas en nombres de tabla", "MySQL en Linux las distingue", "<code>KeepCase = 1</code>"],
    ["localhost", "MySQL 5.0: 1,8 s para conectar", "<code>127.0.0.1</code>"],
    ["Transacciones en MySQL", "MyISAM no las tiene", "InnoDB"],
    ["<code>BUFFER</code> con SQLMsClass", "se pierde: la clase cierra y abre su archivo en cada consulta", "SQLMsDirectClass, o cambiar SQLClass6"],
    ["Ventana mientras consulta", "no responde (la llamada bloquea)", "páginas; barra con texto"]))

T["pruebas"] = ("Pruebas", table(
    ["Prueba", "Qué cubre", "Resultado 29/10/2026"],
    ["<code>tcwDriverMSSQL\\build-test.ps1</code> (TestMsSQL)", "tabla y procedimiento <code>#temporales</code>: InsertId, parámetros con comillas y NULL, "
     "10.000 caracteres, fechas, transacción, dos resultados, procedimiento con conteos, <code>{CALL}</code>, GROUP BY, errores 208 y 2627, "
     "Prepare, Insertar con <code>'</code> y <code>\"</code>, lote de 1.235 filas, resultado pendiente", "TODO OK"],
    ["<code>tcwDriverMariaDB\\build-test.ps1</code> (TestMaria)", "tabla TEMPORARY: lo mismo, más barra invertida, <code>?</code> entre comillas, "
     "<code>UPDATE; SELECT</code>, texto de 20.000", "TODO OK"],
    ["<code>TCWxxxDemo.exe paginas</code>", "5.069 filas por páginas contra una sola consulta", "0 diferencias"],
    ["<code>TCWxxxDemo.exe ejemplos</code>", "las 7 pestañas de Ejemplos de uso", "todas bien"]) +
    p("Las pruebas no dejan nada en la base (tablas y procedimientos temporales)."))

# ------------------------------------------------------------------------------------------------ arbol
ARBOL = [
    ("introduccion", ["novedades"]),
    ("instalacion", ["conexion"]),
    ("guia", []),
    ("leer", ["parametros", "varios", "largos", "paginas", "avance"]),
    ("escribir", ["insertar", "lotes", "preparadas", "transacciones", "migrar"]),
    ("estadisticas", ["est-mssql-lectura", "est-mssql-escritura", "est-maria", "est-paginas", "est-como"]),
    ("referencia", ["ref-conexion"]),
    ("demo", []),
    ("trampas", []),
    ("pruebas", []),
]
CLAVES = {
    "parametros": ["AddParam", "AddNullParam", "?"], "varios": ["NextResult", "ExecSP", "CALL"],
    "insertar": ["Campo", "CampoFecha", "CampoFechaHora", "CampoNulo", "Insertar"], "lotes": ["InsertarLote", "EnviarLote", "BatchSize"],
    "preparadas": ["Prepare", "ExecPrepared", "AddRow"], "transacciones": ["BeginTransaction", "Commit", "Rollback", "LOGOUT"],
    "migrar": ["PROP:SQL", "QUOTED_IDENTIFIER"], "avance": ["ProgressFeq", "ProgressTextFeq"], "paginas": ["TOP", "LIMIT", "keyset"],
    "est-mssql-lectura": ["BUFFER", "VIEW"], "conexion": ["owner", "localhost"], "trampas": ["209", "MARS"],
}


def nodo(tid, hijos):
    titulo = T[tid][0]
    n = {"children": [nodo(x, []) for x in hijos], "file": f"topics/{tid}.html", "id": tid, "inToc": True, "title": titulo}
    if tid in CLAVES:
        n["keywords"] = CLAVES[tid]
    return n


TOPICS.mkdir(exist_ok=True)
for tid, (titulo, *partes) in T.items():
    (TOPICS / f"{tid}.html").write_text("".join(partes), encoding="utf-8")
proyecto = {
    "author": "Templates Clarion",
    "default": "introduccion",
    "lang": "es",
    "snippets": {},
    "subtitle": "SQLMariaClass y SQLMsDirectClass: la SQLClass directo a MariaDB / MySQL y SQL Server",
    "theme": "light",
    "title": "SQLClass directo",
    "topics": [nodo(t, h) for t, h in ARBOL],
    "variables": {},
    "version": "1.0",
}
usados = {t for t, h in ARBOL} | {x for _, h in ARBOL for x in h}
assert usados == set(T), set(T) ^ usados
(DIR / "proyecto.tcwhelp").write_text(json.dumps(proyecto, ensure_ascii=False, indent=2), encoding="utf-8")
print(len(T), "temas")

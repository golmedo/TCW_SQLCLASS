"""Genera la ayuda de SQLMariaClass / TCWMariaDB como proyecto HTML Help (para compilar a CHM).

python -I make-doc.py            -> doc\\html\\*.html + style.css + TCWMariaDB.hhp + toc.hhc + index.hhk
python -I ..\\..\\TCWChm\\html2chm.py html\\TCWMariaDB.hhp -o TCWMariaDB.chm

Los HTML salen en windows-1252 (lo que espera el visor de CHM). Todo el contenido esta en este archivo:
paginas conceptuales en PAGES y una pagina por metodo en METHODS / TCW_METHODS.
"""
import html
import re
from pathlib import Path

OUT = Path(__file__).resolve().parent / 'html'
TITLE = 'SQLMariaClass - la SQLClass directo a MariaDB / MySQL'

CSS = """\
body { font-family: Segoe UI, Tahoma, Arial, sans-serif; font-size: 10pt; color: #1f2933; background: #ffffff; margin: 0; }
.top { background: #0e5a8a; color: #ffffff; padding: 10px 16px 8px 16px; }
.top .crumb { font-size: 8.5pt; color: #cfe3f1; }
.top h1 { font-size: 15pt; margin: 2px 0 0 0; font-weight: 600; color: #ffffff; }
.content { padding: 6px 16px 24px 16px; max-width: 900px; }
h2 { font-size: 11.5pt; color: #0e5a8a; border-bottom: 1px solid #d5e3ec; padding-bottom: 2px; margin: 20px 0 8px 0; }
h3 { font-size: 10.5pt; color: #1f2933; margin: 16px 0 6px 0; }
p { margin: 6px 0 8px 0; line-height: 1.45; }
ul, ol { margin: 4px 0 8px 22px; padding: 0; }
li { margin: 2px 0; line-height: 1.4; }
code { font-family: Consolas, Courier New, monospace; font-size: 9.5pt; background: #f1f5f8; padding: 0 3px; }
pre.code { font-family: Consolas, Courier New, monospace; font-size: 9.5pt; background: #f6f8fa; border: 1px solid #dde4ea;
           border-left: 3px solid #0e5a8a; padding: 8px 10px; margin: 6px 0 10px 0; overflow: auto; line-height: 1.35; }
pre.code .k { color: #00008b; font-weight: bold; }
pre.code .s { color: #a31515; }
pre.code .c { color: #2e7d32; }
pre.sig { font-family: Consolas, Courier New, monospace; font-size: 10pt; background: #eef4f8; border: 1px solid #cfdde7;
          padding: 6px 10px; margin: 6px 0 10px 0; }
table { border-collapse: collapse; margin: 6px 0 12px 0; }
th { background: #e8f0f5; text-align: left; font-weight: 600; border: 1px solid #cfdde7; padding: 4px 8px; }
td { border: 1px solid #dde4ea; padding: 4px 8px; vertical-align: top; }
td.n { text-align: right; }
.nota { background: #fff8e1; border: 1px solid #f0d58c; padding: 6px 10px; margin: 8px 0 10px 0; }
.ok { background: #edf7ee; border: 1px solid #b9dfbd; padding: 6px 10px; margin: 8px 0 10px 0; }
.dif { background: #eef4f8; border: 1px solid #cfdde7; padding: 6px 10px; margin: 8px 0 10px 0; }
.tag { display: inline; font-size: 8pt; background: #0e5a8a; color: #ffffff; padding: 0 5px; margin-left: 6px; }
.tag.nuevo { background: #2e7d32; }
.vt a { margin-right: 10px; }
.pie { font-size: 8pt; color: #7b8794; border-top: 1px solid #e4e7eb; margin-top: 24px; padding-top: 6px; }
"""

KEYWORDS = set('''IF THEN ELSE ELSIF END LOOP UNTIL WHILE TO BY BREAK CYCLE RETURN CODE CASE OF OROF PROCEDURE CLASS
QUEUE EXIT DO ROUTINE DATA INCLUDE ONCE NEW DISPOSE SELF PARENT AND OR NOT FREE ADD GET PUT CLIP LEN FORMAT
MESSAGE STOP DISPLAY SETCURSOR CLOCK GETINI LONGPATH RECORDS DEFORMAT CHOOSE MEMBER MAP TRUE FALSE'''.split())


def hl(code):
    """Resalta codigo Clarion: cadenas, comentarios (! fuera de cadenas) y palabras clave."""
    out = []
    for line in code.rstrip('\n').split('\n'):
        i, n, buf = 0, len(line), []
        while i < n:
            ch = line[i]
            if ch == "'":
                j = i + 1
                while j < n:
                    if line[j] == "'":
                        if j + 1 < n and line[j + 1] == "'":
                            j += 2
                            continue
                        break
                    j += 1
                buf.append('<span class="s">' + html.escape(line[i:j + 1]) + '</span>')
                i = j + 1
            elif ch == '!':
                buf.append('<span class="c">' + html.escape(line[i:]) + '</span>')
                break
            elif ch.isalpha() or ch == '_':
                j = i
                while j < n and (line[j].isalnum() or line[j] in '_:'):
                    j += 1
                w = line[i:j]
                buf.append(f'<span class="k">{w}</span>' if w.upper() in KEYWORDS and w.isupper() else html.escape(w))
                i = j
            else:
                buf.append(html.escape(ch))
                i += 1
        out.append(''.join(buf))
    return '<pre class="code">' + '\n'.join(out) + '</pre>'


def md(text):
    """Mini formato para los textos: `codigo`, **negrita**, [[pagina|texto]] y parrafos/listas/notas.

    Bloques separados por linea en blanco. Un bloque que empieza con '- ' es lista; con '1. ' lista numerada;
    con 'NOTA:' / 'OK:' / 'DIF:' recuadro; con '```' codigo Clarion; con '|' tabla (primera fila = titulos).
    """
    def inline(s):
        out = []
        for i, part in enumerate(re.split(r'(`[^`]+`)', s)):      # impares = `codigo` (sin negrita ni cursiva)
            if i % 2:
                out.append('<code>' + html.escape(part[1:-1], quote=False) + '</code>')
                continue
            part = html.escape(part, quote=False)
            part = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', part)
            part = re.sub(r'(?<![\w*])\*([^*\s][^*]*?)\*(?![\w*])', r'<i>\1</i>', part)
            part = re.sub(r'\[\[([^|\]]+)\|([^\]]+)\]\]', r'<a href="\1.html">\2</a>', part)
            out.append(part)
        return ''.join(out)

    parts, blocks, cur, in_code = [], [], [], False
    for line in text.strip('\n').split('\n'):
        if line.strip().startswith('```'):
            if in_code:
                blocks.append(('code', '\n'.join(cur)))
                cur, in_code = [], False
            else:
                if cur:
                    blocks.append(('txt', '\n'.join(cur)))
                cur, in_code = [], True
            continue
        if in_code:
            cur.append(line)
        elif line.strip() == '':
            if cur:
                blocks.append(('txt', '\n'.join(cur)))
            cur = []
        else:
            cur.append(line)
    if cur:
        blocks.append(('txt', '\n'.join(cur)))

    for kind, b in blocks:
        if kind == 'code':
            parts.append(hl(b))
            continue
        lines = [x.strip() for x in b.split('\n')]
        first = lines[0]
        if first.startswith('## '):
            parts.append(f'<h2>{inline(first[3:])}</h2>')
            if len(lines) > 1:
                parts.append(md('\n'.join(lines[1:])))
        elif first.startswith('### '):
            parts.append(f'<h3>{inline(first[4:])}</h3>')
            if len(lines) > 1:
                parts.append(md('\n'.join(lines[1:])))
        elif first.startswith('- '):
            items, acc = [], None
            for x in lines:
                if x.startswith('- '):
                    if acc is not None:
                        items.append(acc)
                    acc = x[2:]
                else:
                    acc += ' ' + x
            items.append(acc)
            parts.append('<ul>' + ''.join(f'<li>{inline(i)}</li>' for i in items) + '</ul>')
        elif re.match(r'\d+\. ', first):
            items, acc = [], None
            for x in lines:
                m = re.match(r'\d+\. (.*)', x)
                if m:
                    if acc is not None:
                        items.append(acc)
                    acc = m.group(1)
                else:
                    acc += ' ' + x
            items.append(acc)
            parts.append('<ol>' + ''.join(f'<li>{inline(i)}</li>' for i in items) + '</ol>')
        elif first.startswith('|'):
            rows = [[c.strip() for c in re.split(r'\|(?![^\[]*\]\])', x.strip('|'))] for x in lines]   # sin cortar [[a|b]]
            h = ''.join(f'<th>{inline(c)}</th>' for c in rows[0])
            body = ''
            for r in rows[1:]:
                body += '<tr>' + ''.join(
                    f'<td class="n">{inline(c)}</td>' if re.fullmatch(r'[\d.,~\- x%]+', c) and c else f'<td>{inline(c)}</td>'
                    for c in r) + '</tr>'
            parts.append(f'<table><tr>{h}</tr>{body}</table>')
        else:
            cls = None
            for pre, c in (('NOTA:', 'nota'), ('OK:', 'ok'), ('DIF:', 'dif')):
                if first.startswith(pre):
                    cls = c
                    lines[0] = first[len(pre):].strip()
            p = inline(' '.join(lines))
            parts.append(f'<div class="{cls}">{p}</div>' if cls else f'<p>{p}</p>')
    return '\n'.join(parts)


def page(fname, title, crumb, body, see=None):
    vt = ''
    if see:
        links = ' '.join(f'<a href="{f}.html">{html.escape(t)}</a>' for f, t in see)
        vt = f'<h2>Ver también</h2><p class="vt">{links}</p>'
    doc = f"""<!DOCTYPE html>
<html lang="es"><head>
<meta http-equiv="Content-Type" content="text/html; charset=windows-1252">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<title>{html.escape(title)}</title>
<link rel="stylesheet" href="style.css">
</head><body>
<div class="top"><div class="crumb">{html.escape(crumb)}</div><h1>{html.escape(title)}</h1></div>
<div class="content">
{body}
{vt}
<div class="pie">tcwDriverMariaDB - Templates Clarion - documentación generada el 28/10/2026</div>
</div></body></html>
"""
    (OUT / f'{fname}.html').write_bytes(doc.encode('cp1252', errors='xmlcharrefreplace'))


# =============================================================================================== páginas
PAGES = {}

PAGES['index'] = ('SQLMariaClass', 'Inicio', """
`SQLMariaClass` es la **SQLClass de siempre** (SQLClass6: `Exec`, `Next`, `Col`, `LoadQueue`...) yendo **directo a
MariaDB o MySQL**, sin ODBC, sin driver de archivos de Clarion y sin tabla de trabajo. Usa `libmariadb.dll`
(MariaDB Connector/C, API pública, licencia LGPL).

El código que hoy se escribe con la SQLClass sirve igual: mismos métodos, mismas firmas y mismos códigos de
retorno. Para pasar un procedimiento a MariaDB directo alcanza con usar un objeto `SQLMariaClass` en lugar de
`SQLMsClass` / `SQLOdbcClass`.

## Cómo está armado
|Capa|Qué hace|
|`SQLMariaClass` (SQLClass6Maria.inc/.clw)|Hereda de `SQLOdbcClass` y reimplementa sus métodos. Es lo que usa la aplicación.|
|`TCWMariaDB` (TCWMariaDB.inc/.clw)|Conexión directa: conecta, ejecuta, recorre filas, escapa textos. Se puede usar sola.|
|`libmariadb.dll`|MariaDB Connector/C 3.4.9 (32 bits). Va junto al .exe.|
|Template `SQLClass` (sqlclass6.tpl)|Opción **Motor** por objeto: *Driver de la app* o *MariaDB directo*.|

## Por qué usarla
- **Más rápida para traer filas**: 30.000 comprobantes en 430 ms contra 636 ms por ODBC (ver [[rendimiento|Rendimiento]]).
- **Sin límites de la tabla de trabajo**: no hay máximo de columnas ni de largo por valor (por ODBC la razón social de 70 caracteres llegaba cortada a 49).
- **Sin configurar ODBC** en cada PC: alcanza con `libmariadb.dll` junto al programa.
- **Más información**: `Records()` exacto, nombre real de cada columna, `InsertId()`, `AffectedRows()`, `ErrorText()`, transacciones.

## Por dónde empezar
1. [[instalacion|Instalación y requisitos]]
2. [[primeros-pasos|Primeros pasos]]: el ejemplo mínimo.
3. [[template|Template SQLClass]]: agregar un objeto con Motor = MariaDB directo.
4. [[ej-comprobantes|Ejemplo: pantalla de comprobantes con filtros]] (la app de ejemplo).
5. [[sqlmariaclass|Referencia de SQLMariaClass]].
""", [('instalacion', 'Instalación'), ('primeros-pasos', 'Primeros pasos'), ('sqlmariaclass', 'SQLMariaClass')])

PAGES['instalacion'] = ('Instalación y requisitos', 'Guía', """
## Archivos
|Archivo|Dónde va|
|`SQLClass6Maria.inc`, `SQLClass6Maria.clw`|`accessory\\libsrc\\win`|
|`TCWMariaDB.inc`, `TCWMariaDB.clw`|`accessory\\libsrc\\win`|
|`libmariadb.lib`|`accessory\\lib` (se agrega a las *Libraries* del proyecto)|
|`libmariadb.dll`|`accessory\\bin` y **junto al .exe** al distribuir|
|`sqlclass6.tpl` (con la opción Motor)|`accessory\\template\\win` (respaldar el original antes)|

## Requisitos
- **SQLClass6 extendida** (octubre de 2026: `ExecEx`, `ExecSP`, `LogFile`, `ShowProgress`, `WriteLog`). `SQLMariaClass` hereda de ella. Con la SQLClass6 original de 2011 **no compila**.
- **StringTheory**: la usa la SQLClass6 extendida para el log. Es opcional desde el 28/10/2026: en el template, destildar *Usar StringTheory* (ver [[template|Template SQLClass]]).
- **Clarion 11 o superior**, aplicación de 32 bits (la DLL es de 32 bits).
- **Servidor**: MySQL 5.0 o superior, o cualquier MariaDB. Probado con MySQL 5.0.67.

## Proyecto
- Con el template, `libmariadb.lib` y el `INCLUDE('SQLClass6Maria.inc')` se agregan solos cuando algún objeto tiene Motor = *MariaDB directo*.
- Sin el template: agregar `libmariadb.lib` a *Libraries* e incluir `SQLClass6Maria.inc` en *Global Includes* (incluye a su vez `SQLClass6.INC` y `TCWMariaDB.inc`).
- Los fuentes se compilan como parte de la aplicación (`LINK('SQLClass6Maria.clw')` y `LINK('TCWMariaDB.clw')`): no hay DLL de la clase.

NOTA: Si el programa no encuentra `libmariadb.dll` no arranca (Windows avisa que falta la DLL). Distribuirla en la misma carpeta que el .exe.

## Seguridad de la conexión
La cadena de conexión tiene usuario y clave: guardarla en un INI o en la configuración de la aplicación, **no en el
código**. Los ejemplos de esta ayuda la leen con `GETINI('Conexion','Cadena',...)`.
""", [('conexion', 'Cadena de conexión'), ('template', 'Template SQLClass'), ('problemas', 'Problemas frecuentes')])

PAGES['conexion'] = ('Cadena de conexión', 'Guía', """
La cadena va en `Init(...)`, `InitMaria(...)` o `Db.Connect(...)`. Son pares `clave=valor` separados por `;`.
Las mayúsculas en las claves no importan.

|Clave (y sinónimos)|Valor|Por defecto|
|`Server` (`Host`, `Data Source`, `Address`)|nombre o IP del servidor|`127.0.0.1`|
|`Port`|puerto|`3306`|
|`Database` (`Db`, `Initial Catalog`)|base de datos|ninguna|
|`User` (`Uid`, `User Id`, `Username`)|usuario| |
|`Password` (`Pwd`)|clave| |
|`Charset` (`Character Set`)|juego de caracteres de la conexión|`latin1`|
|`Timeout` (`Connect Timeout`, `Connection Timeout`)|segundos para conectar|`10`|
|`SSL` (`SslMode`, `Ssl Mode`)|`1`, `TRUE`, `REQUIRED`, `VERIFY_CA` o `VERIFY_FULL` exige TLS y verifica el certificado|`0`|

```
Server=192.168.0.10;Port=3306;Database=gestion;User=app;Password=****
```

## La cadena de ODBC también sirve
Las claves que no conoce se ignoran, así que la cadena que hoy usa la aplicación con el driver ODBC funciona tal cual:

```
DRIVER={MySQL ODBC 5.1 Driver};SERVER=192.168.0.10;DATABASE=gestion;UID=app;PWD=****;OPTION=3
```

Por eso, al pasar un objeto a *MariaDB directo* desde el template, el `Init(archivo, registro, cadena)` existente no se toca.

## Charset latin1
Con `latin1` (el valor por defecto) los textos viajan sin conversión entre Clarion (ANSI / windows-1252) y el
servidor: acentos y eñes llegan bien. Cambiarlo solo si la base usa otro juego de caracteres y se convierte a mano.

## TLS (SSL)
Connector/C 3.4 exige TLS de fábrica, y los servidores viejos (MySQL 5.0) no lo tienen. Por eso, con `SSL=0` (por
defecto) la clase usa TLS solo si el servidor lo ofrece, sin exigirlo. Con `SSL=1` lo exige y verifica el certificado.

## Leer la cadena del INI
```
L:Conn      CSTRING(1024)
  CODE
  L:Conn = GETINI('Conexion','Cadena','',LONGPATH() & '\\MiApp.ini')
  IF SQLM.InitMaria(L:Conn) THEN MESSAGE(SQLM.ErrorText()); RETURN.
```
""", [('m-init', 'Init'), ('m-initmaria', 'InitMaria'), ('tcwmariadb', 'TCWMariaDB')])

PAGES['primeros-pasos'] = ('Primeros pasos', 'Guía', """
## El ejemplo mínimo
Conectar, consultar, recorrer las filas y cerrar:

```
  INCLUDE('SQLClass6Maria.inc'),ONCE        ! Global Includes (con el template se agrega solo)

SQLM        SQLMariaClass
L:Conn      CSTRING(1024)
L:Total     DECIMAL(19,2)

  CODE
  L:Conn = GETINI('Conexion','Cadena','',LONGPATH() & '\\MiApp.ini')
  SQLM.SilentMode = True                    ! los errores se informan con ErrorText(), sin STOP
  IF SQLM.InitMaria(L:Conn)
    MESSAGE('No se pudo conectar: ' & SQLM.ErrorText())
    RETURN
  END
  SQLM.KeepCase = True                      ! Exec envía la consulta tal cual (sin pasar a minúsculas)
  IF SQLM.Exec('SELECT IdTransaccion, Descripcion, ImporteTotal FROM cbtes WHERE Fecha >= ''2026-01-01''') = Level:Benign
    LOOP UNTIL SQLM.Next()                  ! Next() devuelve 0 mientras trae filas
      L:Total += SQLM.Col(3)
    END
    MESSAGE(SQLM.Records() & ' comprobantes, total ' & FORMAT(L:Total,@n-20.2))
  ELSE
    MESSAGE('Error: ' & SQLM.ErrorText())
  END
  SQLM.Kill()
```

## Lo que hay que saber
- **Códigos de retorno**: como en la SQLClass, `Level:Benign` (0) es *bien* y `Level:Notify` (1) es *error*. Por eso se escribe `IF SQLM.Exec(...)` para detectar el error, y `LOOP UNTIL SQLM.Next()` para recorrer.
- **Minúsculas**: `Exec` pasa toda la consulta a minúsculas (igual que la SQLClass), *incluidos los valores entre comillas*. Usar `KeepCase = True` o `ExecEx(consulta, 1)`. Ver [[m-exec|Exec]].
- **Un resultado por objeto**: cada `Exec` reemplaza el resultado anterior. Para leer dos consultas a la vez, usar dos objetos.
- **Columnas por posición o por nombre**: `Col(2)` o `ColByName('Descripcion')`.
- **Errores**: con `SilentMode = False` (por defecto) la clase muestra el error con `STOP`. Con `SilentMode = True` no muestra nada y el texto queda en `ErrorText()`.

## Siguiente paso
- Cargar un LIST: [[m-loadqueue|LoadQueue]] y el [[ej-comprobantes|ejemplo de comprobantes]].
- Grabar datos: [[ej-grabar|Insertar, actualizar y transacciones]].
""", [('sqlmariaclass', 'SQLMariaClass'), ('ej-comprobantes', 'Ejemplo de comprobantes'), ('m-next', 'Next')])

PAGES['template'] = ('Template SQLClass (Motor MariaDB)', 'Guía', """
El template global **SQLClass** ("Utilizacion de SQL class para Clarion6", `sqlclass6.tpl`) declara los objetos SQL
de la aplicación. Esta versión agrega dos opciones; todo lo demás queda como estaba.

## Opción Motor (por objeto)
En las extensiones globales de la aplicación, **SQLClass > Objetos SQL Globales**, cada objeto tiene ahora:

|Prompt|Valores|
|Motor|`Driver de la app` (como hasta ahora: SQLOdbcClass / SQLMsClass / SQLIfxClass / SQLOraClass según la base elegida) o `MariaDB directo`|

Un objeto con **MariaDB directo** (por ejemplo `SQLM`) se genera así:

```
SQLM                 &SQLMariaClass
Hide:SQLM            CLASS(SQLMariaClass)
```

Los embeds de métodos del objeto funcionan igual (con su llamada a `PARENT`). Si al menos un objeto usa MariaDB,
el template agrega también `INCLUDE('SQLClass6Maria.inc')` y `libmariadb.lib` al proyecto.

### Pasar a MariaDB de a poco
1. Dejar el objeto `SQL` como está (Motor = *Driver de la app*).
2. Agregar un objeto `SQLM` con Motor = *MariaDB directo*.
3. Inicializarlo con la misma cadena: `SQLM.Init(sqlclass,uSQL:Record,GLO:Conexion)`.
4. En cada procedimiento que se quiera pasar, cambiar `SQL.` por `SQLM.`.
5. En los procedimientos con **TCW_Display**, poner `SQLM` en *Instancia SQLClass*.

Los dos objetos conviven en la misma aplicación. Así se compara el resultado antes de cambiar todo.

NOTA: TCW_Display llama a `Exec`, que pasa la consulta a minúsculas. Si la base está en Linux (los nombres de tabla distinguen mayúsculas), poner `SQLM.KeepCase = True` después del `Init`.

## Opción Usar StringTheory
En **Configuración**, el check **Usar StringTheory (log de la SQLClass)** viene tildado. Destildado, el template agrega
`SQLClass6SinStringTheory=>1` al proyecto: la SQLClass6 no incluye StringTheory y `WriteLog` escribe el log con
la API de Windows (mismo formato). Sirve para aplicaciones que no usan StringTheory.

## Aplicaciones existentes
Una aplicación que no usa *MariaDB directo* y deja tildado *Usar StringTheory* genera **exactamente el mismo código**
que con el template original (verificado archivo por archivo).

## Ejemplo: los dos motores con el mismo código
```
  SQL.SilentMode  = True
  SQLM.SilentMode = True
  IF SQL.Init(sqlclass,uSQL:Record,L:Conn) = Level:Benign       ! driver de la app (ODBC)
    IF SQL.Exec('SELECT COUNT(*) FROM cbtes WHERE Fecha >= ''2026-01-01''') = Level:Benign AND SQL.Next() = Level:Benign
      MESSAGE('ODBC: ' & SQL.Col(1))
    END
  END
  IF SQLM.Init(sqlclass,uSQL:Record,L:Conn) = Level:Benign      ! MariaDB directo, misma cadena
    IF SQLM.Exec('SELECT COUNT(*) FROM cbtes WHERE Fecha >= ''2026-01-01''') = Level:Benign AND SQLM.Next() = Level:Benign
      MESSAGE('MariaDB: ' & SQLM.Col(1) & ' - servidor ' & SQLM.ServerVersion())
    END
  END
```
""", [('instalacion', 'Instalación'), ('conexion', 'Cadena de conexión'), ('m-exec', 'Exec')])

PAGES['diferencias'] = ('Diferencias con SQLClass6 (driver)', 'Guía', """
`SQLMariaClass` respeta el comportamiento de la SQLClass6. Estas son las diferencias, todas a favor salvo que se indique.

|Tema|SQLClass6 con driver|SQLMariaClass|
|Tabla de trabajo|Necesita la tabla `sqlclass` (N campos de M caracteres)|No usa archivo; `Init` recibe el archivo solo por compatibilidad|
|Columnas y largo|Limitados por el registro (por ejemplo 25 campos de 49)|Sin límite|
|`Col(n)`|Campo n del registro|Valor que mandó el servidor; `''` si es NULL|
|`Columns()` / `Field(n)`|Lo que dedujo el parser del SELECT|Cantidad y nombres reales que manda el servidor|
|`Records()`|Hace un `SELECT COUNT(*)` aparte|Cuenta el resultado ya leído (exacto con GROUP BY / DISTINCT)|
|Procedimientos almacenados|`ExecSP` convierte `EXEC` en `CALL`|Igual, y descarta el resultado extra del CALL|
|Sentencias aceptadas por `Parse`|SELECT, INSERT, UPDATE, DELETE, CREATE...|Además SHOW, DESCRIBE, EXPLAIN, REPLACE, USE, WITH, LOCK..., y SELECT sin FROM|
|Conexión caída|Error|Reconecta y reintenta una vez (errores 2006 / 2013)|
|`LoadQueue` con ventana|Porcentaje invertido|Porcentaje correcto|
|Nuevos|-|`InitMaria`, `ColByName`, `IsNull`, `Escape`, `Quote`, `InsertId`, `AffectedRows`, `ErrorText`, `ErrorCode`, `ServerVersion`, `BeginTransaction`, `Commit`, `Rollback`, `KeepCase`, `Db`|

## Lo que se mantiene igual (a propósito)
- `Exec` pasa la consulta a minúsculas (salvo `KeepCase`).
- Códigos de retorno: 0 = bien, 1 = error; `Next()` devuelve 0 cuando trajo una fila.
- `SilentMode`, `Debug` / `Debug_Limit` (aviso de consulta lenta), `MaxReads`, `FreeQueue`, `LogFile`, `ShowProgress`.
- Embeds de métodos y métodos virtuales (`TakeRecord`, `TakeSelect`...).

DIF: Los métodos de la SQLClass6 no son VIRTUAL (salvo `Init` y los `Take*`). Por eso el objeto tiene que ser de tipo `SQLMariaClass`: una referencia `&SQLMsClass` que apunte a un `SQLMariaClass` llamaría al código del driver.
""", [('rendimiento', 'Rendimiento'), ('sqlmariaclass', 'SQLMariaClass')])

PAGES['rendimiento'] = ('Rendimiento', 'Guía', """
Medido el 28/10/2026 con la aplicación de ejemplo, MySQL 5.0.67 local, tabla `cbtes` (503.952 filas), 9 columnas,
`ExecEx` + `Col_Format` + `LoadQueue`. ODBC = SQLClass6 + driver ODBC de Clarion + MySQL ODBC 5.1.

## Sin filtro: 30.000 filas
|Motor|Consulta|Carga a la cola|Total|
|SQLMariaClass directo|60 ms|370 ms|**430 ms**|
|SQLClass6 + ODBC|60 ms|576 ms|**636 ms**|

Las dos traen las mismas filas y el mismo total de importes, pero por ODBC **4.045 razones sociales llegaron
cortadas** a 49 caracteres (el campo de la tabla de trabajo); por MariaDB llegan completas (hasta 70).

## Con filtros (promedio de 5 corridas, después de una de calentamiento; total en ms)
|Escenario|Filas|Consulta|MariaDB|ODBC|ODBC / MariaDB|
|Sin filtro (últimas 30.000)|30.000|60|430|644|1,50|
|Fecha: 1er semestre (índice)|22.579|46|326|494|1,52|
|Tipo FC del año|10.166|1.180|1.310|1.384|1,06|
|Razón social LIKE %SRL%|17.716|1.530|1.770|1.866|1,05|
|Razón social LIKE %GARCIA%|3.848|1.490|1.532|1.576|1,03|
|Un cliente (índice)|2.325|10|40|54|1,35|
|Mes actual|460|0-2|8|12|~1,5|
|Un comprobante por Id|1|0-2|2|2|-|

## Conclusiones
- **La consulta tarda lo mismo** con los dos motores: ese trabajo lo hace el servidor.
- **MariaDB directo trae las filas ~1,5 veces más rápido.** Cuantas más filas, más se nota.
- Cuando el servidor tarda (un `LIKE '%texto%'` recorre toda la tabla), la diferencia queda en 3-6 %.
- **El índice pesa más que el motor**: *Tipo FC del año* tarda 1,2 s porque MySQL elige el índice `PorTipoCbte` y ordena 46.200 filas; con `FORCE INDEX (PorFecha)` baja a 168 ms.
""", [('diferencias', 'Diferencias con SQLClass6'), ('ej-comparar', 'Ejemplo: comparar motores')])

PAGES['problemas'] = ('Problemas frecuentes', 'Guía', """
### No conecta: "TLS/SSL error" o "SSL connection is required"
El servidor no tiene TLS (MySQL 5.0, por ejemplo). Con `SSL=0` (el valor por defecto) no se exige. Si la cadena
tiene `SSL=1` o `SslMode=REQUIRED`, quitarlo.

### Falta libmariadb.dll al ejecutar
Copiar `libmariadb.dll` (32 bits) junto al .exe.

### Error de compilación: "ExecEx / LogFile / WriteLog no definido"
La SQLClass6 instalada es la original de 2011. `SQLMariaClass` necesita la SQLClass6 extendida (ver [[instalacion|Instalación]]).

### Unresolved external mysql_...
Falta `libmariadb.lib` en las *Libraries* del proyecto (con el template se agrega sola si algún objeto usa *MariaDB directo*).

### "Table 'base.Clientes' doesn't exist" pero la tabla existe
En Linux los nombres de tabla distinguen mayúsculas y `Exec` pasa la consulta a minúsculas. Usar `KeepCase = True` o `ExecEx(consulta, 1)`.

### Los textos que grabo quedan en minúsculas
Mismo motivo: `Exec` pasa a minúsculas toda la consulta, incluidos los valores entre comillas. Para INSERT y UPDATE usar `KeepCase = True` o `ExecEx(consulta, 1)`.

### Leo dos consultas a la vez y la primera "se corta"
Cada objeto tiene un resultado por vez: un `Exec` dentro del `LOOP` de otro `Exec` sobre el mismo objeto reemplaza el resultado. Usar un segundo objeto.

### Acentos o eñes mal
La conexión tiene que usar `Charset=latin1` (el valor por defecto). Si la base está en `utf8`, el servidor convierte a latin1 al enviar.

### La primera consulta tarda más
El servidor tiene que leer los datos del disco la primera vez. Para medir tiempos, descartar la primera corrida (ver [[ej-comparar|Comparar motores]]).

### Fecha vacía en la cola
Las fechas llegan como texto `aaaa-mm-dd`. Antes de `LoadQueue` indicar `Col_Format(n,'@d10-')` para esa columna (ver [[m-col-format|Col_Format]]).
""", [('instalacion', 'Instalación'), ('conexion', 'Cadena de conexión')])

# ------------------------------------------------------------------------------------------- ejemplos
PAGES['ej-comprobantes'] = ('Ejemplo: comprobantes con filtros', 'Ejemplos', """
Es la pantalla **Comprobantes > MariaDB directo** de la aplicación de ejemplo (`demo\\TCWMariaDemo`). Una ventana con
filtros (fecha desde / hasta, tipo, texto de la razón social, máximo de filas), un LIST y una línea de estado con
cantidad, tiempos, total y versión del servidor.

## Datos
```
SQL                  SQLMariaClass
CbtesQ               QUEUE,PRE(CBQ)                 ! una columna de la cola por cada columna del SELECT, en orden
IdTransaccion          LONG
Fecha                  LONG
TipoCbte               STRING(3)
Letra                  STRING(1)
NroCbte                LONG
IdCliente              LONG
Cliente                STRING(70)
Total                  DECIMAL(17,2)
Saldo                  DECIMAL(12,2)
                     END
L:Desde              LONG
L:Hasta              LONG
L:Tipo               STRING(3)
L:Texto              STRING(40)
L:Max                LONG(30000)
L:Estado             STRING(250)
L:Query              CSTRING(4000)
L:Conn               CSTRING(1024)
L:T0                 LONG
L:T1                 LONG
L:T2                 LONG
L:Ok                 BYTE
```

## Al abrir la ventana (OpenWindow)
```
  L:Desde = DATE(1,1,YEAR(TODAY()))
  L:Hasta = TODAY()
  L:Conn = GETINI('Conexion','Cadena','',LONGPATH() & '\\TCWMariaDemo.ini')
  IF L:Conn = ''
    L:Estado = 'Falta la cadena de conexion en TCWMariaDemo.ini ([Conexion] Cadena=...)'
  ELSE
    SQL.SilentMode = True
    IF SQL.InitMaria(L:Conn)
      L:Estado = 'No se pudo conectar: ' & SQL.ErrorText()
    ELSE
      SQL.KeepCase = True
      L:Ok = True
    END
  END
  DISPLAY()
  IF L:Ok THEN DO Buscar.
```

## Botón Buscar
`Quote()` escapa y pone entre comillas lo que escribió el usuario: no hace falta duplicar comillas a mano.

```
Buscar ROUTINE
  IF NOT L:Ok THEN EXIT.
  L:Query = 'SELECT IdTransaccion, Fecha, TipoCbte, Letra_Cbte, NroCbte, IdCliente, Descripcion, ImporteTotal, Saldo' & |
            ' FROM cbtes WHERE Fecha BETWEEN ''' & FORMAT(L:Desde,@d10-) & ''' AND ''' & FORMAT(L:Hasta,@d10-) & ''''
  IF L:Tipo <> '' THEN L:Query = L:Query & ' AND TipoCbte = ' & SQL.Quote(CLIP(L:Tipo)).
  IF L:Texto <> '' THEN L:Query = L:Query & ' AND Descripcion LIKE ' & SQL.Quote('<37>' & CLIP(L:Texto) & '<37>').
  L:Query = L:Query & ' ORDER BY Fecha DESC, IdTransaccion DESC LIMIT ' & CHOOSE(L:Max > 0,L:Max,1000)
  SETCURSOR(CURSOR:Wait)
  FREE(CbtesQ)
  L:T0 = CLOCK()
  IF SQL.ExecEx(L:Query,1)                          ! 1 = se envía tal cual, sin pasar a minúsculas
    SETCURSOR()
    L:Estado = 'Error: ' & SQL.ErrorText()
    DISPLAY()
    EXIT
  END
  L:T1 = CLOCK()
  SQL.Col_Format(2,'@d10-')                         ! la fecha llega como aaaa-mm-dd
  SQL.LoadQueue(CbtesQ,0,0)                         ! columna 1 -> campo 1 de la cola, columna 2 -> campo 2...
  L:T2 = CLOCK()
  SETCURSOR()
  L:Estado = RECORDS(CbtesQ) & ' comprobantes | consulta ' & (L:T1 - L:T0) * 10 & ' ms + carga ' & |
             (L:T2 - L:T1) * 10 & ' ms | MySQL ' & SQL.ServerVersion()
  SELECT(?Lista,1)
  DISPLAY()
```

## Al cerrar (CloseWindow)
```
  SQL.Kill()
```

OK: Resultado real: 1.000 comprobantes en 30 ms; 30.000 en 430 ms.

## Puntos clave
- `<37>` es el carácter `%` (escrito así para que Clarion no lo tome como parte de un picture).
- Las fechas se arman con `FORMAT(fecha,@d10-)` (`aaaa-mm-dd`) y vuelven con `Col_Format(n,'@d10-')`.
- Los importes llegan con punto decimal y se asignan directo a campos `DECIMAL`.
- `Col_Format` se borra después de cada `LoadQueue`: indicarlo antes de cada carga.
""", [('m-loadqueue', 'LoadQueue'), ('m-quote', 'Quote'), ('m-execex', 'ExecEx'), ('ej-odbc', 'La misma pantalla con ODBC')])

PAGES['ej-odbc'] = ('Ejemplo: la misma pantalla con ODBC', 'Ejemplos', """
La pantalla **Comprobantes > ODBC** de la aplicación de ejemplo es la misma ventana, con la misma consulta, pero con
la SQLClass6 y el driver ODBC de Clarion. Comparar las dos muestra **qué cambia** al pasar a MariaDB directo.

|Parte|ODBC (SQLClass6)|MariaDB directo|
|Objeto|`SQLO SQLOdbcClass`|`SQL SQLMariaClass`|
|Conectar|`SQLO.Init(SQLOdbcFile,SQF:Record,L:Conn)`|`SQL.InitMaria(L:Conn)` (o el mismo `Init`)|
|Tabla de trabajo|`FILE,DRIVER('ODBC')` sobre `sqlclass` (25 campos de 49)|ninguna|
|Comillas en los filtros|a mano: duplicar `'` y `\\`|`SQL.Quote(texto)`|
|Texto del error|lo muestra el driver|`SQL.ErrorText()`|
|Razón social de 70 caracteres|llega cortada a 49|llega completa|

El resto (`ExecEx`, `Col_Format`, `LoadQueue`, el LIST) es **idéntico**.

## Escapar a mano con ODBC
Con la SQLClass6 hay que escapar el texto del usuario antes de ponerlo en la consulta:

```
Esc ROUTINE
  DATA
E   CSTRING(200)
P   LONG
  CODE
  E = ''
  LOOP P = 1 TO LEN(CLIP(L:Texto))
    CASE L:Texto[P]
    OF ''''
      E = E & ''''''
    OF '\\'
      E = E & '\\\\'
    ELSE
      E = E & L:Texto[P]
    END
  END
  L:TextoE = E
```

Con `SQLMariaClass` esa rutina se reemplaza por `SQL.Quote(texto)`, que además usa el juego de caracteres de la conexión.
""", [('ej-comprobantes', 'Comprobantes con MariaDB'), ('m-quote', 'Quote'), ('diferencias', 'Diferencias')])

PAGES['ej-comparar'] = ('Ejemplo: comparar motores', 'Ejemplos', """
La pantalla **Comparar tiempos** de la aplicación de ejemplo corre 8 consultas (sin filtro y con distintos filtros)
con los dos motores, varias veces, y muestra el promedio. Este es el núcleo de la medición, simplificado.

```
SQLM                 SQLMariaClass
SQLO                 SQLOdbcClass
L:R                  LONG
L:Rep                LONG(5)
L:T0                 LONG
L:T1                 LONG
L:T2                 LONG
L:SumM               LONG,DIM(3)                    ! consulta, carga y total (MariaDB)
  CODE
  SQLM.SilentMode = True
  IF SQLM.InitMaria(L:Conn) THEN MESSAGE(SQLM.ErrorText()); RETURN.
  SQLM.KeepCase = True
  CLEAR(L:SumM)
  LOOP L:R = 0 TO L:Rep                             ! la corrida 0 es de calentamiento
    L:T0 = CLOCK()
    IF SQLM.ExecEx(L:Query,1) THEN BREAK.
    L:T1 = CLOCK()
    SQLM.Col_Format(2,'@d10-')
    SQLM.LoadQueue(CbtesQ,0,0)
    L:T2 = CLOCK()
    IF L:R = 0 THEN CYCLE.                          ! no se cuenta: el servidor todavía leía del disco
    L:SumM[1] += (L:T1 - L:T0) * 10
    L:SumM[2] += (L:T2 - L:T1) * 10
    L:SumM[3] += (L:T2 - L:T0) * 10
  END
  MESSAGE('MariaDB: consulta ' & INT(L:SumM[1] / L:Rep) & ' ms, carga ' & INT(L:SumM[2] / L:Rep) & ' ms')
  SQLM.Kill()
```

## Para medir bien
- **Una corrida de calentamiento**: la primera consulta lee del disco y tarda más; si se cuenta, perjudica al motor que va primero.
- **Alternar el orden** de los motores en cada corrida.
- **Verificar que traen lo mismo**: la demo suma los importes y compara la cantidad de filas de los dos.
- `CLOCK()` tiene resolución de 10 ms: medir varias corridas y promediar.

Los resultados están en [[rendimiento|Rendimiento]]. `TCWMariaDemo.exe comparar` corre la comparación sin ventana y deja el resultado en `comparacion.txt`.
""", [('rendimiento', 'Rendimiento'), ('ej-comprobantes', 'Comprobantes con filtros')])

PAGES['ej-grabar'] = ('Ejemplo: insertar, actualizar y transacciones', 'Ejemplos', """
## Insertar y obtener el Id
```
  L:Sql = 'INSERT INTO clientes (Nombre, Cuit, Alta) VALUES (' & |
          SQLM.Quote(CLI:Nombre) & ',' & SQLM.Quote(CLI:Cuit) & ',''' & FORMAT(TODAY(),@d10-) & ''')'
  IF SQLM.ExecEx(L:Sql,1)                           ! 1 = respeta mayúsculas: el nombre se graba como lo escribió el usuario
    MESSAGE('No se pudo grabar: ' & SQLM.ErrorText())
  ELSE
    CLI:Id = SQLM.InsertId()                        ! valor AUTO_INCREMENT generado
  END
```

## Actualizar y saber cuántas filas cambiaron
```
  IF SQLM.ExecEx('UPDATE cbtes SET Saldo = 0 WHERE IdCliente = ' & L:Cliente & ' AND Saldo < 0.01',1) = Level:Benign
    MESSAGE(SQLM.AffectedRows() & ' comprobantes actualizados')
  END
```

## Transacción
Con tablas InnoDB. Si una sentencia falla se deshace todo.

```
L:Error     BYTE
  CODE
  SQLM.BeginTransaction()
  L:Error = SQLM.ExecEx('UPDATE cuentas SET Saldo = Saldo - ' & L:Importe & ' WHERE Id = ' & L:Origen,1)
  IF NOT L:Error
    L:Error = SQLM.ExecEx('UPDATE cuentas SET Saldo = Saldo + ' & L:Importe & ' WHERE Id = ' & L:Destino,1)
  END
  IF L:Error
    SQLM.Rollback()
    MESSAGE('No se pudo transferir: ' & SQLM.ErrorText())
  ELSE
    SQLM.Commit()
  END
```

NOTA: En tablas MyISAM no hay transacciones: `BeginTransaction`, `Commit` y `Rollback` no dan error pero no deshacen nada.

## Un valor suelto
```
  L:Cantidad = SQLM.Fetch(1,'SELECT COUNT(*) FROM cbtes WHERE IdCliente = ' & L:Cliente)
```

## Procedimiento almacenado con resultado
```
  IF SQLM.ExecSP('EXEC sp_SaldoCliente ' & L:Cliente & ', ''' & FORMAT(TODAY(),@d10-) & '''') = Level:Benign
    LOOP UNTIL SQLM.Next()                          ! se envió: CALL sp_SaldoCliente(1000112, '2026-10-28')
      L:Saldo = SQLM.ColByName('Saldo')
    END
  END
```
""", [('m-quote', 'Quote'), ('m-insertid', 'InsertId'), ('m-begintransaction', 'BeginTransaction'), ('m-execsp', 'ExecSP')])

PAGES['ej-log'] = ('Ejemplo: log y ventana de proceso', 'Ejemplos', """
## Anotar cada consulta en un archivo
```
  SQLM.LogFile = LONGPATH() & '\\sql.log'           ! vacío = sin log
```

Cada consulta deja dos líneas: lo que se envió y el resultado con el tiempo en centésimas:

```
20261028 20:25:05 SQL> SELECT COUNT(*) FROM cbtes WHERE Fecha >= '2026-01-01'
20261028 20:25:05     -> OK  (2 cs)
```

También se pueden anotar líneas propias: `SQLM.WriteLog('Inicio del cierre de caja')`.

## Ventana mientras el servidor procesa
```
  SQLM.ShowProgress  = True
  SQLM.ProgressTitle = 'Comprobantes'
  SQLM.ProgressText  = 'Buscando los comprobantes del año...'
  SQLM.ExecEx(L:Query,1)                            ! se ve la ventana mientras espera la respuesta
  SQLM.ShowProgress  = False
```

## Avisar las consultas lentas
```
  SQLM.Debug       = True
  SQLM.Debug_Limit = 300                            ! centésimas: avisa si una consulta tarda más de 3 segundos
```
""", [('propiedades', 'Propiedades'), ('m-writelog', 'WriteLog')])

PAGES['ej-tcwmariadb'] = ('Ejemplo: TCWMariaDB sola', 'Ejemplos', """
`TCWMariaDB` es la conexión que usa `SQLMariaClass` por dentro. Se puede usar sola en código que no necesita la
interfaz de la SQLClass (por ejemplo un proceso o una utilidad). No pasa nada a minúsculas.

```
  INCLUDE('TCWMariaDB.inc'),ONCE

Db          TCWMariaDB
  CODE
  IF Db.Connect(L:Conn)
    MESSAGE('No se pudo conectar: ' & Db.LastError)
    RETURN
  END
  IF Db.Query('SELECT IdCliente, Descripcion, ImporteTotal FROM cbtes WHERE Fecha = CURDATE()') = Level:Benign
    LOOP UNTIL Db.Next()
      Q:Cliente = Db.Col(1)
      Q:Nombre  = Db.Col(Db.ColIndex('Descripcion'))
      Q:Total   = Db.Col(3)
      ADD(Q)
    END
  ELSE
    MESSAGE(Db.LastError)
  END
  Db.Disconnect()
```

Desde un objeto `SQLMariaClass` la misma conexión está en la propiedad `Db`: por ejemplo `SQLM.Db.Ping()` o `SQLM.Db.ConnectTimeout = 5` antes del `Init`.
""", [('tcwmariadb', 'TCWMariaDB'), ('m-db', 'Propiedad Db')])

# =============================================================================================== métodos
# (archivo, nombre, grupo, firma, descripcion, parametros [(nombre, texto)], devuelve, ejemplo, notas, ver, nuevo)
G_CON, G_EXE, G_LEE, G_ESC, G_TRX, G_ERR, G_OTR = ('Conexión', 'Ejecutar consultas', 'Leer resultados', 'Grabar datos',
                                                   'Transacciones', 'Errores y diagnóstico', 'Otros (heredados)')
RET = 'Level:Benign (0) si salió bien; Level:Notify (1) si hubo un error (el texto queda en ErrorText()).'
M = []


def m(f, name, group, sig, desc, params=(), ret=None, ex=None, notes=None, see=(), new=False, same=None):
    M.append(dict(f=f, name=name, group=group, sig=sig, desc=desc, params=params, ret=ret, ex=ex, notes=notes,
                  see=see, new=new, same=same))


m('m-init', 'Init', G_CON, 'Init(*FILE Archivo, *GROUP Registro, STRING Conexion),BYTE,VIRTUAL', """
Conecta con el servidor. Tiene la misma firma que en la SQLClass6 para que el código existente (y el que genera el
template) no cambie: **el archivo y el registro se guardan pero no se usan**; no se abre ningún archivo.
""", [('Archivo', 'archivo de trabajo de la SQLClass (se ignora).'), ('Registro', 'su registro (se ignora).'),
      ('Conexion', 'cadena de conexión. Sirve también la de ODBC (ver [[conexion|Cadena de conexión]]).')], RET, """
  SQLM.SilentMode = True
  IF SQLM.Init(sqlclass,uSQL:Record,GLO:Conexion)
    MESSAGE('No se pudo conectar: ' & SQLM.ErrorText())
  END
""", "Con `SilentMode = False` (por defecto) un error de conexión se muestra con `STOP`. Se puede llamar otra vez para reconectar; cierra la conexión anterior.",
  [('m-initmaria', 'InitMaria'), ('m-kill', 'Kill'), ('conexion', 'Cadena de conexión')],
  same='Misma firma; no abre ni crea la tabla de trabajo.')

m('m-initmaria', 'InitMaria', G_CON, 'InitMaria(STRING Conexion),BYTE', """
Conecta con el servidor sin pasar archivo ni registro. Es lo que llama `Init` por dentro. Usarlo en código nuevo.
""", [('Conexion', 'cadena de conexión (ver [[conexion|Cadena de conexión]]).')], RET, """
  IF SQLM.InitMaria('Server=192.168.0.10;Database=gestion;User=app;Password=' & L:Clave)
    MESSAGE(SQLM.ErrorText())
  END
""", "Deja `FreeQueue = True` y `State = SQL:Ready`. Guarda la cadena en `PropOwner`.",
  [('m-init', 'Init'), ('conexion', 'Cadena de conexión')], new=True)

m('m-kill', 'Kill', G_CON, 'Kill()', """
Cierra la conexión y libera el resultado, las columnas y los formatos. Llamarlo al cerrar la ventana o el
procedimiento. Después se puede volver a llamar a `Init` / `InitMaria`.
""", ex="""
  SQLM.Kill()
""", see=[('m-init', 'Init')], same='Además cierra la conexión con el servidor.')

m('m-serverversion', 'ServerVersion', G_CON, 'ServerVersion(),STRING', """
Devuelve la versión del servidor, por ejemplo `5.0.67-community-nt` o `10.11.6-MariaDB`. Vacío si no hay conexión.
""", ret='La versión como texto.', ex="""
  L:Estado = 'Conectado a MySQL ' & SQLM.ServerVersion()
""", see=[('m-db', 'Propiedad Db')], new=True)

m('m-exec', 'Exec', G_EXE, 'Exec(STRING Query),BYTE', """
Envía una consulta al servidor. Si es un SELECT, deja el resultado listo para leer con `Next` / `Col` / `LoadQueue`.

Como en la SQLClass6, **pasa toda la consulta a minúsculas** antes de enviarla (incluidos los valores entre
comillas), salvo que `KeepCase = True`. Después la analiza con `Parse` y la envía.
""", [('Query', 'la sentencia SQL (SELECT, INSERT, UPDATE, DELETE, CALL, SHOW...).')], RET, """
  SQLM.KeepCase = True
  IF SQLM.Exec('SELECT IdCliente, Descripcion FROM cbtes WHERE TipoCbte = ''FC''') = Level:Benign
    LOOP UNTIL SQLM.Next()
      ! SQLM.Col(1), SQLM.Col(2)
    END
  END
""", """Con `SilentMode = False` un error muestra el mensaje del servidor con `STOP`. Siempre que falla, la consulta queda copiada al portapapeles (también con `SilentMode`).
Con `Debug = True` avisa si la consulta tardó más de `Debug_Limit`.

NOTA: Sin `KeepCase`, un `INSERT ... VALUES ('Juan')` graba `juan`, y en servidores Linux los nombres de tabla con mayúsculas no se encuentran.""",
  [('m-execex', 'ExecEx'), ('m-next', 'Next'), ('propiedades', 'KeepCase')])

m('m-execex', 'ExecEx', G_EXE, 'ExecEx(STRING Query, <BYTE OmitLower>),BYTE', """
Igual que `Exec`, pero con un parámetro para **enviar la consulta tal cual**. Es la forma recomendada en código nuevo.
""", [('Query', 'la sentencia SQL.'), ('OmitLower', 'opcional. 1 = no pasa la consulta a minúsculas. Omitido o 0 = la pasa (como Exec).')],
  RET, """
  IF SQLM.ExecEx('SELECT IdTransaccion, Fecha, Descripcion FROM cbtes WHERE Descripcion LIKE ' & SQLM.Quote('<37>GARCIA<37>'),1)
    MESSAGE(SQLM.ErrorText())
  END
""", "En la SQLClass6 `ExecEx` cuenta las columnas del SELECT con un analizador propio; en `SQLMariaClass` la cantidad y los nombres reales los da el servidor.",
  [('m-exec', 'Exec'), ('ej-comprobantes', 'Ejemplo de comprobantes')])

m('m-execsp', 'ExecSP', G_EXE, 'ExecSP(STRING Query, <SHORT NoCols>),BYTE', """
Ejecuta un procedimiento almacenado que devuelve filas. Acepta la forma de SQL Server y la convierte:

|Se escribe|Se envía|
|`EXEC sp_Saldo 1000112, '2026-10-28'`|`CALL sp_Saldo(1000112, '2026-10-28')`|
|`EXECUTE sp_Saldo 1000112`|`CALL sp_Saldo(1000112)`|
|`CALL sp_Saldo(1000112)`|igual|
|`sp_Totales`|`CALL sp_Totales()`|

No pasa a minúsculas ni por `Parse`. Las filas se leen igual que las de un SELECT.
""", [('Query', 'llamada al procedimiento.'), ('NoCols', 'opcional; cantidad de columnas. No hace falta: la da el servidor.')], RET, """
  IF SQLM.ExecSP('EXEC sp_SaldoCliente ' & L:Cliente) = Level:Benign
    LOOP UNTIL SQLM.Next()
      L:Saldo = SQLM.ColByName('Saldo')
    END
  END
""", "MariaDB devuelve después de un CALL un resultado extra de estado; la clase lo descarta, así que la siguiente consulta no da *Commands out of sync*.",
  [('m-sp', 'SP'), ('ej-grabar', 'Ejemplos de grabación')])

m('m-sp', 'SP', G_EXE, 'SP(SHORT NoCols, STRING SP_Name),BYTE', """
Forma antigua de llamar a un procedimiento almacenado: envía `CALL ` & SP_Name con `Exec` (por lo tanto pasa a
minúsculas salvo `KeepCase`). En código nuevo usar `ExecSP`.
""", [('NoCols', 'cantidad de columnas que devuelve.'), ('SP_Name', "nombre y parámetros, por ejemplo `sp_Cierre(20261028)`.")], RET, """
  SQLM.SP(1,'sp_Cierre(20261028)')
""", see=[('m-execsp', 'ExecSP')])

m('m-fetch', 'Fetch', G_EXE, 'Fetch(SHORT NroCol, STRING Query),STRING\nFetch(SHORT NroCol, STRING Query, *STRING Result),BYTE', """
Ejecuta una consulta (con `Exec`) y devuelve una columna de la **primera fila**. Útil para un valor suelto: un COUNT,
un nombre, un saldo.

- La primera forma devuelve el valor.
- La segunda lo deja en `Result` y devuelve si salió bien.
""", [('NroCol', 'número de columna a devolver.'), ('Query', 'la consulta.'), ('Result', 'variable donde queda el valor (segunda forma).')],
  "Primera forma: el valor de la columna. Segunda forma: Level:Benign si trajo una fila; Level:Notify si hubo error o no hubo filas.", """
  L:Cantidad = SQLM.Fetch(1,'SELECT COUNT(*) FROM cbtes WHERE IdCliente = ' & L:Cliente)

  IF SQLM.Fetch(1,'SELECT Descripcion FROM clientes WHERE Id = ' & L:Cliente,L:Nombre)
    L:Nombre = '(no existe)'
  END
""", "En la primera forma, heredada de la SQLClass6, un error devuelve `'1'` y una consulta sin filas `'0'`: si eso puede confundirse con un valor real, usar la segunda forma. Pasa por `Exec`: usar `KeepCase = True` si hay textos.",
  [('m-exec', 'Exec')])

m('m-parse', 'Parse', G_EXE, 'Parse(),BYTE', """
Uso interno de `Exec` / `ExecEx`. Separa las cláusulas de `Query` en `SQL_Select`, `SQL_From`, `SQL_Where`,
`SQL_GroupBy` y `SQL_OrderBy` (las usa `Records()` cuando no hay resultado) y llama a los métodos virtuales
`TakeSelect`, `TakeInsert`, `TakeUpdate`, `TakeDelete`, `TakeDrop`.

Además de lo que aceptaba la SQLClass6, reconoce SHOW, DESCRIBE, EXPLAIN, REPLACE, USE, WITH, LOCK / UNLOCK,
RENAME, GRANT, ANALYZE, OPTIMIZE, FLUSH y otras sentencias de MariaDB, y un SELECT sin FROM (`SELECT NOW()`).
Una sentencia desconocida avisa (si `SilentMode = False`) y se envía igual.
""", ret='Level:Benign, o Level:Notify si un Take* lo pidió.', see=[('m-exec', 'Exec'), ('m-take', 'Métodos Take*')])

m('m-serverexec', 'ServerExec / ServerExecEx', G_EXE, 'ServerExec(),BYTE\nServerExecEx(),BYTE', """
Uso interno: envían al servidor lo que hay en la propiedad `Query`, con log (`LogFile`) y ventana de proceso
(`ShowProgress`). `ServerExec` lo pasa a minúsculas salvo `KeepCase`; `ServerExecEx` lo envía tal cual.
Normalmente no se llaman directo: usar `Exec` / `ExecEx`.
""", ret=RET, see=[('m-exec', 'Exec'), ('m-execex', 'ExecEx')])

m('m-next', 'Next', G_LEE, 'Next(),BYTE,PROC', """
Avanza a la siguiente fila del resultado. Después se leen las columnas con `Col` o `ColByName`. Por cada fila llama
al método virtual `TakeRecord`.
""", ret='Level:Benign (0) si trajo una fila; Level:Notify (1) si no hay más filas (o no hay resultado).', ex="""
  LOOP UNTIL SQLM.Next()
    Q:Codigo = SQLM.Col(1)
    Q:Nombre = SQLM.Col(2)
    ADD(Q)
  END
""", notes="Suma 1 a `Records_Done` por cada fila. Para una sola fila: `IF SQLM.Exec(...) = Level:Benign AND SQLM.Next() = Level:Benign`.",
  see=[('m-col', 'Col'), ('m-loadqueue', 'LoadQueue')])

m('m-col', 'Col', G_LEE, 'Col(SHORT NroCol),STRING', """
Devuelve el valor de una columna de la fila actual, como texto. Se asigna directo a campos numéricos, de texto o
`DECIMAL`.
""", [('NroCol', 'número de columna (1 = la primera del SELECT).')],
  "El valor como texto. `''` si es NULL o si la columna no existe.", """
  CBQ:Cliente = SQLM.Col(7)
  CBQ:Total   = SQLM.Col(8)                         ! '12345.67' -> 12345.67
  CBQ:Fecha   = DEFORMAT(SQLM.Col(2),@d10-)         ! '2026-10-28' -> fecha de Clarion
""", """No tiene límite de largo. Formatos que manda el servidor: fechas `aaaa-mm-dd`, horas `hh:mm:ss`, números con punto decimal.
`Col_Format` no se aplica aquí (solo en `LoadQueue`): para fechas usar `DEFORMAT`.""",
  [('m-colbyname', 'ColByName'), ('m-isnull', 'IsNull')], same='No depende del registro de la tabla de trabajo: sin límite de columnas ni de largo.')

m('m-colbyname', 'ColByName', G_LEE, 'ColByName(STRING Nombre),STRING', """
Devuelve el valor de una columna por su nombre (o por el alias del `AS`). No distingue mayúsculas. Hace que el código
no dependa del orden de las columnas en el SELECT.
""", [('Nombre', 'nombre de la columna.')], "El valor como texto. `''` si la columna no existe o es NULL.", """
  IF SQLM.ExecEx('SELECT IdCliente, SUM(ImporteTotal) AS Total FROM cbtes GROUP BY IdCliente',1) = Level:Benign
    LOOP UNTIL SQLM.Next()
      Q:Cliente = SQLM.ColByName('IdCliente')
      Q:Total   = SQLM.ColByName('total')
      ADD(Q)
    END
  END
""", see=[('m-col', 'Col'), ('m-field', 'Field')], new=True)

m('m-isnull', 'IsNull', G_LEE, 'IsNull(SHORT NroCol),BYTE', """
Indica si una columna de la fila actual es NULL. `Col` devuelve `''` tanto para NULL como para un texto vacío; con
`IsNull` se distinguen.
""", [('NroCol', 'número de columna.')], '1 si es NULL (o la columna no existe); 0 si tiene valor.', """
  IF SQLM.IsNull(4)
    Q:FechaBaja = 0
  ELSE
    Q:FechaBaja = DEFORMAT(SQLM.Col(4),@d10-)
  END
""", see=[('m-col', 'Col')], new=True)

m('m-columns', 'Columns', G_LEE, 'Columns(),SHORT', """
Cantidad de columnas del último resultado. Con `SQLMariaClass` es el número exacto que manda el servidor.
""", ret='Cantidad de columnas.', ex="""
  LOOP L:I = 1 TO SQLM.Columns()
    L:Titulos = CLIP(L:Titulos) & ' ' & SQLM.Field(L:I)
  END
""", see=[('m-field', 'Field')], same='Exacto: no depende del analizador del SELECT.')

m('m-field', 'Field', G_LEE, 'Field(SHORT FieldNo),STRING', """
Nombre de una columna del último resultado (el alias si tiene `AS`). Útil para armar títulos o exportar.
""", [('FieldNo', 'número de columna.')], "El nombre, o `''` si no existe.", """
  MESSAGE('La columna 8 es ' & SQLM.Field(8))       ! ImporteTotal
""", see=[('m-columns', 'Columns'), ('m-colbyname', 'ColByName')], same='Devuelve el nombre real que manda el servidor.')

m('m-records', 'Records', G_LEE, 'Records(),LONG', """
Cantidad de filas.

- **Si hay un resultado abierto** (después de un SELECT), cuenta sus filas: es exacto también con `GROUP BY`, `DISTINCT` o `LIMIT`, y no hace otra consulta.
- **Si no**, igual que la SQLClass6: ejecuta `SELECT COUNT(*)` con el FROM y el WHERE de la última consulta.
""", ret='Cantidad de filas (también queda en la propiedad `Records`).', ex="""
  IF SQLM.ExecEx('SELECT IdCliente FROM cbtes WHERE Fecha >= ''2026-01-01'' GROUP BY IdCliente',1) = Level:Benign
    MESSAGE(SQLM.Records() & ' clientes con comprobantes este año')
  END
""", notes="Cuenta todas las filas del resultado, no las que faltan leer.", see=[('m-loadqueue', 'LoadQueue')],
  same='Con resultado abierto no hace un COUNT(*) aparte.')

m('m-loadqueue', 'LoadQueue', G_LEE, 'LoadQueue(*QUEUE MyQ, BYTE WithCount, BYTE ShowWin),BYTE', """
Carga todas las filas del resultado en una cola, **por posición**: la columna 1 va al primer campo de la cola, la 2
al segundo, y así. Es la forma más rápida de llenar un LIST.
""", [('MyQ', 'la cola. Sus primeros campos tienen que estar en el mismo orden que las columnas del SELECT.'),
      ('WithCount', '1 = cuenta las filas antes (para el porcentaje de la ventana).'),
      ('ShowWin', '1 = muestra una ventana con el avance y el botón para cancelar.')],
  "Level:Benign; Level:Notify si falló el ADD a la cola.", """
  FREE(CbtesQ)
  IF SQLM.ExecEx(L:Query,1) = Level:Benign
    SQLM.Col_Format(2,'@d10-')                      ! columna 2: fecha aaaa-mm-dd
    SQLM.LoadQueue(CbtesQ,0,0)
  END
""", """- Si `FreeQueue = True` (el valor que deja `Init`) vacía la cola antes de cargar.
- Aplica los formatos de `Col_Format` con `DEFORMAT` y después los borra.
- Si `MaxReads` es mayor que 0, avisa y deja de cargar al pasar esa cantidad.
- Al terminar, `Records` = cantidad de filas de la cola.
- Si la cola tiene menos campos que columnas el SELECT, las columnas sobrantes se ignoran.""",
  [('m-col-format', 'Col_Format'), ('ej-comprobantes', 'Ejemplo de comprobantes')],
  same='Mismo comportamiento; el porcentaje de la ventana ahora es correcto.')

m('m-col-format', 'Col_Format', G_LEE, 'Col_Format(SHORT NroCol, STRING Formato)', """
Indica el picture con que `LoadQueue` convierte (con `DEFORMAT`) una columna antes de ponerla en la cola. Se usa
sobre todo para fechas y horas, que llegan como texto.
""", [('NroCol', 'número de columna.'), ('Formato', "picture de Clarion, por ejemplo `'@d10-'` para `aaaa-mm-dd` o `'@t4'` para `hh:mm:ss`.")],
  ex="""
  SQLM.Col_Format(2,'@d10-')
  SQLM.Col_Format(3,'@t4')
  SQLM.LoadQueue(MovQ,0,0)
""", notes="Los formatos se borran después de cada `LoadQueue`: indicarlos antes de cada carga. No se aplican a `Col()`.",
  see=[('m-loadqueue', 'LoadQueue')])

m('m-escape', 'Escape', G_ESC, 'Escape(STRING Texto),STRING', """
Escapa un texto para ponerlo entre comillas en una consulta: comillas, barra invertida, saltos de línea y el carácter
0. Usa el juego de caracteres de la conexión. Quita los espacios del final.
""", [('Texto', 'el valor.')], 'El texto escapado, sin comillas alrededor.', """
  L:Sql = 'SELECT * FROM clientes WHERE Nombre LIKE ''' & SQLM.Escape(L:Buscar) & '<37>'''
""", "Normalmente es más cómodo `Quote`, que además agrega las comillas.", [('m-quote', 'Quote')], new=True)

m('m-quote', 'Quote', G_ESC, 'Quote(STRING Texto),STRING', """
Escapa un texto y lo devuelve **entre comillas simples**, listo para concatenar en la consulta. Evita errores con
nombres como `O'Higgins` y protege de la inyección de SQL con lo que escribe el usuario.
""", [('Texto', 'el valor.')], "`'texto escapado'`.", """
  L:Sql = 'UPDATE clientes SET Nombre = ' & SQLM.Quote(CLI:Nombre) & ' WHERE Id = ' & CLI:Id
  L:Sql = 'SELECT ... WHERE Descripcion LIKE ' & SQLM.Quote('<37>' & CLIP(L:Texto) & '<37>')
""", see=[('m-escape', 'Escape'), ('ej-grabar', 'Ejemplos de grabación')], new=True)

m('m-insertid', 'InsertId', G_ESC, 'InsertId(),LONG', """
Devuelve el valor AUTO_INCREMENT que generó el último INSERT.
""", ret='El Id generado; 0 si la última sentencia no generó ninguno.', ex="""
  IF SQLM.ExecEx('INSERT INTO pedidos (IdCliente, Fecha) VALUES (' & L:Cliente & ',CURDATE())',1) = Level:Benign
    PED:Id = SQLM.InsertId()
  END
""", notes="Se reinicia en cada consulta: leerlo inmediatamente después del INSERT.", see=[('m-affectedrows', 'AffectedRows')], new=True)

m('m-affectedrows', 'AffectedRows', G_ESC, 'AffectedRows(),LONG', """
Cantidad de filas afectadas por el último INSERT, UPDATE o DELETE. Después de un SELECT es la cantidad de filas del resultado.
""", ret='Cantidad de filas.', ex="""
  SQLM.ExecEx('DELETE FROM temporales WHERE Fecha < CURDATE()',1)
  MESSAGE(SQLM.AffectedRows() & ' registros borrados')
""", notes="En un UPDATE, MySQL cuenta solo las filas que cambiaron de valor.", see=[('m-insertid', 'InsertId')], new=True)

m('m-begintransaction', 'BeginTransaction / Commit / Rollback', G_TRX,
  'BeginTransaction(),BYTE,PROC\nCommit(),BYTE,PROC\nRollback(),BYTE,PROC', """
Manejan una transacción: `BeginTransaction` envía `START TRANSACTION`, `Commit` confirma los cambios y `Rollback`
los deshace.
""", ret=RET, ex="""
  SQLM.BeginTransaction()
  L:Error = SQLM.ExecEx(L:Sql1,1)
  IF NOT L:Error THEN L:Error = SQLM.ExecEx(L:Sql2,1).
  IF L:Error
    SQLM.Rollback()
  ELSE
    SQLM.Commit()
  END
""", notes="""Solo en tablas InnoDB (en MyISAM no deshacen nada). No pasan por `LogFile`.
Si la conexión se corta en medio de una transacción, la reconexión automática empieza una sesión nueva: la transacción se pierde (el servidor la deshace).""",
  see=[('ej-grabar', 'Ejemplo de transacción')], new=True)

m('m-errortext', 'ErrorText / ErrorCode', G_ERR, 'ErrorText(),STRING\nErrorCode(),LONG', """
Texto y número del último error del servidor o de la conexión. Útiles con `SilentMode = True`, cuando la clase no
muestra los errores.
""", ret="Texto con el detalle y el número entre paréntesis, por ejemplo `Error en la consulta: Unknown column 'x' in 'field list' (1054)`. Vacío si la última operación salió bien.", ex="""
  SQLM.SilentMode = True
  IF SQLM.ExecEx(L:Query,1)
    L:Estado = 'Error ' & SQLM.ErrorCode() & ': ' & SQLM.ErrorText()
  END
""", notes="Errores comunes: 1045 usuario o clave, 1049 base inexistente, 1054 columna inexistente, 1146 tabla inexistente, 2003 no se llega al servidor, 2006 / 2013 se cortó la conexión.",
  see=[('propiedades', 'SilentMode')], new=True)

m('m-writelog', 'WriteLog', G_ERR, 'WriteLog(STRING Text)', """
Agrega una línea `aaaammdd hh:mm:ss.cc texto` al archivo indicado en `LogFile`. La clase la usa para anotar cada
consulta; también se puede llamar para anotar líneas propias. Si `LogFile` está vacío no hace nada.
""", [('Text', 'el texto a anotar.')], ex="""
  SQLM.LogFile = LONGPATH() & '\\sql.log'
  SQLM.WriteLog('Cierre de caja: inicio')
""", notes="Con StringTheory (por defecto) o, si el template tiene destildado *Usar StringTheory*, con la API de Windows.",
  see=[('ej-log', 'Ejemplo de log')])

m('m-take', 'TakeRecord y Take*', G_OTR, 'TakeRecord(),BYTE,VIRTUAL\nTakeSelect / TakeInsert / TakeUpdate / TakeDelete / TakeDrop(),BYTE,VIRTUAL', """
Métodos virtuales que se pueden completar desde los embeds del objeto en el template:

- `TakeRecord`: se llama en cada `Next()` que trajo una fila. Lo que devuelve es lo que devuelve `Next`.
- `TakeSelect`, `TakeInsert`, ...: se llaman desde `Parse` según el tipo de sentencia. Devolver Level:Notify cancela el envío (salvo en SELECT).
""", ret='Level:Benign para seguir.', ex="""
! embed de SQLM.TakeRecord (antes de la llamada a PARENT)
  L:Filas += 1
  IF L:Filas % 1000 = 0 THEN DISPLAY(?Avance).
""", see=[('m-next', 'Next'), ('template', 'Template')])

m('m-registerupdate', 'RegisterUpdate / UpdateBuffer', G_OTR,
  'RegisterUpdate(*FileManager MyFm, *KEY MyKey, *? MyField),VIRTUAL\nUpdateBuffer(),BYTE,PROC', """
Heredados de la SQLClass6 (*AutoUpdate*): `RegisterUpdate` asocia el objeto a un archivo del diccionario, su clave
y el campo de la clave primaria; `UpdateBuffer` toma el valor de la columna `PK_Col` de la fila actual y lee ese
registro con el FileManager.
""", ret='UpdateBuffer: False si leyó el registro; True si no lo encontró.', ex="""
  SQLM.RegisterUpdate(Access:Clientes,CLI:PorId,CLI:Id)
  SQLM.PK_Col = 1
  IF SQLM.ExecEx('SELECT Id FROM clientes WHERE Saldo > 0',1) = Level:Benign
    LOOP UNTIL SQLM.Next()
      IF NOT SQLM.UpdateBuffer()
        ! CLI:Record tiene el cliente completo
      END
    END
  END
""", see=[('propiedades', 'Propiedades')])

M_GROUPS = [G_CON, G_EXE, G_LEE, G_ESC, G_TRX, G_ERR, G_OTR]

PROPS = """
|Propiedad|Tipo|Uso|
|`KeepCase`|BYTE|**Nueva.** 1 = `Exec`, `Fetch`, `SP` y `Records` envían la consulta tal cual, sin pasarla a minúsculas.|
|`Db`|&TCWMariaDB|**Nueva.** La conexión directa (ver [[tcwmariadb|TCWMariaDB]]): `SQLM.Db.AutoReconnect`, `SQLM.Db.ConnectTimeout`, `SQLM.Db.Ping()`...|
|`SilentMode`|BYTE|1 = no muestra los errores (sin STOP ni MESSAGE); se leen con `ErrorText()`.|
|`LogFile`|CSTRING(260)|Archivo donde se anota cada consulta y su resultado. Vacío = sin log.|
|`ShowProgress`|BYTE|1 = muestra una ventana mientras el servidor procesa cada consulta.|
|`ProgressTitle`, `ProgressText`|CSTRING|Título y texto de esa ventana.|
|`Debug`, `Debug_Limit`|BYTE, TIME|Avisa las consultas que tardan más de `Debug_Limit` centésimas.|
|`MaxReads`|LONG|Máximo de filas que carga `LoadQueue` (0 = sin límite). El template lo llena con *Limitar Cant. Máxima de Registros*.|
|`FreeQueue`|BYTE|1 = `LoadQueue` vacía la cola antes de cargar (lo deja en 1 el `Init`).|
|`Records`|LONG|Cantidad de filas: la actualizan `Records()` y `LoadQueue`.|
|`Records_Done`|LONG|Filas leídas con `Next` desde la última consulta.|
|`Query`|CSTRING(20480)|La última consulta enviada (ya en minúsculas si correspondía).|
|`SQL_Select`, `SQL_From`, `SQL_Where`, `SQL_GroupBy`, `SQL_OrderBy`|CSTRING|Cláusulas de la última consulta, separadas por `Parse`.|
|`State`|BYTE|`SQL:Ready` (1) conectado; `SQL:NotReady` (0) no. `Next` lo pone en 1 si trajo una fila y en 0 al final.|
|`PropOwner`|CSTRING|La cadena de conexión del último `Init`.|
|`PK_Col`, `AutoUpdate`|SHORT, BYTE|Para `RegisterUpdate` / `UpdateBuffer`.|

NOTA: `KeepCase` no afecta a `ExecEx` (se decide con su segundo parámetro) ni a `ExecSP` (nunca pasa a minúsculas).
"""

TCW_PROPS = """
|Propiedad|Tipo|Uso|
|`Host`, `Port`, `User`, `Password`, `Database`|CSTRING / LONG|Datos de conexión (los llena `SetConnection`).|
|`Charset`|CSTRING(32)|Juego de caracteres; `latin1` por defecto.|
|`ConnectTimeout`|LONG|Segundos para conectar; 10 por defecto.|
|`AutoReconnect`|BYTE|1 (por defecto) = si se cortó la conexión (2006 / 2013), reconecta y reintenta una vez.|
|`SSL`|BYTE|0 = TLS opcional; 1 = TLS obligatorio con verificación del certificado.|
|`LastError`, `LastErrno`|CSTRING, LONG|Último error.|
|`AffectedRows`, `InsertId`|LONG|Del último INSERT / UPDATE / DELETE (después de un SELECT, `AffectedRows` = filas del resultado).|
"""

TCW_METHODS = """
|Método|Devuelve|Qué hace|
|`SetConnection(STRING Cadena)`| |Lee la cadena de conexión y llena las propiedades (no conecta).|
|`Connect(<STRING Cadena>)`|BYTE|Conecta (con la cadena o con las propiedades). 0 = bien.|
|`Disconnect()`| |Cierra la conexión y libera el resultado.|
|`Connected()`|BYTE|1 si hay conexión abierta.|
|`Ping()`|BYTE|Verifica que el servidor responde. 0 = bien.|
|`Query(STRING Sql)`|BYTE|Envía la sentencia tal cual y guarda el resultado completo. 0 = bien.|
|`HasResult()`|BYTE|1 si la última sentencia devolvió filas.|
|`Next()`|BYTE|Siguiente fila: 0 si trajo una, 1 al final.|
|`Columns()`|LONG|Cantidad de columnas del resultado.|
|`RowCount()`|LONG|Cantidad de filas del resultado.|
|`Col(LONG n)`|STRING|Valor de la columna n de la fila actual (`''` si es NULL).|
|`IsNull(LONG n)`|BYTE|1 si la columna es NULL.|
|`ColName(LONG n)`|STRING|Nombre de la columna n.|
|`ColIndex(STRING Nombre)`|LONG|Número de la columna con ese nombre (0 si no existe); no distingue mayúsculas.|
|`FreeResult()`| |Libera el resultado y descarta los pendientes (los de un CALL).|
|`Escape(STRING Texto)`|STRING|Texto escapado para ir entre comillas.|
|`Quote(STRING Texto)`|STRING|Texto escapado y entre comillas.|
|`BeginTransaction()`, `Commit()`, `Rollback()`|BYTE|Transacciones (InnoDB).|
|`ServerVersion()`, `ClientVersion()`|STRING|Versión del servidor y de libmariadb.dll.|
"""


def method_page(x):
    tag = '<span class="tag nuevo">nuevo</span>' if x['new'] else ''
    body = f'<pre class="sig">{html.escape(x["sig"])}</pre>'
    body += md(x['desc'])
    if x['params']:
        rows = ''.join(f'<tr><td><code>{html.escape(p)}</code></td><td>{md(t)[3:-4] if md(t).startswith("<p>") else md(t)}</td></tr>'
                       for p, t in x['params'])
        body += f'<h2>Parámetros</h2><table><tr><th>Parámetro</th><th>Descripción</th></tr>{rows}</table>'
    if x['ret']:
        body += '<h2>Devuelve</h2>' + md(x['ret'])
    if x['ex']:
        body += '<h2>Ejemplo</h2>' + hl(x['ex'].strip('\n'))
    if x['notes']:
        body += '<h2>Observaciones</h2>' + md(x['notes'])
    if x['same']:
        body += '<h2>Respecto de SQLClass6</h2>' + md('DIF: ' + x['same'])
    elif x['new']:
        body += '<h2>Respecto de SQLClass6</h2>' + md('DIF: Método nuevo: no existe en la SQLClass6.')
    else:
        body += '<h2>Respecto de SQLClass6</h2>' + md('DIF: Igual que en la SQLClass6.')
    page(x['f'], f"SQLMariaClass.{x['name']}", f"SQLMariaClass > {x['group']}", tag + body, list(x['see']))


def class_page():
    body = md("""
`SQLMariaClass` hereda de `SQLOdbcClass` (SQLClass6) y reimplementa sus métodos para enviar el SQL directo al
servidor con [[tcwmariadb|TCWMariaDB]]. Archivos: `SQLClass6Maria.inc` / `SQLClass6Maria.clw`.

```
SQLM        SQLMariaClass                       ! objeto
SQLR        &SQLMariaClass                      ! referencia: el tipo tiene que ser SQLMariaClass
  CODE
  SQLR &= NEW SQLMariaClass
  ...
  DISPOSE(SQLR)
```

**Códigos de retorno** (como la SQLClass6): Level:Benign (0) = bien; Level:Notify (1) = error. `Next()` devuelve 0
cuando trajo una fila.
""")
    for g in M_GROUPS:
        rows = ''
        for x in [x for x in M if x['group'] == g]:
            first = re.sub(r'\s+', ' ', x['desc'].strip()).split('. ')[0].rstrip('.') + '.'
            nuevo = ' <span class="tag nuevo">nuevo</span>' if x['new'] else ''
            rows += f'<tr><td><a href="{x["f"]}.html">{html.escape(x["name"])}</a>{nuevo}</td><td>{md(first)[3:-4]}</td></tr>'
        body += f'<h2>{html.escape(g)}</h2><table>{rows}</table>'
    body += '<h2>Propiedades</h2><p>Ver <a href="propiedades.html">Propiedades de SQLMariaClass</a>.</p>'
    page('sqlmariaclass', 'Clase SQLMariaClass', 'Referencia', body,
         [('propiedades', 'Propiedades'), ('diferencias', 'Diferencias con SQLClass6'), ('tcwmariadb', 'TCWMariaDB')])


def build():
    OUT.mkdir(exist_ok=True)
    for old in OUT.glob('*.html'):
        old.unlink()
    (OUT / 'style.css').write_text(CSS, encoding='ascii')
    for f, (title, crumb, text, see) in PAGES.items():
        page(f, title, crumb, md(text), see)
    class_page()
    page('propiedades', 'Propiedades de SQLMariaClass', 'Referencia > SQLMariaClass', md(PROPS),
         [('sqlmariaclass', 'SQLMariaClass'), ('ej-log', 'Ejemplo de log')])
    page('m-db', 'SQLMariaClass.Db', 'Referencia > SQLMariaClass', md("""
Propiedad `Db` (`&TCWMariaDB`): la conexión directa que usa el objeto. Se crea en el constructor y se libera en el
destructor. Sirve para ajustar la conexión o usar lo que `SQLMariaClass` no expone:

```
  SQLM.Db.ConnectTimeout = 5                        ! antes del Init
  SQLM.Db.AutoReconnect  = False
  IF SQLM.InitMaria(L:Conn) THEN RETURN.
  IF SQLM.Db.Ping() THEN MESSAGE('Se perdió la conexión: ' & SQLM.Db.LastError).
  L:Version = SQLM.Db.ClientVersion()               ! versión de libmariadb.dll
```

NOTA: No ejecutar consultas con `SQLM.Db.Query` mientras se lee un resultado de `SQLM`: comparten el resultado.
"""), [('tcwmariadb', 'TCWMariaDB'), ('propiedades', 'Propiedades')])
    page('tcwmariadb', 'Clase TCWMariaDB', 'Referencia', md("""
`TCWMariaDB` (`TCWMariaDB.inc` / `.clw`) llama a `libmariadb.dll` por su API pública. Es lo que usa
`SQLMariaClass` por dentro, y se puede usar sola. Devuelve lo mismo que la SQLClass: 0 = bien, 1 = error (detalle
en `LastError`). **No pasa nada a minúsculas.**
""") + '<h2>Propiedades</h2>' + md(TCW_PROPS) + '<h2>Métodos</h2>' + md(TCW_METHODS) + md("""
## Ejemplo
```
Db          TCWMariaDB
  CODE
  IF Db.Connect(L:Conn) THEN MESSAGE(Db.LastError); RETURN.
  IF Db.Query('SELECT COUNT(*) FROM cbtes') = Level:Benign AND Db.Next() = Level:Benign
    MESSAGE(Db.Col(1) & ' comprobantes')
  END
  Db.Disconnect()
```
"""), [('ej-tcwmariadb', 'Ejemplo completo'), ('m-db', 'SQLMariaClass.Db'), ('conexion', 'Cadena de conexión')])
    for x in M:
        method_page(x)
    write_project()


# ============================================================================================ proyecto
TOC = [
    ('Inicio', 'index'),
    ('Guía', None, [('Instalación y requisitos', 'instalacion'), ('Cadena de conexión', 'conexion'),
                    ('Primeros pasos', 'primeros-pasos'), ('Template SQLClass (Motor MariaDB)', 'template'),
                    ('Diferencias con SQLClass6', 'diferencias'), ('Rendimiento', 'rendimiento'),
                    ('Problemas frecuentes', 'problemas')]),
    ('Ejemplos', None, [('Comprobantes con filtros', 'ej-comprobantes'), ('La misma pantalla con ODBC', 'ej-odbc'),
                        ('Comparar motores', 'ej-comparar'), ('Insertar, actualizar y transacciones', 'ej-grabar'),
                        ('Log y ventana de proceso', 'ej-log'), ('TCWMariaDB sola', 'ej-tcwmariadb')]),
    ('Referencia', None, [('SQLMariaClass', 'sqlmariaclass'), ('Propiedades', 'propiedades'), ('Propiedad Db', 'm-db')]
     + [(g, None, [(x['name'], x['f']) for x in M if x['group'] == g]) for g in M_GROUPS]
     + [('TCWMariaDB', 'tcwmariadb')]),
]


def obj(name, f=None):
    s = f'<LI> <OBJECT type="text/sitemap">\n<param name="Name" value="{html.escape(name)}">\n'
    if f:
        s += f'<param name="Local" value="{f}.html">\n'
    return s + '</OBJECT>\n'


def toc_items(items):
    s = '<UL>\n'
    for it in items:
        s += obj(it[0], it[1])
        if len(it) > 2:
            s += toc_items(it[2])
    return s + '</UL>\n'


HEAD = ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML//EN">\n<HTML><HEAD>\n'
        '<meta http-equiv="Content-Type" content="text/html; charset=windows-1252">\n</HEAD><BODY>\n')


def write_project():
    (OUT / 'toc.hhc').write_bytes((HEAD + toc_items(TOC) + '</BODY></HTML>\n').encode('cp1252', errors='xmlcharrefreplace'))
    keys = []
    for x in M:
        for n in x['name'].replace(' / ', '/').split('/'):
            n = n.strip()
            keys.append((n, x['f']))
            keys.append((f'SQLMariaClass.{n}', x['f']))
    keys += [('Cadena de conexión', 'conexion'), ('Charset', 'conexion'), ('SSL / TLS', 'conexion'),
             ('Template SQLClass', 'template'), ('Motor (template)', 'template'), ('StringTheory', 'template'),
             ('TCW_Display', 'template'), ('KeepCase', 'propiedades'), ('SilentMode', 'propiedades'),
             ('LogFile', 'ej-log'), ('ShowProgress', 'ej-log'), ('Debug_Limit', 'ej-log'), ('MaxReads', 'propiedades'),
             ('FreeQueue', 'propiedades'), ('Db', 'm-db'), ('TCWMariaDB', 'tcwmariadb'), ('libmariadb.dll', 'instalacion'),
             ('Instalación', 'instalacion'), ('ODBC', 'ej-odbc'), ('Rendimiento', 'rendimiento'),
             ('Minúsculas', 'm-exec'), ('Fechas', 'm-col-format'), ('NULL', 'm-isnull'), ('Errores', 'm-errortext'),
             ('Procedimientos almacenados', 'm-execsp'), ('Transacciones', 'm-begintransaction'),
             ('Problemas frecuentes', 'problemas'), ('Diferencias con SQLClass6', 'diferencias')]
    s = HEAD + '<UL>\n' + ''.join(obj(k, f) for k, f in sorted(set(keys), key=lambda t: t[0].lower())) + '</UL>\n</BODY></HTML>\n'
    (OUT / 'index.hhk').write_bytes(s.encode('cp1252', errors='xmlcharrefreplace'))
    files = sorted(p.name for p in OUT.glob('*.html')) + ['style.css']
    hhp = f"""[OPTIONS]
Compatibility=1.1 or later
Compiled file=TCWMariaDB.chm
Contents file=toc.hhc
Index file=index.hhk
Default topic=index.html
Display compile progress=No
Full-text search=Yes
Language=0x2c0a Español (Argentina)
Title={TITLE}

[FILES]
""" + '\n'.join(files) + '\n'
    (OUT / 'TCWMariaDB.hhp').write_bytes(hhp.replace('\n', '\r\n').encode('cp1252'))
    print(f'{len(files) - 1} paginas en {OUT}')


if __name__ == '__main__':
    build()

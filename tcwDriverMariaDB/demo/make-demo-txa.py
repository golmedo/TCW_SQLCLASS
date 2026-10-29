"""Genera TCWMariaDemo.txa: frame + Comprobantes (SQLMariaClass) + ComprobantesOdbc (SQLClass6 + driver ODBC) + Comparar.

python make-demo-txa.py      -> escribe TCWMariaDemo.txa (UTF-8; build-demo.ps1 lo pasa a cp1252)
Las dos pantallas de comprobantes tienen la misma ventana y la misma consulta; cambia solo el objeto SQL.
"""
from pathlib import Path

STAMP = "MODIFIED '2026/10/28' '10:00:00'"
COLS = "IdTransaccion, Fecha, TipoCbte, Letra_Cbte, NroCbte, IdCliente, Descripcion, ImporteTotal, Saldo"
LIST_FORMAT = ("48R(2)|M~Id~C(0)@n_10@44R(2)|M~Fecha~C(0)@d6@24C|M~Tipo~@s3@12C|M~L~@s1@42R(2)|M~Numero~C(0)@n_8@"
               "40R(2)|M~Cliente~C(0)@n_8@170L(2)|M~Razon social~@s70@68R(2)|M~Total~C(0)@n-17.2@64R(2)|M~Saldo~C(0)@n-15.2@")

CBTES_QUEUE = """\
CbtesQ               QUEUE,PRE(CBQ)
IdTransaccion          LONG
Fecha                  LONG
TipoCbte               STRING(3)
Letra                  STRING(1)
NroCbte                LONG
IdCliente              LONG
Cliente                STRING(70)
Total                  DECIMAL(17,2)
Saldo                  DECIMAL(12,2)
                     END"""


def embed(name, code, priority=4000, when=None, when2=None):
    """Bloque EMBED de TXA. when/when2 = instancias (control, evento)."""
    body = f"[DEFINITION]\n[SOURCE]\nPROPERTY:BEGIN\nPRIORITY {priority}\nPROPERTY:END\n{code.rstrip()}\n[END]\n"
    if when2:
        return f"EMBED {name}\n[INSTANCES]\nWHEN '{when}'\n[INSTANCES]\nWHEN '{when2}'\n{body}[END]\n[END]\n"
    if when:
        return f"EMBED {name}\n[INSTANCES]\nWHEN '{when}'\n{body}[END]\n"
    return f"EMBED {name}\n{body}"


def module(n, proc_text):
    return f"[MODULE]\nNAME 'TCWMariaDemo{n:03d}.clw'\n[COMMON]\nFROM ABC GENERATED\n{STAMP}\n{proc_text}[END]\n"


# barra y texto de avance de SQLMariaClass (SQL.ProgressFeq / SQL.ProgressTextFeq)
AVANCE_CONTROLS = """\
       PROGRESS,AT(8,290,584,8),USE(?SQLBarra),RANGE(0,100)
       STRING(''),AT(8,301,584,10),USE(?SQLTexto),FONT(,,0808080H)
"""
AVANCE_INIT = "    SQL.ProgressFeq = ?SQLBarra\n    SQL.ProgressTextFeq = ?SQLTexto\n"   # antes de conectar: muestra 'Conectando...'


def filter_window(title, avance=False):
    # con avance (MariaDB) la lista se achica y van la barra y el texto debajo
    lista_alto, extra, estado_y, alto = (258, AVANCE_CONTROLS, 316, 332) if avance else (270, "", 304, 320)
    return f"""\
[WINDOW]
Window WINDOW('{title}'),AT(,,600,{alto}),CENTER,GRAY,SYSTEM,MAX,FONT('Segoe UI',9)
       PROMPT('Desde:'),AT(8,10),USE(?L:Desde:Prompt)
       ENTRY(@d6),AT(34,8,50,12),USE(L:Desde)
       PROMPT('Hasta:'),AT(92,10),USE(?L:Hasta:Prompt)
       ENTRY(@d6),AT(116,8,50,12),USE(L:Hasta)
       PROMPT('Tipo:'),AT(174,10),USE(?L:Tipo:Prompt)
       ENTRY(@s3),AT(194,8,24,12),USE(L:Tipo),UPR
       PROMPT('Cliente:'),AT(226,10),USE(?L:Texto:Prompt)
       ENTRY(@s40),AT(256,8,120,12),USE(L:Texto)
       PROMPT('Maximo:'),AT(384,10),USE(?L:Max:Prompt)
       SPIN(@n6),AT(414,8,46,12),USE(L:Max),RANGE(1,100000),STEP(1000)
       BUTTON('&Buscar'),AT(486,6,52,16),USE(?Buscar),DEFAULT
       BUTTON('&Cerrar'),AT(542,6,50,16),USE(?Close),STD(STD:Close)
       LIST,AT(8,28,584,{lista_alto}),USE(?Lista),VSCROLL,FROM(CbtesQ), |
           FORMAT('{LIST_FORMAT}')
{extra}       STRING(@s250),AT(8,{estado_y},584,12),USE(L:Estado)
     END
"""


FILTER_DATA = CBTES_QUEUE + """
L:Desde              LONG
L:Hasta              LONG
L:Tipo               STRING(3)
L:Texto              STRING(40)
L:TextoE             STRING(90)
L:Max                LONG(30000)
L:Estado             STRING(250)
L:Query              CSTRING(4000)
L:Conn               CSTRING(1024)
L:T0                 LONG
L:T1                 LONG
L:T2                 LONG
L:Total              DECIMAL(19,2)
L:I                  LONG
L:Ok                 BYTE"""

OPEN_COMMON = """\
  L:Desde = DATE(1,1,YEAR(TODAY()))
  L:Hasta = TODAY()
  L:Conn = GETINI('Conexion','Cadena','',LONGPATH() & '\\TCWMariaDemo.ini')
  IF L:Conn = ''
    L:Estado = 'Falta la cadena de conexion en TCWMariaDemo.ini ([Conexion] Cadena=...)'
  ELSE
{connect}
  END
  DISPLAY()"""

BUSCAR_COMMON = """\
Buscar ROUTINE
  IF NOT L:Ok THEN EXIT.
  L:Query = 'SELECT {cols}' & |
            ' FROM cbtes WHERE Fecha BETWEEN ''' & FORMAT(L:Desde,@d10-) & ''' AND ''' & FORMAT(L:Hasta,@d10-) & ''''
  IF L:Tipo <> '' THEN L:Query = L:Query & ' AND TipoCbte = ' & {quote_tipo}.
  IF L:Texto <> '' THEN L:Query = L:Query & ' AND Descripcion LIKE ' & {quote_texto}.
  L:Query = L:Query & ' ORDER BY Fecha DESC, IdTransaccion DESC LIMIT ' & CHOOSE(L:Max > 0,L:Max,1000)
  SETCURSOR(CURSOR:Wait)
  FREE(CbtesQ)
  L:T0 = CLOCK()
  IF {obj}.ExecEx(L:Query,1)
    SETCURSOR()
    L:Estado = 'Error: ' & {error}
    DISPLAY()
    EXIT
  END
  L:T1 = CLOCK()
  {obj}.Col_Format(2,'@d10-')                         ! la fecha llega como aaaa-mm-dd
  {obj}.LoadQueue(CbtesQ,0,0)
  L:T2 = CLOCK()
  L:Total = 0
  LOOP L:I = 1 TO RECORDS(CbtesQ)
    GET(CbtesQ,L:I)
    L:Total += CBQ:Total
  END
  SETCURSOR()
  L:Estado = RECORDS(CbtesQ) & ' comprobantes  |  consulta ' & (L:T1 - L:T0) * 10 & ' ms + carga ' & (L:T2 - L:T1) * 10 & |
             ' ms = ' & (L:T2 - L:T0) * 10 & ' ms  |  Total: ' & CLIP(LEFT(FORMAT(L:Total,@n-20.2))) & '  |  {engine}'
  SELECT(?Lista,1)
  DISPLAY()

! comillas simples duplicadas y barra invertida escapada (MySQL)
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
  L:TextoE = E"""


def comprobantes(name, title, obj_decl, connect, quote_tipo, quote_texto, obj, error, engine, extra_close, avance=False):
    data = obj_decl + "\n" + FILTER_DATA
    proc = f"""[PROCEDURE]
NAME {name}
[COMMON]
FROM ABC Window
{STAMP}
[EMBED]
"""
    proc += embed("%DataSection", data)
    open_code = OPEN_COMMON.format(connect=connect)
    proc += (f"EMBED %WindowEventHandling\n[INSTANCES]\nWHEN 'OpenWindow'\n[DEFINITION]\n[SOURCE]\nPROPERTY:BEGIN\nPRIORITY 8000\n"
             f"PROPERTY:END\n{open_code}\n  IF L:Ok THEN DO Buscar.\n[END]\n"
             f"WHEN 'CloseWindow'\n[DEFINITION]\n[SOURCE]\nPROPERTY:BEGIN\nPRIORITY 2000\nPROPERTY:END\n{extra_close}\n[END]\n[END]\n")
    proc += embed("%ControlEventHandling", "  UPDATE()\n  DO Buscar", when="?Buscar", when2="Accepted")
    proc += embed("%ProcedureRoutines", BUSCAR_COMMON.format(cols=COLS, quote_tipo=quote_tipo, quote_texto=quote_texto,
                                                            obj=obj, error=error, engine=engine))
    proc += "[END]\n" + filter_window(title, avance)
    return proc


MARIA = comprobantes(
    "Comprobantes", "Comprobantes - SQLMariaClass (MariaDB directo, sin ODBC)",
    "SQL                  SQLMariaClass",
    "    SQL.SilentMode = True\n" + AVANCE_INIT + "    IF SQL.InitMaria(L:Conn)\n      L:Estado = 'No se pudo conectar: ' & SQL.ErrorText()\n"
    "    ELSE\n      SQL.KeepCase = True\n      L:Ok = True\n    END",
    "SQL.Quote(CLIP(L:Tipo))", "SQL.Quote('<37>' & CLIP(L:Texto) & '<37>')",
    "SQL", "SQL.ErrorText()", "SQLMariaClass directo - MySQL ' & SQL.ServerVersion() & '", "  SQL.Kill()", avance=True)

ODBC = comprobantes(
    "ComprobantesOdbc", "Comprobantes - SQLClass6 + driver ODBC (MySQL ODBC 5.1)",
    "SQLO                 SQLOdbcClass",
    "    SQLO.SilentMode = True\n    IF SQLO.Init(SQLOdbcFile,SQF:Record,L:Conn)\n      L:Estado = 'No se pudo abrir la conexion ODBC'\n"
    "    ELSE\n      L:Ok = True\n    END",
    "'''' & CLIP(L:Tipo) & ''''", "'''<37>' & CLIP(L:TextoE) & '<37>'''",
    "SQLO", "'ver el mensaje del driver ODBC'", "SQLClass6 + driver ODBC (tabla sqlclass, 25 campos de 49)", "  SQLO.Kill()")
# en ODBC el texto se escapa antes con la rutina Esc
ODBC = ODBC.replace("  IF L:Texto <> '' THEN L:Query = L:Query & ' AND Descripcion LIKE '",
                    "  IF L:Texto <> '' THEN DO Esc.\n  IF L:Texto <> '' THEN L:Query = L:Query & ' AND Descripcion LIKE '")

# Por paginas (keyset): la primera pagina sale enseguida y las siguientes se piden al llegar al final del LIST.
# La pagina siguiente continua desde la ultima fila cargada: (Fecha, IdTransaccion) < (ultima Fecha, ultimo Id).
# No usa OFFSET: con 500 mil filas el servidor recorreria y descartaria las anteriores en cada pagina.
# CBQ:FechaSql guarda la fecha tal como la manda el servidor (no se muestra) para comparar sin perder la hora.
PAGINAS_DATA = "SQL                  SQLMariaClass\n" + CBTES_QUEUE.replace(
    "                     END", "FechaSql               STRING(30)\n                     END") + """
L:Desde              LONG
L:Hasta              LONG
L:Tipo               STRING(3)
L:Texto              STRING(40)
L:Pagina             LONG(200)
L:Contar             BYTE(1)
L:Estado             STRING(250)
L:Where              CSTRING(1000)
L:Query              CSTRING(2000)
L:Conn               CSTRING(1024)
L:T0                 LONG
L:MsPrimera          LONG
L:MsUltima           LONG
L:MsConteo           LONG
L:Paginas            LONG
L:Hay                LONG
L:Antes              LONG
L:UltFecha           STRING(30)
L:UltId              LONG
L:Total              DECIMAL(19,2)
L:I                  LONG
L:Ok                 BYTE
L:Fin                BYTE
L:Dif                LONG
L:N                  LONG
L:T1                 LONG
L:MsPaginas          LONG"""

PAGINAS_ROUTINES = f"""\
! arma el filtro, cuenta (opcional) y trae la primera pagina
Buscar ROUTINE
  IF NOT L:Ok THEN EXIT.
  IF L:Pagina < 1 THEN L:Pagina = 200.
  L:Where = 'Fecha BETWEEN ''' & FORMAT(L:Desde,@d10-) & ''' AND ''' & FORMAT(L:Hasta,@d10-) & ''''
  IF L:Tipo <> '' THEN L:Where = L:Where & ' AND TipoCbte = ' & SQL.Quote(CLIP(L:Tipo)).
  IF L:Texto <> '' THEN L:Where = L:Where & ' AND Descripcion LIKE ' & SQL.Quote('<37>' & CLIP(L:Texto) & '<37>').
  FREE(CbtesQ)
  L:Fin = False
  L:Paginas = 0
  L:Total = 0
  L:Hay = -1
  L:MsConteo = 0
  IF L:Contar
    SETCURSOR(CURSOR:Wait)
    L:T0 = CLOCK()
    IF NOT SQL.ExecEx('SELECT COUNT(*) FROM cbtes WHERE ' & L:Where,1)
      IF SQL.Next() = Level:Benign THEN L:Hay = SQL.Col(1).
    END
    L:MsConteo = (CLOCK() - L:T0) * 10
    SETCURSOR()
  END
  DO Siguiente
  L:MsPrimera = L:MsUltima
  SELECT(?Lista,1)
  DISPLAY()

! trae la pagina que sigue a la ultima fila cargada y la agrega al final de la cola
Siguiente ROUTINE
  IF NOT L:Ok OR L:Fin THEN EXIT.
  L:Query = 'SELECT {COLS}, Fecha FROM cbtes WHERE ' & L:Where
  IF RECORDS(CbtesQ)
    L:Query = L:Query & ' AND Fecha <= ''' & CLIP(L:UltFecha) & ''' AND (Fecha < ''' & CLIP(L:UltFecha) & |
              ''' OR IdTransaccion < ' & L:UltId & ')'
  END
  L:Query = L:Query & ' ORDER BY Fecha DESC, IdTransaccion DESC LIMIT ' & L:Pagina
  L:Antes = RECORDS(CbtesQ)
  SETCURSOR(CURSOR:Wait)
  L:T0 = CLOCK()
  IF SQL.ExecEx(L:Query,1)
    SETCURSOR()
    L:Fin = True
    L:Estado = 'Error: ' & SQL.ErrorText()
    DISPLAY()
    EXIT
  END
  SQL.Col_Format(2,'@d10-')                           ! la fecha llega como aaaa-mm-dd
  SQL.LoadQueue(CbtesQ,0,0)                           ! FreeQueue = False: agrega a lo ya cargado
  L:MsUltima = (CLOCK() - L:T0) * 10
  SETCURSOR()
  L:Paginas += 1
  IF RECORDS(CbtesQ) - L:Antes < L:Pagina THEN L:Fin = True.
  LOOP L:I = L:Antes + 1 TO RECORDS(CbtesQ)
    GET(CbtesQ,L:I)
    L:Total += CBQ:Total
  END
  IF RECORDS(CbtesQ)
    GET(CbtesQ,RECORDS(CbtesQ))
    L:UltFecha = CBQ:FechaSql
    L:UltId = CBQ:IdTransaccion
  END
  DO Estado

! se llama desde el TIMER y al moverse en la lista: pide otra pagina si se ve el final de lo cargado
Mirar ROUTINE
  IF NOT L:Ok OR L:Fin OR NOT RECORDS(CbtesQ) THEN EXIT.
  IF ?Lista{{PROP:YOrigin}} + 2 * ?Lista{{PROP:Items}} >= RECORDS(CbtesQ)
    DO Siguiente
    DISPLAY(?Lista)
  END

Estado ROUTINE
  L:Estado = RECORDS(CbtesQ) & CHOOSE(L:Hay >= 0,' de ' & L:Hay,'') & ' comprobantes en ' & L:Paginas & ' paginas' & |
             CHOOSE(L:Fin,' (fin)','') & '  |  primera ' & L:MsPrimera & ' ms, ultima ' & L:MsUltima & ' ms' & |
             CHOOSE(L:Contar,', conteo ' & L:MsConteo & ' ms','') & '  |  Total cargado: ' & CLIP(LEFT(FORMAT(L:Total,@n-20.2)))
  DISPLAY(?L:Estado)

! modo automatico (TCWMariaDemo.exe paginas): carga ~5000 filas de a 137 y las compara, fila por fila,
! con una sola consulta del mismo orden; ninguna diferencia = la clave no saltea ni repite filas
Probar ROUTINE
  L:Pagina = 137
  L:Contar = False
  L:T1 = CLOCK()
  DO Buscar
  L:MsPrimera = (CLOCK() - L:T1) * 10
  LOOP WHILE NOT L:Fin AND RECORDS(CbtesQ) < 5000
    DO Siguiente
  END
  L:MsPaginas = (CLOCK() - L:T1) * 10
  L:Dif = 0
  L:I = 0
  IF SQL.ExecEx('SELECT IdTransaccion FROM cbtes WHERE ' & L:Where & ' ORDER BY Fecha DESC, IdTransaccion DESC LIMIT ' & RECORDS(CbtesQ),1)
    L:Dif = -1
  ELSE
    LOOP UNTIL SQL.Next()
      L:I += 1
      GET(CbtesQ,L:I)
      IF ERRORCODE() OR CBQ:IdTransaccion <> SQL.Col(1) THEN L:Dif += 1.
    END
    IF L:I <> RECORDS(CbtesQ) THEN L:Dif += 1.
  END
  SQL.LogFile = LONGPATH() & '\\paginas.txt'
  SQL.WriteLog(CLIP(L:Estado))
  SQL.WriteLog('Una sola consulta: ' & L:I & ' filas. Diferencias con la carga por paginas: ' & L:Dif)
  L:N = RECORDS(CbtesQ)
  SQL.WriteLog('Por paginas de 137: primera pagina en pantalla ' & L:MsPrimera & ' ms; ' & L:N & ' filas en ' & L:Paginas & |
               ' paginas ' & L:MsPaginas & ' ms')
  ! sin paginas: las mismas filas de una vez, y todo el filtro de una vez (lo que hace la pantalla MariaDB directo)
  FREE(CbtesQ)
  L:T1 = CLOCK()
  IF NOT SQL.ExecEx('SELECT {COLS}, Fecha FROM cbtes WHERE ' & L:Where & ' ORDER BY Fecha DESC, IdTransaccion DESC LIMIT ' & L:N,1)
    SQL.Col_Format(2,'@d10-')
    SQL.LoadQueue(CbtesQ,0,0)
  END
  SQL.WriteLog('Sin paginas, las mismas ' & RECORDS(CbtesQ) & ' filas de una vez: ' & (CLOCK() - L:T1) * 10 & ' ms')
  FREE(CbtesQ)
  L:T1 = CLOCK()
  IF NOT SQL.ExecEx('SELECT {COLS}, Fecha FROM cbtes WHERE ' & L:Where & ' ORDER BY Fecha DESC, IdTransaccion DESC',1)
    SQL.Col_Format(2,'@d10-')
    SQL.LoadQueue(CbtesQ,0,0)
  END
  SQL.WriteLog('Sin paginas, todo el filtro (' & RECORDS(CbtesQ) & ' filas) de una vez: ' & (CLOCK() - L:T1) * 10 & |
               ' ms hasta ver la primera fila')
  SQL.LogFile = ''"""

PAGINAS_OPEN = OPEN_COMMON.format(connect=(
    "    SQL.SilentMode = True\n" + AVANCE_INIT + "    IF SQL.InitMaria(L:Conn)\n      L:Estado = 'No se pudo conectar: ' & SQL.ErrorText()\n"
    "    ELSE\n      SQL.KeepCase = True\n      SQL.FreeQueue = False\n      L:Ok = True\n    END"))


def instance(when, code, priority):
    return f"WHEN '{when}'\n[DEFINITION]\n[SOURCE]\nPROPERTY:BEGIN\nPRIORITY {priority}\nPROPERTY:END\n{code.rstrip()}\n[END]\n"


# un solo EMBED por punto: varias instancias (WHEN) dentro del mismo bloque
PAGINAS = f"""[PROCEDURE]
NAME ComprobantesPaginas
[COMMON]
FROM ABC Window
{STAMP}
[EMBED]
""" + embed("%DataSection", PAGINAS_DATA) \
    + "EMBED %WindowEventHandling\n[INSTANCES]\n" \
    + instance("OpenWindow", PAGINAS_OPEN + "\n  IF INSTRING('PAGINAS',UPPER(COMMAND()),1,1)\n    DO Probar\n"
               "    POST(EVENT:CloseWindow)\n  ELSIF L:Ok\n    DO Buscar\n  END", 8000) \
    + instance("CloseWindow", "  SQL.Kill()", 2000) \
    + instance("Timer", "  DO Mirar", 4000) + "[END]\n" \
    + "EMBED %ControlEventHandling\n[INSTANCES]\n" \
    + "WHEN '?Buscar'\n[INSTANCES]\n" + instance("Accepted", "  UPDATE()\n  DO Buscar", 4000) + "[END]\n" \
    + "WHEN '?Lista'\n[INSTANCES]\n" + instance("NewSelection", "  DO Mirar", 4000) + "[END]\n[END]\n" \
    + embed("%ProcedureRoutines", PAGINAS_ROUTINES) + f"""[END]
[WINDOW]
Window WINDOW('Comprobantes por paginas - SQLMariaClass (carga al llegar al final de la lista)'),AT(,,600,332),CENTER,GRAY,SYSTEM,MAX,TIMER(25),FONT('Segoe UI',9)
       PROMPT('Desde:'),AT(8,10),USE(?L:Desde:Prompt)
       ENTRY(@d6),AT(34,8,50,12),USE(L:Desde)
       PROMPT('Hasta:'),AT(92,10),USE(?L:Hasta:Prompt)
       ENTRY(@d6),AT(116,8,50,12),USE(L:Hasta)
       PROMPT('Tipo:'),AT(174,10),USE(?L:Tipo:Prompt)
       ENTRY(@s3),AT(194,8,24,12),USE(L:Tipo),UPR
       PROMPT('Cliente:'),AT(226,10),USE(?L:Texto:Prompt)
       ENTRY(@s40),AT(256,8,100,12),USE(L:Texto)
       PROMPT('Pagina:'),AT(362,10),USE(?L:Pagina:Prompt)
       SPIN(@n5),AT(390,8,40,12),USE(L:Pagina),RANGE(10,5000),STEP(100)
       CHECK('Contar'),AT(436,9),USE(L:Contar)
       BUTTON('&Buscar'),AT(486,6,52,16),USE(?Buscar),DEFAULT
       BUTTON('&Cerrar'),AT(542,6,50,16),USE(?Close),STD(STD:Close)
       LIST,AT(8,28,584,258),USE(?Lista),VSCROLL,FROM(CbtesQ), |
           FORMAT('{LIST_FORMAT}')
{AVANCE_CONTROLS}       STRING(@s250),AT(8,316,584,12),USE(L:Estado)
     END
"""

N_ESC = 8
COMPARAR_DATA = CBTES_QUEUE + f"""
SQLM                SQLMariaClass
SQLO                 SQLOdbcClass
ResQ                 QUEUE,PRE(RQ)
Escenario              STRING(40)
Motor                  STRING(30)
Filas                  LONG
MsConsulta             LONG
MsCarga                LONG
MsTotal                LONG
Factor                 STRING(10)
Rapidez                STRING(10)
Igual                  STRING(10)
                     END
L:Max                LONG(30000)
L:Rep                LONG(5)
L:Estado             STRING(250)
L:Query              CSTRING(1000)
L:Conn               CSTRING(1024)
L:E                  LONG
L:EscNombre          STRING(40),DIM({N_ESC})
L:EscWhere           CSTRING(300),DIM({N_ESC})
L:R                  LONG
L:T0                 LONG
L:T1                 LONG
L:T2                 LONG
L:SumM               LONG,DIM(3)
L:SumO               LONG,DIM(3)
L:TotM               LONG
L:TotO               LONG
L:FilasM             LONG
L:FilasO             LONG
L:ImpM               DECIMAL(19,2)
L:ImpO               DECIMAL(19,2)
L:Auto               BYTE
L:I                  LONG
L:Y                  LONG
L:Version            STRING(40)
L:SumImp             DECIMAL(19,2)
L:Pct                LONG
L:Avance             LONG
L:Paso               LONG
L:Pasos              LONG
L:MotorTxt           STRING(20)"""

COMPARAR_ROUTINES = f"""\
! escenarios: sin filtro, filtros por indice (fecha, tipo, cliente) y LIKE '%texto%' (recorre toda la tabla)
Escenarios ROUTINE
  L:Y = YEAR(TODAY())
  L:EscNombre[1] = 'Sin filtro (ultimas ' & L:Max & ')'
  L:EscWhere[1]  = ''
  L:EscNombre[2] = 'Fecha: 1er semestre ' & L:Y
  L:EscWhere[2]  = ' WHERE Fecha BETWEEN ''' & FORMAT(DATE(1,1,L:Y),@d10-) & ''' AND ''' & FORMAT(DATE(6,30,L:Y),@d10-) & ''''
  L:EscNombre[3] = 'Tipo FC desde el 1/1/' & L:Y
  L:EscWhere[3]  = ' WHERE TipoCbte = ''FC'' AND Fecha >= ''' & FORMAT(DATE(1,1,L:Y),@d10-) & ''''
  L:EscNombre[4] = 'Razon social LIKE <37>SRL<37>'
  L:EscWhere[4]  = ' WHERE Descripcion LIKE ''<37>SRL<37>'''
  L:EscNombre[5] = 'Razon social LIKE <37>GARCIA<37>'
  L:EscWhere[5]  = ' WHERE Descripcion LIKE ''<37>GARCIA<37>'''
  L:EscNombre[6] = 'Un cliente (IdCliente 1000112)'
  L:EscWhere[6]  = ' WHERE IdCliente = 1000112'
  L:EscNombre[7] = 'Fecha: mes actual'
  L:EscWhere[7]  = ' WHERE Fecha BETWEEN ''' & FORMAT(DATE(MONTH(TODAY()),1,L:Y),@d10-) & ''' AND ''' & FORMAT(TODAY(),@d10-) & ''''
  L:EscNombre[8] = 'Un comprobante (por Id)'
  L:EscWhere[8]  = ' WHERE IdTransaccion = 970048800'

Comparar ROUTINE
  L:Conn = GETINI('Conexion','Cadena','',LONGPATH() & '\\TCWMariaDemo.ini')
  IF L:Conn = '' THEN L:Estado = 'Falta la cadena de conexion en TCWMariaDemo.ini'; DISPLAY(); EXIT.
  IF L:Max < 1 THEN L:Max = 30000.
  IF L:Rep < 1 THEN L:Rep = 1.
  SETCURSOR(CURSOR:Wait)
  FREE(ResQ)
  L:TotM = 0
  L:TotO = 0
  SQLM.SilentMode = True
  SQLO.SilentMode = True
  IF SQLM.InitMaria(L:Conn) THEN SETCURSOR(); L:Estado = 'MariaDB: ' & SQLM.ErrorText(); DISPLAY(); EXIT.
  SQLM.KeepCase = True
  IF SQLO.Init(SQLOdbcFile,SQF:Record,L:Conn) THEN SETCURSOR(); L:Estado = 'No se pudo abrir la conexion ODBC'; DISPLAY(); EXIT.
  DO Escenarios
  L:Paso = 0
  L:Pasos = {N_ESC} * (L:Rep + 1) * 2                ! escenarios x corridas (con la de calentamiento) x 2 motores
  L:Avance = 0
  DISPLAY(?L:Avance)
  LOOP L:E = 1 TO {N_ESC}
    L:Query = 'SELECT {COLS} FROM cbtes' & L:EscWhere[L:E] & ' ORDER BY Fecha DESC, IdTransaccion DESC LIMIT ' & L:Max
    L:SumM[1] = 0 ; L:SumM[2] = 0 ; L:SumM[3] = 0
    L:SumO[1] = 0 ; L:SumO[2] = 0 ; L:SumO[3] = 0
    LOOP L:R = 0 TO L:Rep                            ! la corrida 0 calienta la cache del servidor y no se cuenta
      IF L:R - 2 * INT(L:R / 2)                      ! se alterna quien va primero
        DO CorrerMaria
        DO CorrerOdbc
      ELSE
        DO CorrerOdbc
        DO CorrerMaria
      END
      IF L:R = 0
        L:SumM[1] = 0 ; L:SumM[2] = 0 ; L:SumM[3] = 0
        L:SumO[1] = 0 ; L:SumO[2] = 0 ; L:SumO[3] = 0
      END
    END
    DO AddResults
    DISPLAY(?Resultados)
  END
  L:Version = SQLM.ServerVersion()
  SQLM.Kill()
  SQLO.Kill()
  SETCURSOR()
  L:Avance = 100
  L:Estado = 'Todos los escenarios: MariaDB directo ' & L:TotM & ' ms, ODBC ' & L:TotO & ' ms' & |
             CHOOSE(L:TotM > 0,' (ODBC x ' & CLIP(LEFT(FORMAT(L:TotO / L:TotM,@n6.2))) & ', MariaDB ' & |
             CHOOSE(L:TotO >= L:TotM,ROUND((L:TotO / L:TotM - 1) * 100,1) & '% mas rapido', |
                    ROUND((L:TotM / L:TotO - 1) * 100,1) & '% mas lento') & ')','') & |
             '  -  promedio de ' & L:Rep & ' corridas, MySQL ' & CLIP(L:Version)
  DISPLAY()
  IF L:Auto THEN DO Guardar.

CorrerMaria ROUTINE
  L:MotorTxt = 'MariaDB directo'
  DO Avanzar
  FREE(CbtesQ)
  L:T0 = CLOCK()
  IF SQLM.ExecEx(L:Query,1) THEN L:Estado = 'MariaDB: ' & SQLM.ErrorText(); EXIT.
  L:T1 = CLOCK()
  SQLM.Col_Format(2,'@d10-')
  SQLM.LoadQueue(CbtesQ,0,0)
  L:T2 = CLOCK()
  L:SumM[1] += (L:T1 - L:T0) * 10 ; L:SumM[2] += (L:T2 - L:T1) * 10 ; L:SumM[3] += (L:T2 - L:T0) * 10
  DO Verificar
  L:FilasM = RECORDS(CbtesQ)
  L:ImpM = L:SumImp

CorrerOdbc ROUTINE
  L:MotorTxt = 'SQLClass6 + ODBC'
  DO Avanzar
  FREE(CbtesQ)
  L:T0 = CLOCK()
  IF SQLO.ExecEx(L:Query,1) THEN L:Estado = 'ODBC: error en la consulta'; EXIT.
  L:T1 = CLOCK()
  SQLO.Col_Format(2,'@d10-')
  SQLO.LoadQueue(CbtesQ,0,0)
  L:T2 = CLOCK()
  L:SumO[1] += (L:T1 - L:T0) * 10 ; L:SumO[2] += (L:T2 - L:T1) * 10 ; L:SumO[3] += (L:T2 - L:T0) * 10
  DO Verificar
  L:FilasO = RECORDS(CbtesQ)
  L:ImpO = L:SumImp

! una fila por motor con el promedio de las corridas; Factor = cuantas veces tarda ODBC lo que tarda MariaDB
AddResults ROUTINE
  RQ:Escenario = L:EscNombre[L:E]
  RQ:Motor = 'MariaDB directo'
  RQ:Filas = L:FilasM
  RQ:MsConsulta = L:SumM[1] / L:Rep ; RQ:MsCarga = L:SumM[2] / L:Rep ; RQ:MsTotal = L:SumM[3] / L:Rep
  RQ:Factor = ''
  RQ:Rapidez = ''
  RQ:Igual = CHOOSE(L:FilasM = L:FilasO AND L:ImpM = L:ImpO,'si','NO')
  ADD(ResQ)
  RQ:Escenario = ''
  RQ:Motor = 'SQLClass6 + ODBC'
  RQ:Filas = L:FilasO
  RQ:MsConsulta = L:SumO[1] / L:Rep ; RQ:MsCarga = L:SumO[2] / L:Rep ; RQ:MsTotal = L:SumO[3] / L:Rep
  RQ:Factor = CHOOSE(L:SumM[3] > 0,'x ' & CLIP(LEFT(FORMAT(L:SumO[3] / L:SumM[3],@n6.2))),'-')
  ! cuanto mas rapido es MariaDB (+) o mas lento (-) que ODBC: x 1.83 = +83%
  IF L:SumM[3] > 0
    L:Pct = ROUND((L:SumO[3] / L:SumM[3] - 1) * 100,1)
    RQ:Rapidez = CHOOSE(L:Pct > 0,'+','') & L:Pct & '%'
  ELSE
    RQ:Rapidez = '-'
  END
  RQ:Igual = ''
  ADD(ResQ)
  L:TotM += L:SumM[3] / L:Rep
  L:TotO += L:SumO[3] / L:Rep

! barra de avance: un paso por cada corrida de cada motor
Avanzar ROUTINE
  L:Paso += 1
  L:Avance = L:Paso * 100 / L:Pasos
  L:Estado = 'Escenario ' & L:E & ' de {N_ESC}: ' & CLIP(L:EscNombre[L:E]) & '  -  ' & |
             CHOOSE(L:R = 0,'calentamiento','corrida ' & L:R & ' de ' & L:Rep) & '  -  ' & CLIP(L:MotorTxt) & |
             '  (' & L:Avance & '%)'
  DISPLAY(?L:Avance)
  DISPLAY(?L:Estado)

! control de que los dos motores traen lo mismo: cantidad de filas y suma de importes
Verificar ROUTINE
  L:SumImp = 0
  LOOP L:I = 1 TO RECORDS(CbtesQ)
    GET(CbtesQ,L:I)
    L:SumImp += CBQ:Total
  END

! modo automatico (TCWMariaDemo.exe comparar): deja el resultado en comparacion.txt
Guardar ROUTINE
  SQLM.LogFile = LONGPATH() & '\\comparacion.txt'
  SQLM.WriteLog('Comparacion por escenario: maximo ' & L:Max & ' filas, promedio de ' & L:Rep & ' corridas')
  LOOP L:I = 1 TO RECORDS(ResQ)
    GET(ResQ,L:I)
    SQLM.WriteLog(FORMAT(RQ:Escenario,@s34) & ' ' & FORMAT(RQ:Motor,@s17) & ' filas ' & FORMAT(RQ:Filas,@n6) & |
                  '  consulta ' & FORMAT(RQ:MsConsulta,@n5) & '  carga ' & FORMAT(RQ:MsCarga,@n5) & '  total ' & FORMAT(RQ:MsTotal,@n5) & |
                  ' ms  ' & CLIP(RQ:Factor) & CHOOSE(RQ:Rapidez = '','','  MariaDB ' & CLIP(RQ:Rapidez)) & CHOOSE(RQ:Igual = '','','  mismo resultado: ' & RQ:Igual))
  END
  SQLM.WriteLog(CLIP(L:Estado))
  SQLM.LogFile = ''"""

COMPARAR = f"""[PROCEDURE]
NAME Comparar
[COMMON]
FROM ABC Window
{STAMP}
[EMBED]
""" + embed("%DataSection", COMPARAR_DATA) + f"""\
EMBED %WindowEventHandling
[INSTANCES]
WHEN 'OpenWindow'
[DEFINITION]
[SOURCE]
PROPERTY:BEGIN
PRIORITY 8000
PROPERTY:END
  L:Auto = CHOOSE(INSTRING('COMPARAR',UPPER(COMMAND()),1,1) > 0)
  IF L:Auto
    DO Comparar
    POST(EVENT:CloseWindow)
  END
[END]
[END]
""" + embed("%ControlEventHandling", "  UPDATE()\n  DO Comparar", when="?Comparar", when2="Accepted") \
    + embed("%ProcedureRoutines", COMPARAR_ROUTINES) + """[END]
[WINDOW]
Window WINDOW('Comparar tiempos por escenario - SQLMariaClass directo vs SQLClass6 + ODBC'),AT(,,600,294),CENTER,GRAY,SYSTEM,FONT('Segoe UI',9)
       PROMPT('Maximo de filas:'),AT(8,10),USE(?L:Max:Prompt)
       SPIN(@n6),AT(62,8,50,12),USE(L:Max),RANGE(1,500000),STEP(10000)
       PROMPT('Corridas:'),AT(122,10),USE(?L:Rep:Prompt)
       SPIN(@n2),AT(156,8,30,12),USE(L:Rep),RANGE(1,20)
       BUTTON('&Comparar'),AT(482,6,56,16),USE(?Comparar),DEFAULT
       BUTTON('C&errar'),AT(542,6,50,16),USE(?Close),STD(STD:Close)
       LIST,AT(8,28,584,212),USE(?Resultados),VSCROLL,FROM(ResQ), |
           FORMAT('132L(2)|M~Escenario~@s40@76L(2)|M~Motor~@s30@42R(2)|M~Filas~C(0)@n_8@54R(2)|M~Consulta (ms)~C(0)@n_8@48R(2)|M~Carga (ms)~C(0)@n_8@48R(2)|M~Total (ms)~C(0)@n_8@52C|M~ODBC / Maria~@s10@58C|M~Maria + rapida~@s10@34C|M~Igual~@s10@')
       STRING('Promedio por escenario. Igual = misma cantidad de filas y misma suma de importes. ODBC corta la razon social a 49 caracteres (tabla sqlclass).'),AT(8,244,584,10),USE(?Nota)
       STRING(@s250),AT(8,258,584,12),USE(L:Estado),FONT(,,,FONT:bold)
       PROGRESS,AT(8,274,584,10),USE(L:Avance),RANGE(0,100)
     END
"""

MAIN = f"""[PROCEDURE]
NAME Main
[COMMON]
FROM ABC Frame
CATEGORY 'Frame'
{STAMP}
[PROMPTS]
%ButtonAction DEPEND %Control DEFAULT TIMES 5
WHEN  ('?Ejemplos') ('Call a Procedure')
WHEN  ('?Maria') ('Call a Procedure')
WHEN  ('?Paginas') ('Call a Procedure')
WHEN  ('?Odbc') ('Call a Procedure')
WHEN  ('?Comparar') ('Call a Procedure')

%ButtonProcedure DEPEND %Control PROCEDURE TIMES 5
WHEN  ('?Ejemplos') (Ejemplos)
WHEN  ('?Maria') (Comprobantes)
WHEN  ('?Paginas') (ComprobantesPaginas)
WHEN  ('?Odbc') (ComprobantesOdbc)
WHEN  ('?Comparar') (Comparar)

%ButtonThread DEPEND %Control LONG TIMES 5
WHEN  ('?Ejemplos') (0)
WHEN  ('?Maria') (0)
WHEN  ('?Paginas') (0)
WHEN  ('?Odbc') (0)
WHEN  ('?Comparar') (0)
[EMBED]
""" + embed("%WindowEventHandling", "  IF INSTRING('COMPARAR',UPPER(COMMAND()),1,1)\n    Comparar()\n    POST(EVENT:CloseWindow)\n"
            "  ELSIF INSTRING('PAGINAS',UPPER(COMMAND()),1,1)\n    ComprobantesPaginas()\n    POST(EVENT:CloseWindow)\n"
            "  ELSIF INSTRING('MARIA',UPPER(COMMAND()),1,1)\n    Comprobantes()\n    POST(EVENT:CloseWindow)\n"
            "  ELSIF INSTRING('EJEMPLOS',UPPER(COMMAND()),1,1)\n    Ejemplos()\n    POST(EVENT:CloseWindow)\n  END",
            priority=8000, when="OpenWindow") + """[END]
[WINDOW]
AppFrame APPLICATION('TCWMariaDemo - SQLClass: MariaDB directo vs ODBC'),AT(,,420,250),CENTER,MASK,SYSTEM,MAX,RESIZE,FONT('Segoe UI',9)
       MENUBAR,USE(?Menubar)
         MENU('&Comprobantes'),USE(?ComprobantesMenu)
           ITEM('&MariaDB directo (SQLMariaClass)'),USE(?Maria)
           ITEM('MariaDB por &paginas (carga al bajar)'),USE(?Paginas)
           ITEM('&ODBC (SQLClass6 + MySQL ODBC 5.1)'),USE(?Odbc)
           ITEM,SEPARATOR,USE(?Sep1)
           ITEM('C&omparar tiempos'),USE(?Comparar)
           ITEM('&Ejemplos de uso (parametros, Insertar, lotes, transacciones...)'),USE(?Ejemplos)
           ITEM,SEPARATOR,USE(?Sep2)
           ITEM('&Salir'),USE(?Exit),STD(STD:Close)
         END
       END
     END
"""

GLOBAL_DATA = """\
SQLOdbcFile          FILE,DRIVER('ODBC'),NAME('sqlclass'),PRE(SQF),THREAD
Record                 RECORD
""" + "\n".join(f"F{i:<21}CSTRING(50)" for i in range(1, 26)) + """
                       END
                     END"""

HEADER = f"""[APPLICATION]
VERSION 34
TODO ABC ToDo
PROCEDURE Main
[COMMON]
FROM ABC
{STAMP}
[PROJECT]
#noedit
#system win32 exe
#model clarion dll
""" + "".join(f'#compile "TCWMariaDemo{n}.clw" -- GENERATED\n' for n in ["", "001", "002", "003", "004", "005", "006"]) + """\
#pragma link("libmariadb.lib")
#pragma define(StringTheoryLinkMode=>1)
#pragma define(StringTheoryDLLMode=>0)
#link "TCWMariaDemo.exe"
[PROGRAM]
NAME 'TCWMariaDemo.clw'
[COMMON]
FROM ABC ABC
""" + STAMP + "\n[EMBED]\n" + embed("%AfterGlobalIncludes", "  INCLUDE('SQLClass6Maria.inc'),ONCE") \
    + embed("%GlobalData", GLOBAL_DATA) + "[END]\n[END]\n"

# pantalla Ejemplos (ejemplos.py; se ejecuta aparte porque python -I no agrega esta carpeta al path)
_ns = {}
exec(Path(__file__).with_name("ejemplos.py").read_text(encoding="utf-8"), _ns)
EJEMPLOS = _ns["EJEMPLOS"]

txa = HEADER + module(1, MAIN) + module(2, MARIA) + module(3, ODBC) + module(4, COMPARAR) + module(5, PAGINAS) + module(6, EJEMPLOS)
Path(__file__).with_name("TCWMariaDemo.txa").write_text(txa, encoding="utf-8", newline="\r\n")
print("TCWMariaDemo.txa:", len(txa), "bytes")

"""Procedimiento Ejemplos de TCWMariaDemo: una pestana por cada uso de SQLMariaClass, con el codigo a la vista.

Lo importa make-demo-txa.py (EJEMPLOS = procedimiento TXA). Las escrituras van a tablas TEMPORARY (tcw_demo,
tcw_demo_lote; InnoDB para que haya transacciones): viven solo en la conexion de la ventana y no tocan la base.
TCWMariaDemo.exe ejemplos corre las siete pestanas y deja el resultado en ejemplos.txt.
"""

STAMP = "MODIFIED '2026/10/29' '12:00:00'"


def clar_lines(var, lines):
    """Asigna un texto de varias lineas a una variable Clarion (escapa ' < { y une con <13,10>)."""
    out = []
    for i, ln in enumerate(lines):
        t = ln.replace("'", "''").replace("<", "<<").replace("{", "{{")
        sep = "<13,10>" if i < len(lines) - 1 else ""
        out.append(f"'{t}{sep}'")
    return f"  {var} = " + " & |\n           ".join(out)


# --- el codigo que se muestra en cada pestana (es el mismo que ejecuta la pestana)
COD = {
    1: ["! parametros '?': cada valor se escapa y va entre comillas solo (mysql_real_escape_string)",
        "SQL.AddParam(L:Cliente)",
        "SQL.AddParam(FORMAT(L:Desde,@d10-))",
        "IF SQL.ExecEx('SELECT IdTransaccion, Fecha, TipoCbte, NroCbte, Descripcion, ImporteTotal' & |",
        "              ' FROM cbtes WHERE IdCliente = ? AND Fecha >= ? ORDER BY Fecha DESC LIMIT 200',1)",
        "  MESSAGE(SQL.ErrorText())",
        "END",
        "LOOP UNTIL SQL.Next()",
        "  ! SQL.Col(1), SQL.ColByName('Descripcion')...",
        "END"],
    2: ["! INSERT por nombre de campo: sin comillas, Clip ni Fun_Date",
        "SQL.Campo('Nombre',L:Nombre)                    ! una ' o una \" adentro no rompe nada",
        "SQL.Campo('Importe',L:Importe)",
        "SQL.CampoFecha('Fecha',L:Fecha)                 ! fecha de Clarion; 0 = NULL",
        "SQL.CampoFechaHora('Hora',TODAY(),CLOCK())",
        "SQL.CampoNulo('Nota')",
        "IF SQL.Insertar('tcw_demo') THEN MESSAGE(SQL.ErrorText()).",
        "",
        "! Insertar arma INSERT INTO tabla (...) VALUES (...) con cada valor escapado:",
        "! una ' o una \\ en el texto no rompen la sentencia."],
    3: ["! muchas filas: InsertarLote arma un INSERT de varias filas (de a 500, hasta 512 KB)",
        "LOOP I = 1 TO Cantidad",
        "  SQL.Campo('Id',I)",
        "  SQL.Campo('Nombre','Cliente ' & I)",
        "  SQL.Campo('Importe',I * 1.25)",
        "  SQL.CampoFecha('Fecha',TODAY() - I % 365)",
        "  IF SQL.InsertarLote('tcw_demo_lote') THEN BREAK.",
        "END",
        "SQL.EnviarLote()                                ! las que quedan (SQL.Db.BatchSize = 500)",
        "",
        "! Se compara con el INSERT armado como texto (como con PROP:SQL) y con Insertar fila por fila."],
    4: ["! sentencia preparada: se guarda una vez y los '?' se reemplazan al ejecutar",
        "! (MySQL 5.0 no tiene arreglos de parametros: AddRow con un INSERT arma uno de varias filas)",
        "SQL.Prepare('UPDATE tcw_demo_lote SET Importe = Importe * ? WHERE MOD(Id, ?) = 0')",
        "SQL.AddParam('2') ; SQL.AddParam('10')",
        "SQL.ExecPrepared()                              ! SQL.AffectedRows() = filas cambiadas",
        "SQL.AddParam('0.5') ; SQL.AddParam('10')",
        "SQL.ExecPrepared()                              ! misma sentencia, otros valores",
        "",
        "! Para un lote: AddParam de cada valor + SQL.AddRow() por fila, y SQL.ExecPrepared() al final."],
    5: ["SQL.BeginTransaction()",
        "SQL.ExecEx('DELETE FROM tcw_demo_lote',1)",
        "! ... dentro de la transaccion la tabla esta vacia ...",
        "SQL.Rollback()                                  ! o SQL.Commit()",
        "",
        "! Equivale a LOGOUT / ROLLBACK (o COMMIT) del driver de Clarion. La tabla tiene que ser InnoDB",
        "! (en MyISAM no hay transacciones)."],
    6: ["! dos SELECT en una sola consulta (igual con ExecSP('CALL sp(?)') si el procedimiento devuelve varios)",
        "SQL.AddParam(L:Cliente2) ; SQL.AddParam(L:Cliente2)",
        "IF SQL.ExecEx('SELECT TipoCbte, COUNT(*) AS Cantidad, SUM(ImporteTotal) AS Total FROM cbtes' & |",
        "              ' WHERE IdCliente = ? GROUP BY TipoCbte ORDER BY TipoCbte;' & |",
        "              ' SELECT IdTransaccion, Fecha, TipoCbte, NroCbte, ImporteTotal FROM cbtes' & |",
        "              ' WHERE IdCliente = ? ORDER BY Fecha DESC, IdTransaccion DESC LIMIT 10',1)",
        "  MESSAGE(SQL.ErrorText())",
        "END",
        "LOOP UNTIL SQL.Next()                           ! resultado 1: resumen por tipo",
        "END",
        "IF SQL.NextResult() = Level:Benign              ! resultado 2: ultimos 10 comprobantes",
        "  LOOP UNTIL SQL.Next()",
        "  END",
        "END"],
    7: ["! MEDIUMTEXT: se graba y se lee entero (sin el limite de 49 de la tabla sqlclass)",
        "SQL.Campo('Nombre','Texto largo')",
        "SQL.Campo('Importe',0)",
        "SQL.Campo('Nota',ALL('0123456789',L:Largo))",
        "SQL.Insertar('tcw_demo')",
        "SQL.ExecEx('SELECT CHAR_LENGTH(Nota), Nota FROM tcw_demo ORDER BY Id DESC LIMIT 1',1)",
        "SQL.Next()",
        "Texto = SQL.Col(2)                              ! los " + "L:Largo caracteres"],
}

DATA = """SQL                  SQLMariaClass
ResQ                 QUEUE,PRE(RQ)
Linea                  STRING(250)
                     END
L:Conn               CSTRING(1024)
L:Ok                 BYTE
L:Txt                STRING(250)
L:Titulo             STRING(60)
L:Auto               BYTE
L:Cliente            LONG(1000112)
L:Cliente2           LONG(1000112)
L:Desde              LONG
L:Nombre             STRING(60)
L:Importe            DECIMAL(12,2)
L:Fecha              LONG
L:Cantidad           LONG(5000)
L:Largo              LONG(20000)
L:Metodo             STRING(45),DIM(3)
L:M                  LONG
L:I                  LONG
L:N                  LONG
L:T0                 LONG
L:Ms                 LONG
L:Base               LONG
L:Hay                LONG
L:Feq1               LONG
L:Feq2               LONG
""" + "".join(f"L:Cod{i:<17}STRING(1500)\n" for i in range(1, 8))

OPEN = """  L:Desde = DATE(1,1,YEAR(TODAY()) - 1)
  L:Nombre = 'O''Brien "el de las comillas"'
  L:Importe = 1234.56
  L:Fecha = TODAY()
  L:Metodo[1] = 'INSERT armado como texto (como PROP:SQL)'
  L:Metodo[2] = 'Insertar (una fila por viaje)'
  L:Metodo[3] = 'InsertarLote (INSERT de 500 filas)'
""" + "\n".join(clar_lines(f"L:Cod{i}", COD[i]) for i in range(1, 8)) + """
  L:Conn = GETINI('Conexion','Cadena','',LONGPATH() & '\\TCWMariaDemo.ini')
  IF L:Conn = ''
    ?SQLTexto{PROP:Text} = 'Falta la cadena de conexion en TCWMariaDemo.ini ([Conexion] Cadena=Server=...;Database=...;User=...;Password=...)'
  ELSE
    SQL.SilentMode = True
    SQL.ProgressFeq = ?SQLBarra
    SQL.ProgressTextFeq = ?SQLTexto
    IF SQL.InitMaria(L:Conn) = Level:Benign
      SQL.KeepCase = True
      L:Ok = True
      ! tablas TEMPORARY (solo de esta conexion; no tocan la base); InnoDB para que haya transacciones
      SQL.ExecEx('CREATE TEMPORARY TABLE IF NOT EXISTS tcw_demo (Id INT AUTO_INCREMENT PRIMARY KEY, Nombre VARCHAR(60), ' & |
                 'Importe DECIMAL(12,2), Fecha DATE NULL, Hora DATETIME NULL, Nota MEDIUMTEXT NULL) ENGINE=InnoDB',1)
      SQL.ExecEx('CREATE TEMPORARY TABLE IF NOT EXISTS tcw_demo_lote (Id INT PRIMARY KEY, Nombre VARCHAR(50), ' & |
                 'Importe DECIMAL(12,2), Fecha DATE NULL) ENGINE=InnoDB',1)
    END
  END
  DISPLAY()
  L:Auto = CHOOSE(INSTRING('EJEMPLOS',UPPER(COMMAND()),1,1) > 0)
  IF L:Auto AND L:Ok
    L:Cantidad = 2000
    L:Titulo = '1. Parametros' ; DO Param ; DO Volcar
    L:Titulo = '2. Insertar' ; DO Insert ; DO Volcar
    L:Titulo = '3. InsertarLote (2000 filas)' ; DO Lote ; DO Volcar
    L:Titulo = '4. Prepare' ; DO Prepara ; DO Volcar
    L:Titulo = '5. Transaccion' ; DO Trans ; DO Volcar
    L:Titulo = '6. Varios resultados' ; DO Varios ; DO Volcar
    L:Titulo = '7. Texto largo' ; DO Largo ; DO Volcar
    POST(EVENT:CloseWindow)
  END"""

ROUTINES = """Agregar ROUTINE
  RQ:Linea = L:Txt
  ADD(ResQ)

MostrarError ROUTINE
  L:Txt = 'ERROR: ' & SQL.ErrorText()
  DO Agregar

! modo automatico (TCWMsSQLDemo.exe ejemplos): agrega lo que muestra la lista a ejemplos.txt
Volcar ROUTINE
  SQL.LogFile = LONGPATH() & '\\ejemplos.txt'
  SQL.WriteLog('== ' & CLIP(L:Titulo))
  LOOP L:I = 1 TO RECORDS(ResQ)
    GET(ResQ,L:I)
    SQL.WriteLog('   ' & CLIP(RQ:Linea))
  END
  SQL.LogFile = ''

! 1. parametros '?'
Param ROUTINE
  FREE(ResQ)
  L:T0 = CLOCK()
  SQL.AddParam(L:Cliente)
  SQL.AddParam(FORMAT(L:Desde,@d10-))
  IF SQL.ExecEx('SELECT IdTransaccion, Fecha, TipoCbte, NroCbte, Descripcion, ImporteTotal' & |
                ' FROM cbtes WHERE IdCliente = ? AND Fecha >= ? ORDER BY Fecha DESC, IdTransaccion DESC LIMIT 200',1)
    DO MostrarError
    EXIT
  END
  L:N = 0
  LOOP UNTIL SQL.Next()
    L:N += 1
    L:Txt = FORMAT(SQL.Col(1),@n_10) & '  ' & SQL.Col(2) & '  ' & FORMAT(SQL.Col(3),@s4) & FORMAT(SQL.Col(4),@n_9) & '  ' & |
            FORMAT(SQL.ColByName('Descripcion'),@s45) & FORMAT(SQL.Col(6),@n-16.2)
    DO Agregar
  END
  RQ:Linea = L:N & ' comprobantes del cliente ' & L:Cliente & ' desde el ' & FORMAT(L:Desde,@d6) & ' en ' & (CLOCK() - L:T0) * 10 & |
             ' ms (dos parametros ?, escapados solos)'
  ADD(ResQ,1)

! 2. INSERT por nombre de campo
Insert ROUTINE
  FREE(ResQ)
  SQL.Campo('Nombre',L:Nombre)
  SQL.Campo('Importe',L:Importe)
  SQL.CampoFecha('Fecha',L:Fecha)
  SQL.CampoFechaHora('Hora',TODAY(),CLOCK())
  SQL.CampoNulo('Nota')
  IF SQL.Insertar('tcw_demo')
    DO MostrarError
    EXIT
  END
  L:Txt = 'Insertado. Ultimas filas de tcw_demo (Id, Nombre, Importe, Fecha, Hora, Nota):'
  DO Agregar
  DO MostrarDemo

MostrarDemo ROUTINE
  IF SQL.ExecEx('SELECT Id, Nombre, Importe, Fecha, DATE_FORMAT(Hora,''<37>Y-<37>m-<37>d <37>H:<37>i:<37>s''), ' & |
                'CASE WHEN Nota IS NULL THEN ''(NULL)'' ELSE CONCAT(CHAR_LENGTH(Nota), '' caracteres'') END' & |
                ' FROM tcw_demo ORDER BY Id DESC LIMIT 15',1)
    DO MostrarError
    EXIT
  END
  LOOP UNTIL SQL.Next()
    L:Txt = FORMAT(SQL.Col(1),@n6) & '  ' & FORMAT(SQL.Col(2),@s36) & FORMAT(SQL.Col(3),@n-12.2) & '  ' & |
            FORMAT(SQL.Col(4),@s11) & FORMAT(SQL.Col(5),@s20) & SQL.Col(6)
    DO Agregar
  END

! 3. tres formas de grabar las mismas filas; la barra la mueve esta rutina (la de la clase se apaga para no
!    sumarle a la forma 1 el repintado de cada consulta)
Lote ROUTINE
  FREE(ResQ)
  IF L:Cantidad < 1 THEN L:Cantidad = 1000.
  L:Feq1 = SQL.ProgressFeq
  L:Feq2 = SQL.ProgressTextFeq
  SQL.ProgressFeq = 0
  SQL.ProgressTextFeq = 0
  L:Base = 0
  LOOP L:M = 1 TO 3
    SQL.ExecEx('TRUNCATE TABLE tcw_demo_lote',1)
    L:T0 = CLOCK()
    LOOP L:I = 1 TO L:Cantidad
      IF L:M = 1
        IF SQL.ExecEx('INSERT INTO tcw_demo_lote (Id, Nombre, Importe, Fecha) VALUES (' & L:I & ', ' & |
                      SQL.Quote('Cliente ' & L:I) & ', ' & L:I * 1.25 & ', ''' & FORMAT(TODAY() - L:I % 365,@d10-) & ''')',1)
          DO MostrarError
          BREAK
        END
      ELSE
        SQL.Campo('Id',L:I)
        SQL.Campo('Nombre','Cliente ' & L:I)
        SQL.Campo('Importe',L:I * 1.25)
        SQL.CampoFecha('Fecha',TODAY() - L:I % 365)
        IF L:M = 2
          IF SQL.Insertar('tcw_demo_lote') THEN DO MostrarError ; BREAK.
        ELSE
          IF SQL.InsertarLote('tcw_demo_lote') THEN DO MostrarError ; BREAK.
        END
      END
      IF L:I % 250 = 0
        ?SQLBarra{PROP:Progress} = L:I * 100 / L:Cantidad
        ?SQLTexto{PROP:Text} = CLIP(L:Metodo[L:M]) & ': ' & L:I & ' de ' & L:Cantidad & ' filas'
        DISPLAY(?SQLBarra)
        DISPLAY(?SQLTexto)
      END
    END
    IF L:M = 3 AND SQL.EnviarLote() THEN DO MostrarError.
    L:Ms = (CLOCK() - L:T0) * 10
    IF L:M = 1 THEN L:Base = L:Ms.
    L:Hay = SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_demo_lote')
    L:Txt = FORMAT(L:Metodo[L:M],@s44) & FORMAT(L:Ms,@n8) & ' ms' & FORMAT(CHOOSE(L:Ms > 0,L:Cantidad * 1000 / L:Ms,0),@n9) & ' filas/s' & |
            CHOOSE(L:M > 1 AND L:Ms > 0,'   ' & CLIP(LEFT(FORMAT(L:Base / L:Ms,@n6.1))) & ' veces mas rapido','') & |
            CHOOSE(L:Hay = L:Cantidad,'','   (grabo ' & L:Hay & ')')
    DO Agregar
    DISPLAY(?Res)
  END
  SQL.ProgressFeq = L:Feq1
  SQL.ProgressTextFeq = L:Feq2
  ?SQLBarra{PROP:Progress} = 100
  ?SQLTexto{PROP:Text} = 'Listo: ' & L:Cantidad & ' filas de cada forma en tcw_demo_lote'
  DISPLAY()

! 4. sentencia preparada, dos veces con otros valores
Prepara ROUTINE
  FREE(ResQ)
  IF SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_demo_lote') = 0
    LOOP L:I = 1 TO 1000
      SQL.Campo('Id',L:I)
      SQL.Campo('Nombre','Cliente ' & L:I)
      SQL.Campo('Importe',L:I * 1.25)
      SQL.CampoFecha('Fecha',TODAY() - L:I % 365)
      SQL.InsertarLote('tcw_demo_lote')
    END
    SQL.EnviarLote()
  END
  L:Txt = 'Antes:   ' & SQL.Fetch(1,'SELECT CONCAT(COUNT(*), '' filas, suma '', SUM(Importe)) FROM tcw_demo_lote')
  DO Agregar
  IF SQL.Prepare('UPDATE tcw_demo_lote SET Importe = Importe * ? WHERE MOD(Id, ?) = 0')
    DO MostrarError
    EXIT
  END
  SQL.AddParam('2')
  SQL.AddParam('10')
  IF SQL.ExecPrepared() THEN DO MostrarError ; EXIT.
  L:Txt = 'ExecPrepared con 2 y 10:   ' & SQL.AffectedRows() & ' filas (Importe x 2 donde Id es multiplo de 10)'
  DO Agregar
  L:Txt = '         ' & SQL.Fetch(1,'SELECT CONCAT(COUNT(*), '' filas, suma '', SUM(Importe)) FROM tcw_demo_lote')
  DO Agregar
  SQL.AddParam('0.5')
  SQL.AddParam('10')
  IF SQL.ExecPrepared() THEN DO MostrarError ; EXIT.
  L:Txt = 'ExecPrepared con 0.5 y 10: ' & SQL.AffectedRows() & ' filas (misma sentencia, otros valores: vuelve al importe original)'
  DO Agregar
  L:Txt = 'Despues: ' & SQL.Fetch(1,'SELECT CONCAT(COUNT(*), '' filas, suma '', SUM(Importe)) FROM tcw_demo_lote')
  DO Agregar

! 5. transaccion con rollback
Trans ROUTINE
  FREE(ResQ)
  L:Txt = 'Filas antes:                     ' & SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_demo_lote')
  DO Agregar
  IF SQL.BeginTransaction() THEN DO MostrarError ; EXIT.
  SQL.ExecEx('DELETE FROM tcw_demo_lote',1)
  L:Txt = 'BeginTransaction + DELETE:       borradas ' & SQL.AffectedRows() & ', quedan ' & SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_demo_lote')
  DO Agregar
  IF SQL.Rollback() THEN DO MostrarError ; EXIT.
  L:Txt = 'Rollback:                        quedan ' & SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_demo_lote') & ' (no se borro nada)'
  DO Agregar

! 6. procedimiento con dos resultados
Varios ROUTINE
  FREE(ResQ)
  SQL.AddParam(L:Cliente2)
  SQL.AddParam(L:Cliente2)
  IF SQL.ExecEx('SELECT TipoCbte, COUNT(*) AS Cantidad, SUM(ImporteTotal) AS Total FROM cbtes' & |
                ' WHERE IdCliente = ? GROUP BY TipoCbte ORDER BY TipoCbte;' & |
                ' SELECT IdTransaccion, Fecha, TipoCbte, NroCbte, ImporteTotal FROM cbtes' & |
                ' WHERE IdCliente = ? ORDER BY Fecha DESC, IdTransaccion DESC LIMIT 10',1)
    DO MostrarError
    EXIT
  END
  L:Txt = 'Resultado 1 (' & CLIP(SQL.Field(1)) & ', ' & CLIP(SQL.Field(2)) & ', ' & CLIP(SQL.Field(3)) & '): resumen por tipo del cliente ' & L:Cliente2
  DO Agregar
  LOOP UNTIL SQL.Next()
    L:Txt = '   ' & FORMAT(SQL.Col(1),@s5) & FORMAT(SQL.Col(2),@n8) & ' comprobantes' & FORMAT(SQL.Col(3),@n-20.2)
    DO Agregar
  END
  IF SQL.NextResult() = Level:Benign
    L:Txt = 'Resultado 2 (' & SQL.Columns() & ' columnas): los ultimos 10'
    DO Agregar
    LOOP UNTIL SQL.Next()
      L:Txt = '   ' & FORMAT(SQL.Col(1),@n_10) & '  ' & SQL.Col(2) & '  ' & FORMAT(SQL.Col(3),@s4) & FORMAT(SQL.Col(4),@n_9) & FORMAT(SQL.Col(5),@n-16.2)
      DO Agregar
    END
  END

! 7. varchar(max)
Largo ROUTINE
  FREE(ResQ)
  IF L:Largo < 1 THEN L:Largo = 20000.
  SQL.Campo('Nombre','Texto de ' & L:Largo & ' caracteres')
  SQL.Campo('Importe',0)
  SQL.Campo('Nota',ALL('0123456789',L:Largo))
  IF SQL.Insertar('tcw_demo')
    DO MostrarError
    EXIT
  END
  IF SQL.ExecEx('SELECT CHAR_LENGTH(Nota), Nota FROM tcw_demo ORDER BY Id DESC LIMIT 1',1) THEN DO MostrarError ; EXIT.
  SQL.Next()
  L:N = LEN(SQL.Col(2))
  L:Txt = 'Grabado: ' & SQL.Col(1) & ' caracteres en el servidor; leido: ' & L:N & CHOOSE(SQL.Col(2) = ALL('0123456789',L:Largo),' (identico)',' (DISTINTO)')
  DO Agregar
  DO MostrarDemo"""


def tab(n, title, inputs, button):
    return (f"           TAB('{title}'),USE(?Tab{n})\n{inputs}"
            f"             BUTTON('{button}'),AT(564,20,64,16),USE(?Run{n})\n"
            f"             TEXT,AT(10,42,618,130),USE(L:Cod{n}),SKIP,FONT('Consolas',8),VSCROLL,READONLY\n"
            f"           END\n")


TABS = (
    tab(1, '1. Parametros ?',
        "             PROMPT('Cliente:'),AT(12,24),USE(?L:Cliente:Prompt)\n"
        "             ENTRY(@n_10),AT(42,22,50,12),USE(L:Cliente)\n"
        "             PROMPT('Desde:'),AT(102,24),USE(?L:Desde:Prompt)\n"
        "             ENTRY(@d6),AT(128,22,52,12),USE(L:Desde)\n", '&Buscar')
    + tab(2, '2. Insertar',
          "             PROMPT('Nombre:'),AT(12,24),USE(?L:Nombre:Prompt)\n"
          "             ENTRY(@s60),AT(42,22,200,12),USE(L:Nombre)\n"
          "             PROMPT('Importe:'),AT(250,24),USE(?L:Importe:Prompt)\n"
          "             ENTRY(@n-12.2),AT(282,22,60,12),USE(L:Importe)\n"
          "             PROMPT('Fecha:'),AT(350,24),USE(?L:Fecha:Prompt)\n"
          "             ENTRY(@d6),AT(376,22,52,12),USE(L:Fecha)\n", '&Insertar')
    + tab(3, '3. InsertarLote',
          "             PROMPT('Filas:'),AT(12,24),USE(?L:Cantidad:Prompt)\n"
          "             SPIN(@n7),AT(42,22,60,12),USE(L:Cantidad),RANGE(100,200000),STEP(1000)\n"
          "             PROMPT('Graba las mismas filas de tres formas y compara los tiempos.'),AT(110,24),USE(?Lote:Nota)\n", '&Comparar')
    + tab(4, '4. Prepare',
          "             PROMPT('Un UPDATE preparado, ejecutado dos veces con otros valores.'),AT(12,24),USE(?Prep:Nota)\n", '&Ejecutar')
    + tab(5, '5. Transaccion',
          "             PROMPT('BeginTransaction, DELETE y Rollback: no se borra nada.'),AT(12,24),USE(?Trans:Nota)\n", '&Ejecutar')
    + tab(6, '6. Varios resultados',
          "             PROMPT('Cliente:'),AT(12,24),USE(?L:Cliente2:Prompt)\n"
          "             ENTRY(@n_10),AT(42,22,50,12),USE(L:Cliente2)\n", '&Ejecutar')
    + tab(7, '7. Texto largo',
          "             PROMPT('Caracteres:'),AT(12,24),USE(?L:Largo:Prompt)\n"
          "             SPIN(@n7),AT(52,22,60,12),USE(L:Largo),RANGE(1,1000000),STEP(10000)\n", '&Ejecutar')
)

WINDOW = f"""[WINDOW]
Window WINDOW('Ejemplos de uso - SQLMariaClass (MariaDB directo)'),AT(,,640,406),CENTER,GRAY,SYSTEM,MAX,FONT('Segoe UI',9)
       SHEET,AT(4,4,632,174),USE(?Sheet)
{TABS}       END
       PROGRESS,AT(4,182,632,8),USE(?SQLBarra),RANGE(0,100)
       STRING(''),AT(4,192,632,10),USE(?SQLTexto),FONT(,,0808080H)
       LIST,AT(4,204,632,180),USE(?Res),VSCROLL,FROM(ResQ),FONT('Consolas',8),FORMAT('1000L(2)@s250@')
       BUTTON('&Cerrar'),AT(576,388,60,14),USE(?Close),STD(STD:Close)
     END
"""


def instance(when, code, priority=4000):
    return f"WHEN '{when}'\n[DEFINITION]\n[SOURCE]\nPROPERTY:BEGIN\nPRIORITY {priority}\nPROPERTY:END\n{code.rstrip()}\n[END]\n"


RUNS = {1: "Param", 2: "Insert", 3: "Lote", 4: "Prepara", 5: "Trans", 6: "Varios", 7: "Largo"}

EJEMPLOS = (f"""[PROCEDURE]
NAME Ejemplos
[COMMON]
FROM ABC Window
{STAMP}
[EMBED]
EMBED %DataSection
[DEFINITION]
[SOURCE]
PROPERTY:BEGIN
PRIORITY 4000
PROPERTY:END
{DATA.rstrip()}
[END]
EMBED %WindowEventHandling
[INSTANCES]
""" + instance("OpenWindow", OPEN, 8000) + instance("CloseWindow", "  SQL.Kill()", 2000) + "[END]\n"
    + "EMBED %ControlEventHandling\n[INSTANCES]\n"
    + "".join(f"WHEN '?Run{n}'\n[INSTANCES]\n" + instance("Accepted", f"  UPDATE()\n  IF L:Ok THEN DO {r}.\n  DISPLAY()") + "[END]\n"
              for n, r in RUNS.items())
    + "[END]\n"
    + f"EMBED %ProcedureRoutines\n[DEFINITION]\n[SOURCE]\nPROPERTY:BEGIN\nPRIORITY 4000\nPROPERTY:END\n{ROUTINES}\n[END]\n"
    + "[END]\n" + WINDOW)

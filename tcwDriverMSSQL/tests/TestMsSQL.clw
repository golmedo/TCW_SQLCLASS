  PROGRAM
!==============================================================================
! Prueba de SQLMsDirectClass (SQLClass directo a SQL Server).
!   TestMsSQL.exe "Server=PC\INSTANCIA;Database=base;User=u;Password=p"   (o el owner 'servidor,base,usuario,clave')
! Usa una tabla #temporal y un procedimiento #temporal: no deja nada en la base. Resultado en resultados.txt.
!==============================================================================
  INCLUDE('SQLClass6MsDirect.inc'),ONCE
  MAP
Log   PROCEDURE(STRING pText)
Ok    PROCEDURE(STRING pWhat,BYTE pRes)                  ! pRes = codigo de retorno (0 = bien)
Chk   PROCEDURE(STRING pWhat,BYTE pCond)                 ! pCond = condicion que se tiene que cumplir
  END

LogFile         FILE,DRIVER('ASCII'),NAME('resultados.txt'),CREATE
Rec               RECORD
Line                STRING(2048)
                  END
                END

SQL             &SQLMsDirectClass
Conn            CSTRING(1024)
V               STRING(200)
Largo           STRING(10000)
I               LONG
N               LONG
Fails           LONG
Q               QUEUE,PRE(Q)
Id                LONG
Nombre            STRING(60)
Importe           DECIMAL(12,2)
                END

  CODE
  Conn = COMMAND(1)
  CREATE(LogFile)
  OPEN(LogFile)
  SQL &= NEW SQLMsDirectClass
  SQL.SilentMode = True
  SQL.LogFile = 'sql.log'
  Ok('InitDirect',SQL.InitDirect(Conn))
  IF SQL.State <> SQL:Ready
    Log('  ' & SQL.ErrorText())
  ELSE
    Log('  servidor ' & SQL.ServerVersion() & '  cliente ' & SQL.Db.ClientVersion())
    SQL.KeepCase = True
    Ok('CREATE TABLE #temporal',SQL.Exec('CREATE TABLE #tcw_prueba (Id INT IDENTITY(1,1) PRIMARY KEY, Nombre VARCHAR(60), ' & |
                                         'Importe DECIMAL(12,2), Nota VARCHAR(MAX) NULL, Fecha DATE NULL)'))
    LOOP I = 1 TO 25
      V = CHOOSE(I % 3 + 1,'Peña & Cía','O''Brien "comillas"','Barra \ final')
      IF SQL.Exec('INSERT INTO #tcw_prueba (Nombre, Importe) VALUES (' & SQL.Quote(CLIP(V) & ' ' & I) & ', ' & I * 10.5 & ')') THEN Ok('INSERT ' & I,1).
    END
    Chk('InsertId = 25 (SCOPE_IDENTITY): ' & SQL.InsertId(),CHOOSE(SQL.InsertId() = 25))
    Chk('AffectedRows del INSERT = 1: ' & SQL.AffectedRows(),CHOOSE(SQL.AffectedRows() = 1))
    ! SELECT, columnas y valores con caracteres especiales
    Ok('SELECT',SQL.Exec('SELECT Id, Nombre, Importe FROM #tcw_prueba ORDER BY Id'))
    Chk('Columns = 3: ' & SQL.Columns(),CHOOSE(SQL.Columns() = 3))
    Chk('Field(2) = Nombre: ' & SQL.Field(2),CHOOSE(SQL.Field(2) = 'Nombre'))
    Chk('Records() = 25: ' & SQL.Records(),CHOOSE(SQL.Records() = 25))
    I = 0
    LOOP UNTIL SQL.Next()
      I += 1
      IF I = 1 THEN Chk('fila 1 vuelve igual: ' & SQL.Col(2),CHOOSE(SQL.Col(2) = 'O''Brien "comillas" 1')).
      IF I = 3 THEN Chk('fila 3 vuelve igual: ' & SQL.Col(2) & ' | ' & SQL.ColByName('Importe'),CHOOSE(SQL.Col(2) = 'Peña & Cía 3' AND SQL.ColByName('Importe') = '31.50')).
    END
    Chk('filas leidas = 25: ' & I,CHOOSE(I = 25))
    ! Fetch
    V = SQL.Fetch(1,'SELECT COUNT(*) FROM #tcw_prueba WHERE Importe > 100')
    Chk('Fetch COUNT = 16: ' & V,CHOOSE(V = 16))
    Ok('Fetch con resultado',SQL.Fetch(2,'SELECT Id, Nombre FROM #tcw_prueba WHERE Id = 2',V))
    Chk('Fetch Id=2: ' & CLIP(V),CHOOSE(V = 'Barra \ final 2'))
    ! LoadQueue
    SQL.Exec('SELECT Id, Nombre, Importe FROM #tcw_prueba WHERE Id <= 10 ORDER BY Id')
    Ok('LoadQueue',SQL.LoadQueue(Q,1,0))
    GET(Q,10)
    Chk('LoadQueue: 10 filas, ultima 10 / 105.00: ' & RECORDS(Q) & ' ' & Q:Id & ' ' & Q:Importe,CHOOSE(RECORDS(Q) = 10 AND Q:Id = 10 AND Q:Importe = 105))
    ! parametros '?': comilla sin escapar, NULL y un texto largo (varchar(max) por SQLGetData)
    SQL.AddParam('O''Brien%')
    V = SQL.Fetch(1,'SELECT COUNT(*) FROM #tcw_prueba WHERE Nombre LIKE ?')
    Chk('parametro con comilla: 9 filas: ' & V,CHOOSE(V = 9))
    Largo = ALL('abcdefghij',10000)
    SQL.AddParam(Largo)
    SQL.AddNullParam()
    SQL.AddParam('2026-10-29')
    Ok('UPDATE con 3 parametros',SQL.ExecEx('UPDATE #tcw_prueba SET Nota = ?, Nombre = ISNULL(?, Nombre), Fecha = ? WHERE Id = 1',1))
    Chk('AffectedRows = 1: ' & SQL.AffectedRows(),CHOOSE(SQL.AffectedRows() = 1))
    SQL.Exec('SELECT LEN(Nota), Nota, Fecha, Nombre FROM #tcw_prueba WHERE Id = 1')
    SQL.Next()
    N = LEN(SQL.Col(2))
    Chk('texto largo vuelve entero: ' & SQL.Col(1) & ' / ' & N,CHOOSE(SQL.Col(1) = 10000 AND N = 10000 AND SQL.Col(2) = Largo))
    Chk('fecha: ' & SQL.Col(3),CHOOSE(SQL.Col(3) = '2026-10-29' AND DEFORMAT(SQL.Col(3),@d10-) = DATE(10,29,2026)))
    ! NULL
    SQL.Exec('SELECT Nota, Nombre FROM #tcw_prueba WHERE Id = 2')
    SQL.Next()
    Chk('IsNull(Nota)=1, IsNull(Nombre)=0',CHOOSE(SQL.IsNull(1) = 1 AND SQL.IsNull(2) = 0))
    ! UPDATE
    Ok('UPDATE',SQL.Exec('UPDATE #tcw_prueba SET Importe = Importe * 2 WHERE Id <= 5'))
    Chk('AffectedRows = 5: ' & SQL.AffectedRows(),CHOOSE(SQL.AffectedRows() = 5))
    ! transaccion con rollback
    Ok('BeginTransaction',SQL.BeginTransaction())
    SQL.Exec('DELETE FROM #tcw_prueba')
    Chk('dentro de la transaccion: 0 filas',CHOOSE(SQL.Fetch(1,'SELECT COUNT(*) FROM #tcw_prueba') = 0))
    Ok('Rollback',SQL.Rollback())
    V = SQL.Fetch(1,'SELECT COUNT(*) FROM #tcw_prueba')
    Chk('despues del ROLLBACK: 25 filas: ' & V,CHOOSE(V = 25))
    ! varios resultados en un lote
    Ok('lote con 2 SELECT',SQL.ExecEx('SELECT 1 AS a; SELECT 2 AS b, 3 AS c',1))
    SQL.Next()
    Chk('primer resultado: a = 1',CHOOSE(SQL.Col(1) = 1 AND SQL.Columns() = 1))
    Ok('NextResult',SQL.NextResult())
    SQL.Next()
    Chk('segundo resultado: 2 columnas, c = 3, Field(2) = c',CHOOSE(SQL.Columns() = 2 AND SQL.Col(2) = 3 AND SQL.Field(2) = 'c'))
    Chk('no hay tercer resultado',CHOOSE(SQL.NextResult() = Level:Notify))
    ! procedimiento temporal con dos resultados y conteos intermedios
    Ok('CREATE PROCEDURE #temporal',SQL.Exec('CREATE PROCEDURE #tcw_sp @desde INT AS BEGIN UPDATE #tcw_prueba SET Importe = Importe WHERE Id = 1; ' & |
                                             'SELECT Id, Nombre FROM #tcw_prueba WHERE Id >= @desde ORDER BY Id; SELECT COUNT(*) AS total FROM #tcw_prueba END'))
    Ok('ExecSP',SQL.ExecSP('EXEC #tcw_sp 20'))
    I = 0
    LOOP UNTIL SQL.Next()
      I += 1
    END
    Chk('ExecSP filas = 6 (saltea el conteo del UPDATE): ' & I,CHOOSE(I = 6))
    Ok('NextResult del procedimiento',SQL.NextResult())
    SQL.Next()
    Chk('segundo resultado del procedimiento: total = 25',CHOOSE(SQL.Col(1) = 25))
    Ok('CALL con escape ODBC',SQL.ExecSP('CALL #tcw_sp(24)'))
    Chk('CALL: 2 filas',CHOOSE(SQL.Records() = 2))
    ! GROUP BY: Records() exacto
    SQL.Exec('SELECT CASE WHEN Importe > 100 THEN 1 ELSE 0 END, COUNT(*) FROM #tcw_prueba GROUP BY CASE WHEN Importe > 100 THEN 1 ELSE 0 END')
    Chk('Records() con GROUP BY = 2: ' & SQL.Records(),CHOOSE(SQL.Records() = 2))
    ! errores
    Chk('tabla inexistente falla con 208: ' & SQL.ErrorText(),CHOOSE(SQL.Exec('SELECT * FROM tabla_que_no_existe') = Level:Notify AND SQL.ErrorCode() = 208))
    Log('  ' & SQL.ErrorText())
    SQL.Exec('SET IDENTITY_INSERT #tcw_prueba ON')
    Chk('clave duplicada falla con 2627',CHOOSE(SQL.Exec('INSERT INTO #tcw_prueba (Id, Nombre) VALUES (1, ''x'')') = Level:Notify AND SQL.ErrorCode() = 2627))
    SQL.Exec('SET IDENTITY_INSERT #tcw_prueba OFF')
    Ok('Exec despues del error',SQL.Exec('SELECT 1'))
    ! sentencia preparada: se prepara una vez y se ejecuta dos veces con otros valores
    Ok('Prepare UPDATE',SQL.Prepare('UPDATE #tcw_prueba SET Importe = ? WHERE Id = ?'))
    SQL.AddParam('99.99') ; SQL.AddParam('3')
    Ok('ExecPrepared 1',SQL.ExecPrepared())
    Chk('AffectedRows = 1: ' & SQL.AffectedRows(),CHOOSE(SQL.AffectedRows() = 1))
    SQL.AddParam('11.11') ; SQL.AddParam('4')
    Ok('ExecPrepared 2 (misma sentencia)',SQL.ExecPrepared())
    V = SQL.Fetch(1,'SELECT CAST(SUM(Importe) AS varchar(20)) FROM #tcw_prueba WHERE Id IN (3,4)')
    Chk('valores de las dos ejecuciones: 111.10: ' & V,CHOOSE(V = '111.10'))
    ! INSERT por nombre de campo: comillas simples y dobles, fecha, fecha y hora, NULL
    Ok('CREATE TABLE #campos',SQL.Exec('CREATE TABLE #tcw_campos (Id INT PRIMARY KEY, Nombre VARCHAR(60), Importe DECIMAL(12,2), ' & |
                                       'Fecha DATE NULL, Hora DATETIME NULL, Nota VARCHAR(50) NULL)'))
    SQL.Campo('Id',1)
    SQL.Campo('Nombre','O''Brien "dice" hola')
    SQL.Campo('Importe',123.45)
    SQL.CampoFecha('Fecha',DATE(10,29,2026))
    SQL.CampoFechaHora('Hora',DATE(10,29,2026),DEFORMAT('09:05:07',@t04))
    SQL.CampoNulo('Nota')
    Ok('Insertar',SQL.Insertar('#tcw_campos'))
    SQL.Exec('SELECT Nombre, Importe, Fecha, CONVERT(varchar(19), Hora, 120), Nota FROM #tcw_campos WHERE Id = 1')
    SQL.Next()
    Chk('Insertar: texto con comillas vuelve igual: ' & SQL.Col(1),CHOOSE(SQL.Col(1) = 'O''Brien "dice" hola'))
    Chk('Insertar: importe, fecha, hora y NULL: ' & SQL.Col(2) & ' ' & SQL.Col(3) & ' ' & SQL.Col(4), |
        CHOOSE(SQL.Col(2) = '123.45' AND SQL.Col(3) = '2026-10-29' AND SQL.Col(4) = '2026-10-29 09:05:07' AND SQL.IsNull(5)))
    ! lote: 1234 filas, se mandan solas de a 500 y EnviarLote manda las 234 que quedan
    LOOP I = 2 TO 1235
      SQL.Campo('Id',I)
      SQL.Campo('Nombre','Fila ' & I)
      SQL.Campo('Importe',I * 0.5)
      SQL.CampoFecha('Fecha',CHOOSE(I % 10 = 0,0,DATE(1,1,2026) + I))
      IF SQL.InsertarLote('#tcw_campos') THEN Ok('InsertarLote fila ' & I,1) ; BREAK.
    END
    Chk('pendientes antes de EnviarLote = 234: ' & SQL.Db.PendingRows(),CHOOSE(SQL.Db.PendingRows() = 234))
    Ok('EnviarLote',SQL.EnviarLote())
    ! un procedimiento con un segundo resultado sin leer no tiene que trabar la sentencia preparada que sigue
    Ok('ExecSP con dos resultados (sin leer el segundo)',SQL.ExecSP('EXEC #tcw_sp 20'))
    SQL.Campo('Id',5000)
    SQL.Campo('Nombre','despues del procedimiento')
    SQL.Campo('Importe',0)
    Ok('Insertar despues de un resultado pendiente',SQL.Insertar('#tcw_campos'))
    SQL.Exec('DELETE FROM #tcw_campos WHERE Id = 5000')
    V = SQL.Fetch(1,'SELECT CAST(COUNT(*) AS varchar(10)) + ''/'' + CAST(SUM(Importe) AS varchar(20)) + ''/'' + CAST(SUM(CASE WHEN Fecha IS NULL THEN 1 ELSE 0 END) AS varchar(10)) FROM #tcw_campos')
    Chk('lote: 1235 filas, suma 381737.95, 123 fechas NULL: ' & V,CHOOSE(V = '1235/381737.95/123'))
    Ok('DROP TABLE #temporal',SQL.Exec('DROP TABLE #tcw_prueba'))
    SQL.Kill()
  END
  Log(CHOOSE(Fails = 0,'RESULTADO: TODO OK','RESULTADO: ' & Fails & ' FALLA(S)'))
  CLOSE(LogFile)
  DISPOSE(SQL)

Log PROCEDURE(STRING pText)
  CODE
  LogFile.Line = pText
  ADD(LogFile)

Ok PROCEDURE(STRING pWhat,BYTE pRes)
  CODE
  IF pRes
    Fails += 1
    Log('FALLA ' & CLIP(pWhat) & ': ' & SQL.ErrorText())
  ELSE
    Log('OK    ' & pWhat)
  END

Chk PROCEDURE(STRING pWhat,BYTE pCond)
  CODE
  IF pCond
    Log('OK    ' & pWhat)
  ELSE
    Fails += 1
    Log('FALLA ' & pWhat)
  END

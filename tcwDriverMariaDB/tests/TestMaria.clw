  PROGRAM
!==============================================================================
! Prueba de SQLMariaClass (SQLClass directo a MariaDB/MySQL).
!   TestMaria.exe "Server=127.0.0.1;Port=3306;Database=test;User=u;Password=p"
! Usa una tabla TEMPORARY (no deja nada en la base). Con un 2do parametro SP prueba tambien un store procedure. Resultado en resultados.txt.
!==============================================================================
  INCLUDE('SQLClass6Maria.inc'),ONCE
  MAP
Log   PROCEDURE(STRING pText)
Ok    PROCEDURE(STRING pWhat,BYTE pRes)
Chk   PROCEDURE(STRING pWhat,BYTE pCond)                 ! pCond = condicion que se tiene que cumplir
  END

LogFile         FILE,DRIVER('ASCII'),NAME('resultados.txt'),CREATE
Rec               RECORD
Line                STRING(2048)
                  END
                END

SQL             &SQLMariaClass
Conn            CSTRING(1024)
V               STRING(200)
I               LONG
Fails           LONG
N               LONG
Largo           STRING(20000)
Q               QUEUE,PRE(Q)
Id                LONG
Nombre            STRING(60)
Importe           DECIMAL(12,2)
                END

  CODE
  Conn = COMMAND(1)
  IF Conn = '' THEN Conn = 'Server=127.0.0.1;Port=3306;Database=test;User=root;Password='.
  CREATE(LogFile)
  OPEN(LogFile)
  SQL &= NEW SQLMariaClass
  SQL.SilentMode = True
  SQL.LogFile = 'sql.log'
  Ok('InitMaria',SQL.InitMaria(Conn))
  IF SQL.State <> SQL:Ready
    Log('  ' & SQL.ErrorText())
  ELSE
    Log('  servidor ' & SQL.ServerVersion() & '  cliente ' & SQL.Db.ClientVersion())
    SQL.KeepCase = True
    SQL.Exec('DROP TEMPORARY TABLE IF EXISTS tcw_prueba_sqlclass')
    Ok('CREATE TEMPORARY TABLE',SQL.Exec('CREATE TEMPORARY TABLE tcw_prueba_sqlclass (Id INT AUTO_INCREMENT PRIMARY KEY, Nombre VARCHAR(60), Importe DECIMAL(12,2), Nota VARCHAR(100) NULL)'))
    LOOP I = 1 TO 25
      V = CHOOSE(I % 3 + 1,'Peña & Cía','O''Brien "comillas"','Barra \ final')
      IF SQL.Exec('INSERT INTO tcw_prueba_sqlclass (Nombre, Importe) VALUES (' & SQL.Quote(CLIP(V) & ' ' & I) & ', ' & I * 10.5 & ')') THEN Ok('INSERT ' & I,1).
    END
    Log('  InsertId=' & SQL.InsertId() & '  (esperado 25)')
    Ok('SELECT',SQL.Exec('SELECT Id, Nombre, Importe FROM tcw_prueba_sqlclass ORDER BY Id'))
    Log('  Columns=' & SQL.Columns() & '  Field(2)=' & SQL.Field(2) & '  Records()=' & SQL.Records())
    I = 0
    LOOP UNTIL SQL.Next()
      I += 1
      IF I <= 3 THEN Log('  fila ' & SQL.Col(1) & ' | ' & SQL.Col(2) & ' | ' & SQL.ColByName('Importe')).
    END
    Log('  filas leidas=' & I & '  Records_Done=' & SQL.Records_Done)
    IF I <> 25 THEN Ok('Cantidad de filas',1).
    ! Fetch (un valor)
    Log('  Fetch COUNT=' & SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_prueba_sqlclass WHERE Importe > 100'))
    Ok('Fetch con resultado',SQL.Fetch(2,'SELECT Id, Nombre FROM tcw_prueba_sqlclass WHERE Id = 2',V))
    Log('  Fetch Id=2 -> ' & CLIP(V))
    ! LoadQueue con formato
    SQL.Exec('SELECT Id, Nombre, Importe FROM tcw_prueba_sqlclass WHERE Id <= 10 ORDER BY Id')
    Ok('LoadQueue',SQL.LoadQueue(Q,1,0))
    GET(Q,10)
    Log('  cola=' & RECORDS(Q) & '  ultima: ' & Q:Id & ' ' & CLIP(Q:Nombre) & ' ' & Q:Importe)
    ! NULL
    SQL.Exec('SELECT Nota, Nombre FROM tcw_prueba_sqlclass WHERE Id = 1')
    SQL.Next()
    Log('  IsNull(Nota)=' & SQL.IsNull(1) & '  IsNull(Nombre)=' & SQL.IsNull(2))
    ! UPDATE / DELETE
    Ok('UPDATE',SQL.Exec('UPDATE tcw_prueba_sqlclass SET Importe = Importe * 2 WHERE Id <= 5'))
    Log('  AffectedRows=' & SQL.AffectedRows() & '  (esperado 5)')
    ! transaccion con rollback
    SQL.BeginTransaction()
    SQL.Exec('DELETE FROM tcw_prueba_sqlclass')
    SQL.Rollback()
    Log('  despues del ROLLBACK quedan ' & SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_prueba_sqlclass') & ' filas (esperado 25)')
    ! store procedure con resultado (solo con el parametro sp: crea y borra tcw_prueba_sp en la base)
    IF UPPER(COMMAND(2)) = 'SP'
      SQL.Exec('DROP PROCEDURE IF EXISTS tcw_prueba_sp')
      Ok('CREATE PROCEDURE',SQL.Exec('CREATE PROCEDURE tcw_prueba_sp(IN desde INT) SELECT Id, Nombre FROM tcw_prueba_sqlclass WHERE Id >= desde ORDER BY Id'))
      Ok('ExecSP',SQL.ExecSP('EXEC tcw_prueba_sp 20'))
      I = 0
      LOOP UNTIL SQL.Next()
        I += 1
      END
      Log('  ExecSP filas=' & I & '  (esperado 6)')
      Ok('Exec despues del CALL (sin "out of sync")',SQL.Exec('SELECT 1'))
      SQL.Exec('DROP PROCEDURE IF EXISTS tcw_prueba_sp')
    END
    ! GROUP BY: Records() exacto
    SQL.Exec('SELECT Importe > 100, COUNT(*) FROM tcw_prueba_sqlclass GROUP BY Importe > 100')
    Log('  Records() con GROUP BY=' & SQL.Records() & '  (esperado 2)')
    ! parametros '?': comilla sin escapar, barra invertida, NULL y un '?' dentro de comillas que no se toca
    SQL.AddParam('O''Brien%')
    V = SQL.Fetch(1,'SELECT COUNT(*) FROM tcw_prueba_sqlclass WHERE Nombre LIKE ?')
    Chk('parametro con comilla: 9 filas: ' & V,CHOOSE(V = 9))
    SQL.AddParam('Barra \ con '' comilla')
    SQL.AddNullParam()
    Ok('UPDATE con parametros',SQL.ExecEx('UPDATE tcw_prueba_sqlclass SET Nombre = ?, Nota = ? WHERE Id = 1',1))
    SQL.Exec('SELECT Nombre, Nota FROM tcw_prueba_sqlclass WHERE Id = 1')
    SQL.Next()
    Chk('parametros vuelven iguales: ' & SQL.Col(1),CHOOSE(SQL.Col(1) = 'Barra \ con '' comilla' AND SQL.IsNull(2)))
    SQL.AddParam('x')
    V = SQL.Fetch(1,'SELECT CONCAT(''a?b'', ?)')
    Chk('el ? entre comillas no se toca: ' & V,CHOOSE(V = 'a?bx'))
    ! varias sentencias: NextResult, y 'UPDATE ...; SELECT ...' va directo al resultado
    Ok('lote con 2 SELECT',SQL.ExecEx('SELECT 1 AS a; SELECT 2 AS b, 3 AS c',1))
    SQL.Next()
    Chk('primer resultado: a = 1',CHOOSE(SQL.Col(1) = 1 AND SQL.Columns() = 1))
    Ok('NextResult',SQL.NextResult())
    SQL.Next()
    Chk('segundo resultado: 2 columnas, c = 3, Field(2) = c',CHOOSE(SQL.Columns() = 2 AND SQL.Col(2) = 3 AND SQL.Field(2) = 'c'))
    Chk('no hay tercer resultado',CHOOSE(SQL.NextResult() = Level:Notify))
    Ok('UPDATE; SELECT',SQL.ExecEx('UPDATE tcw_prueba_sqlclass SET Importe = Importe WHERE Id = 2; SELECT COUNT(*) FROM tcw_prueba_sqlclass',1))
    SQL.Next()
    Chk('UPDATE; SELECT da el resultado del SELECT: 25',CHOOSE(SQL.Col(1) = 25))
    ! sentencia preparada: dos veces con otros valores
    Ok('Prepare UPDATE',SQL.Prepare('UPDATE tcw_prueba_sqlclass SET Importe = ? WHERE Id = ?'))
    SQL.AddParam('99.99') ; SQL.AddParam('3')
    Ok('ExecPrepared 1',SQL.ExecPrepared())
    Chk('AffectedRows = 1: ' & SQL.AffectedRows(),CHOOSE(SQL.AffectedRows() = 1))
    SQL.AddParam('11.11') ; SQL.AddParam('4')
    Ok('ExecPrepared 2 (misma sentencia)',SQL.ExecPrepared())
    V = SQL.Fetch(1,'SELECT SUM(Importe) FROM tcw_prueba_sqlclass WHERE Id IN (3,4)')
    Chk('valores de las dos ejecuciones: 111.10: ' & V,CHOOSE(V = '111.10'))
    ! INSERT por nombre de campo
    Ok('CREATE TEMPORARY TABLE tcw_campos',SQL.Exec('CREATE TEMPORARY TABLE tcw_campos (Id INT PRIMARY KEY, Nombre VARCHAR(60), ' & |
                                                   'Importe DECIMAL(12,2), Fecha DATE NULL, Hora DATETIME NULL, Nota MEDIUMTEXT NULL)'))
    SQL.Campo('Id',1)
    SQL.Campo('Nombre','O''Brien "dice" \ hola')
    SQL.Campo('Importe',123.45)
    SQL.CampoFecha('Fecha',DATE(10,29,2026))
    SQL.CampoFechaHora('Hora',DATE(10,29,2026),DEFORMAT('09:05:07',@t04))
    SQL.CampoNulo('Nota')
    Ok('Insertar',SQL.Insertar('tcw_campos'))
    SQL.Exec('SELECT Nombre, Importe, Fecha, DATE_FORMAT(Hora,''<37>Y-<37>m-<37>d <37>H:<37>i:<37>s''), Nota FROM tcw_campos WHERE Id = 1')
    SQL.Next()
    Chk('Insertar: texto con comillas y barra vuelve igual: ' & SQL.Col(1),CHOOSE(SQL.Col(1) = 'O''Brien "dice" \ hola'))
    Chk('Insertar: importe, fecha, hora y NULL: ' & SQL.Col(2) & ' ' & SQL.Col(3) & ' ' & SQL.Col(4), |
        CHOOSE(SQL.Col(2) = '123.45' AND SQL.Col(3) = '2026-10-29' AND SQL.Col(4) = '2026-10-29 09:05:07' AND SQL.IsNull(5)))
    ! lote: 1234 filas en INSERT de varias filas (de a 500) y EnviarLote manda las 234 que quedan
    LOOP I = 2 TO 1235
      SQL.Campo('Id',I)
      SQL.Campo('Nombre','Fila ' & I)
      SQL.Campo('Importe',I * 0.5)
      SQL.CampoFecha('Fecha',CHOOSE(I % 10 = 0,0,DATE(1,1,2026) + I))
      IF SQL.InsertarLote('tcw_campos') THEN Ok('InsertarLote fila ' & I,1) ; BREAK.
    END
    Chk('pendientes antes de EnviarLote = 234: ' & SQL.Db.PendingRows(),CHOOSE(SQL.Db.PendingRows() = 234))
    Ok('EnviarLote',SQL.EnviarLote())
    V = SQL.Fetch(1,'SELECT CONCAT(COUNT(*), ''/'', SUM(Importe), ''/'', SUM(Fecha IS NULL)) FROM tcw_campos')
    Chk('lote: 1235 filas, suma 381737.95, 123 fechas NULL: ' & V,CHOOSE(V = '1235/381737.95/123'))
    ! texto largo
    Largo = ALL('abcdefghij',20000)
    SQL.Campo('Id',9000)
    SQL.Campo('Nombre','largo')
    SQL.Campo('Importe',0)
    SQL.Campo('Nota',Largo)
    Ok('Insertar texto de 20000',SQL.Insertar('tcw_campos'))
    SQL.Exec('SELECT CHAR_LENGTH(Nota), Nota FROM tcw_campos WHERE Id = 9000')
    SQL.Next()
    N = LEN(SQL.Col(2))
    Chk('texto largo vuelve entero: ' & SQL.Col(1) & ' / ' & N,CHOOSE(SQL.Col(1) = 20000 AND N = 20000 AND SQL.Col(2) = Largo))
    ! un resultado pendiente sin leer no traba lo que sigue
    Ok('lote con un segundo resultado sin leer',SQL.ExecEx('SELECT 1; SELECT 2',1))
    SQL.Campo('Id',9001)
    SQL.Campo('Nombre','despues')
    SQL.Campo('Importe',0)
    Ok('Insertar despues de un resultado pendiente',SQL.Insertar('tcw_campos'))
    SQL.Exec('DROP TEMPORARY TABLE tcw_campos')
    ! error esperado
    Log('  tabla inexistente -> ' & CHOOSE(SQL.Exec('SELECT * FROM tabla_que_no_existe') = Level:Notify,'falla bien: ' & SQL.ErrorText(),'NO FALLO'))
    Ok('Exec despues del error',SQL.Exec('SELECT 1'))
    Ok('DROP TEMPORARY TABLE',SQL.Exec('DROP TEMPORARY TABLE tcw_prueba_sqlclass'))
    SQL.Kill()
  END
  Log(CHOOSE(Fails = 0,'RESULTADO: TODO OK','RESULTADO: ' & Fails & ' FALLA(S)'))
  CLOSE(LogFile)
  DISPOSE(SQL)

Log PROCEDURE(STRING pText)
  CODE
  LogFile.Line = pText
  ADD(LogFile)

Chk PROCEDURE(STRING pWhat,BYTE pCond)
  CODE
  IF pCond
    Log('OK    ' & pWhat)
  ELSE
    Fails += 1
    Log('FALLA ' & pWhat)
  END

Ok PROCEDURE(STRING pWhat,BYTE pRes)
  CODE
  IF pRes
    Fails += 1
    Log('FALLA ' & CLIP(pWhat) & ': ' & SQL.ErrorText())
  ELSE
    Log('OK    ' & pWhat)
  END

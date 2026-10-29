  MEMBER
!==============================================================================
! SQLMsDirectClass - implementacion (ver SQLClass6MsDirect.inc)
! Reproduce los metodos de SQLOdbcClass (SQLClass6.clw) con el mismo comportamiento y los mismos codigos
! de retorno (Level:Benign = bien, Level:Notify = error; Next() devuelve 0 cuando trajo una fila),
! pero enviando el SQL directo a SQL Server con TCWMsSQL (API de ODBC) en vez de PROP:SQL sobre un archivo.
!==============================================================================
  MAP
    MODULE('user32')
      tmsd_RedrawWindow(LONG hWnd,LONG lprc,LONG hrgn,LONG flags),LONG,PASCAL,PROC,NAME('RedrawWindow')
    END
  END

  INCLUDE('aberror.inc'),ONCE
  INCLUDE('abbrowse.inc'),ONCE
  INCLUDE('SQLClass6MsDirect.inc'),ONCE
  INCLUDE('StringClass.INC'),ONCE

!------------------------------------------------------------------------------
SQLMsDirectClass.Construct PROCEDURE()
  CODE
  SELF.Db &= NEW TCWMsSQL
  SELF.ProgressDelay = 10

SQLMsDirectClass.Destruct PROCEDURE()
  CODE
  IF NOT SELF.Db &= NULL
    SELF.Db.Disconnect()
    DISPOSE(SELF.Db)
  END

!------------------------------------------------------------------------------
! Init con la misma firma que SQLClass6: el archivo y el registro se guardan pero no se usan.
! Conexion = 'Server=PC\INSTANCIA;Database=base;User=usuario;Password=clave', una cadena ODBC o el owner
! del driver MSSQL de Clarion 'servidor,base,usuario,clave' (asi un Init existente no cambia).
SQLMsDirectClass.Init PROCEDURE(*File Archivo,*Group Registro,String Conexion)
  CODE
  SELF.SQLFile &= Archivo
  SELF.SQLFileRecord &= Registro
  RETURN SELF.InitDirect(Conexion)

SQLMsDirectClass.InitDirect PROCEDURE(String Conexion)
  CODE
  SETCURSOR(Cursor:Wait)
  SELF.PropOwner = Conexion
  SELF.FreeQueue = True
  SELF.ProgLast = CLOCK()
  SELF.SetProgress(-1,'Conectando al servidor...')
  IF SELF.Db.Connect(Conexion)
    SELF.State = SQL:NotReady
    SETCURSOR()
    SELF.SetProgress(-1,'No se pudo conectar: ' & SELF.Db.LastError)
    IF NOT SELF.SilentMode THEN STOP('SQLClass (SQL Server) no pudo conectar.<13,10>' & SELF.Db.LastError).
    RETURN Level:Notify
  END
  SELF.SetProgress(-1,'Conectado en ' & ABS(CLOCK() - SELF.ProgLast) * 10 & ' ms')
  SELF.State = SQL:Ready
  SETCURSOR()
  RETURN Level:Benign

SQLMsDirectClass.Kill PROCEDURE()
  CODE
  FREE(SELF.Fields)
  FREE(SELF.Format)
  SELF.Db.Disconnect()
  SELF.State = SQL:NotReady

!------------------------------------------------------------------------------
SQLMsDirectClass.SP PROCEDURE(Short NoCols,String SP_Name)
  CODE
  SELF.Cols = CHOOSE(NoCols > 0,NoCols,1)
  IF SELF.Exec('EXEC ' & SP_Name) THEN RETURN Level:Notify.
  RETURN Level:Benign

SQLMsDirectClass.Exec PROCEDURE(String Query)
Loc:Start       TIME
Loc:Duration    TIME
  CODE
  IF NOT SELF.Db.Connected() THEN MESSAGE('SQLClass (SQL Server) no esta conectada. Llame a Init / InitDirect','Error',ICON:Exclamation);RETURN Level:Notify.
  SELF.Records_Done = 0
  SELF.Records      = 0
  IF SELF.KeepCase
    SELF.Query     = CLIP(Query)
  ELSE
    SELF.Query     = Lower(CLIP(Query))
  END
  IF NOT SELF.Parse() = Level:Benign
    IF NOT SELF.SilentMode THEN MESSAGE(' SQL : THE PARSE OF THE QUERY FAILED').
    SETCLIPBOARD(SELF.Query)
    RETURN Level:Notify
  END
  Loc:Start = CLOCK()
  IF NOT SELF.ServerExec() = Level:Benign
    IF NOT SELF.SilentMode THEN MESSAGE(' SQL : THE EXECUTION OF THE QUERY FAILED').
    SETCLIPBOARD(SELF.Query)
    RETURN Level:Notify
  END
  Loc:Duration = CLOCK() - Loc:Start
  IF SELF.Debug AND Loc:Duration > SELF.Debug_Limit
    MESSAGE('SQL Class (Long Query Detection).| El Query:|' & CLIP(SELF.Query) & '| Duracion: ' & FORMAT(Loc:Duration,@t4),'LONG QUERY',ICON:EXCLAMATION)
    SETCLIPBOARD(SELF.Query)
  END
  RETURN Level:Benign

SQLMsDirectClass.ExecEx PROCEDURE(String Query,<Byte OmitLower>)
Loc:Start       TIME
Loc:Duration    TIME
  CODE
  IF NOT SELF.Db.Connected() THEN MESSAGE('SQLClass (SQL Server) no esta conectada. Llame a Init / InitDirect','Error',ICON:Exclamation);RETURN Level:Notify.
  SELF.Records_Done = 0
  SELF.Records      = 0
  IF OMITTED(2) OR NOT OmitLower
    SELF.Query     = Lower(CLIP(Query))
  ELSE
    SELF.Query     = CLIP(Query)
  END
  IF NOT SELF.Parse() = Level:Benign
    IF NOT SELF.SilentMode THEN MESSAGE(' SQL : THE PARSE OF THE QUERY FAILED').
    SETCLIPBOARD(SELF.Query)
    RETURN Level:Notify
  END
  SELF.Cols = SELF.CountCols()
  Loc:Start = CLOCK()
  IF NOT SELF.ServerExecEx() = Level:Benign
    IF NOT SELF.SilentMode THEN MESSAGE(' SQL : THE EXECUTION OF THE QUERY FAILED').
    SETCLIPBOARD(SELF.Query)
    RETURN Level:Notify
  END
  Loc:Duration = CLOCK() - Loc:Start
  IF SELF.Debug AND Loc:Duration > SELF.Debug_Limit
    MESSAGE('SQL Class (Long Query Detection).| El Query:|' & CLIP(SELF.Query) & '| Duracion: ' & FORMAT(Loc:Duration,@t4),'LONG QUERY',ICON:EXCLAMATION)
    SETCLIPBOARD(SELF.Query)
  END
  RETURN Level:Benign

! 'EXEC sp p1, p2' / 'EXECUTE sp p1' se mandan tal cual; 'CALL sp(p1, p2)' con el escape de ODBC {CALL sp(p1, p2)}.
! Respeta mayusculas (no pasa por Parse ni Lower). Si el procedimiento devuelve varios resultados: NextResult().
SQLMsDirectClass.ExecSP PROCEDURE(String Query,<Short NoCols>)
Args        CSTRING(20480)
  CODE
  IF NOT SELF.Db.Connected() THEN MESSAGE('SQLClass (SQL Server) no esta conectada. Llame a Init / InitDirect','Error',ICON:Exclamation);RETURN Level:Notify.
  SELF.Records_Done = 0
  SELF.Records      = 0
  Args              = CLIP(LEFT(Query))
  IF UPPER(SUB(Args,1,5)) = 'CALL '
    SELF.Query = '{{' & Args & CHOOSE(INSTRING('(',Args,1,1) = 0,'()','') & '}'
  ELSIF UPPER(SUB(Args,1,5)) = 'EXEC ' OR UPPER(SUB(Args,1,8)) = 'EXECUTE '
    SELF.Query = Args
  ELSE
    SELF.Query = 'EXEC ' & Args
  END
  FREE(SELF.Fields)
  IF OMITTED(3) OR NOT NoCols THEN SELF.Cols = 1 ELSE SELF.Cols = NoCols.
  IF NOT SELF.ServerExecEx() = Level:Benign
    IF NOT SELF.SilentMode THEN MESSAGE(' SQL : THE EXECUTION OF THE STORE PROCEDURE FAILED|' & CLIP(SELF.Query)).
    SETCLIPBOARD(SELF.Query)
    RETURN Level:Notify
  END
  RETURN Level:Benign

!------------------------------------------------------------------------------
! Igual que SQLClass6.Parse: separa SELECT/FROM/WHERE/GROUP BY/ORDER BY (lo usa Records) y llama a los Take*.
! Acepta ademas las sentencias propias de SQL Server (EXEC, DECLARE, MERGE, IF, WITH, PRINT, TRUNCATE...).
! Una sentencia desconocida avisa (como antes) y se envia igual.
SQLMsDirectClass.Parse PROCEDURE()
PosFrom      LONG
PosWhere     LONG
Pos_OrderBy  LONG
Pos_GroupBy  LONG
Upp          BYTE
  CODE
  SELF.SQL_Select  = ''
  SELF.SQL_From    = ''
  SELF.SQL_Where   = ''
  SELF.SQL_OrderBy = ''
  SELF.SQL_GroupBy = ''
  SELF.MiString.Delimiters = ' ,|'
  SELF.MiString.Text = CLIP(SELF.Query)
  SELF.MiString.SelEnd = 0
  CASE CLIP(UPPER(SELF.MiString.NextToken()))
  OF 'SELECT'
    IF SELF.TakeSelect() <> Level:Benign THEN RETURN Level:Benign.
  OF 'INSERT' OROF 'REPLACE'
    SELF.Cols = 1
    RETURN CHOOSE(SELF.TakeInsert() = Level:Benign,Level:Benign,Level:Notify)
  OF 'DELETE'
    SELF.Cols = 1
    RETURN CHOOSE(SELF.TakeDelete() = Level:Benign,Level:Benign,Level:Notify)
  OF 'UPDATE'
    SELF.Cols = 1
    RETURN CHOOSE(SELF.TakeUpdate() = Level:Benign,Level:Benign,Level:Notify)
  OF 'DROP'
    SELF.Cols = 1
    RETURN CHOOSE(SELF.TakeDrop() = Level:Benign,Level:Benign,Level:Notify)
  OF 'EXECUTE' OROF 'BEGIN' OROF 'COMMIT' OROF 'ROLLBACK' OROF 'SET' OROF 'CREATE' OROF 'TRUNCATE' |
  OROF 'ALTER' OROF 'SAVEPOINT' OROF 'START' OROF 'RELEASE' OROF 'SHOW' OROF 'DESCRIBE' OROF 'DESC' |
  OROF 'EXPLAIN' OROF 'USE' OROF 'WITH' OROF 'LOCK' OROF 'UNLOCK' OROF 'RENAME' OROF 'GRANT' |
  OROF 'REVOKE' OROF 'ANALYZE' OROF 'OPTIMIZE' OROF 'CHECK' OROF 'REPAIR' OROF 'DO' OROF 'LOAD' |
  OROF 'FLUSH' OROF 'KILL' OROF 'HANDLER' OROF 'VALUES' OROF 'TABLE' OROF 'EXEC' OROF 'DECLARE' |
  OROF 'MERGE' OROF 'IF' OROF 'WHILE' OROF 'PRINT' OROF 'RAISERROR' OROF 'THROW' OROF 'BULK' OROF 'DBCC' |
  OROF 'BACKUP' OROF 'RESTORE' OROF 'DENY' OROF 'OPEN' OROF 'CLOSE' OROF 'FETCH' OROF 'DEALLOCATE' OROF 'WAITFOR'
    SELF.Cols = 1
    RETURN Level:Benign
  OF 'CALL' OROF 'NORESULTCALL'
    RETURN Level:Benign
  ELSE
    IF NOT SELF.SilentMode
      MESSAGE('LA SQL CLASS DETECTO UN ERROR DE SINTAXIS EN:|' & CLIP(SELF.Query),'SYNTAX ERROR',ICON:EXCLAMATION)
      SETCLIPBOARD(SELF.Query)
    END
    RETURN Level:Benign
  END
  Upp = SELF.MiString.ForceUpper
  SELF.MiString.ForceUpper = True
  PosFrom     = SELF.MiString.Find('FROM')
  PosWhere    = SELF.MiString.Find('WHERE')
  Pos_OrderBy = SELF.MiString.Find('ORDER BY')
  Pos_GroupBy = SELF.MiString.Find('GROUP BY')
  SELF.MiString.ForceUpper = Upp
  IF PosFrom
    SELF.SQL_Select = SELF.MiString.SubLeft(PosFrom)
  ELSE
    SELF.SQL_Select = SELF.MiString.Text                ! SELECT sin FROM (SELECT GETDATE(), SELECT 1+1)
    RETURN Level:Benign
  END
  IF PosWhere
    SELF.SQL_From = SELF.MiString.Text[PosFrom : PosWhere-1]
  END
  IF Pos_GroupBy
    IF PosWhere
      SELF.SQL_Where = SELF.MiString.Text[PosWhere : Pos_GroupBy-1]
    ELSE
      SELF.SQL_From  = SELF.MiString.Text[PosFrom : Pos_GroupBy-1]
    END
    IF Pos_OrderBy
      SELF.SQL_GroupBy = SELF.MiString.Text[Pos_GroupBy : Pos_OrderBy-1]
      SELF.SQL_OrderBy = SELF.MiString.SubRight(Pos_OrderBy)
    ELSE
      SELF.SQL_GroupBy = SELF.MiString.SubRight(Pos_GroupBy)
    END
  ELSIF Pos_OrderBy
    SELF.SQL_OrderBy = SELF.MiString.SubRight(Pos_OrderBy)
    IF PosWhere
      SELF.SQL_Where = SELF.MiString.Text[PosWhere : Pos_OrderBy-1]
    ELSE
      SELF.SQL_From  = SELF.MiString.Text[PosFrom : Pos_OrderBy-1]
    END
  ELSIF PosWhere
    SELF.SQL_Where = SELF.MiString.SubRight(PosWhere)
  ELSE
    SELF.SQL_From  = SELF.MiString.SubRight(PosFrom)
  END
  RETURN Level:Benign

!------------------------------------------------------------------------------
SQLMsDirectClass.ServerExec PROCEDURE()
  CODE
  IF SELF.KeepCase THEN RETURN SELF.RunQuery(CLIP(SELF.Query),'ServerExec').
  RETURN SELF.RunQuery(Lower(CLIP(SELF.Query)),'ServerExec')

SQLMsDirectClass.ServerExecEx PROCEDURE()
  CODE
  RETURN SELF.RunQuery(CLIP(SELF.Query),'ServerExecEx')

! envia el SQL, con log y ventana de proceso igual que SQLClass6
SQLMsDirectClass.RunQuery PROCEDURE(String pSql,String pMethod)
Res         BYTE
LogStart    LONG
ProgWin     WINDOW,AT(,,300,64),CENTER,COLOR(COLOR:White),FONT('Segoe UI',9,,FONT:regular)
                BOX,AT(0,0,300,3),USE(?PgTop),COLOR(0D77800H),FILL(0D77800H)
                STRING('Procesando consulta'),AT(14,9,272,14),USE(?PgTitle),FONT(,11,0404040H,FONT:bold)
                STRING(''),AT(14,26,272,10),USE(?PgText),FONT(,9,0808080H,FONT:regular)
                BOX,AT(14,42,272,5),USE(?PgBar0),COLOR(0EBEBEBH),FILL(0EBEBEBH)
                BOX,AT(14,42,90,5),USE(?PgBar),COLOR(0D77800H),FILL(0D77800H)
            END
  CODE
  IF SELF.ShowProgress THEN DO ProgOpen.
  IF LEN(SELF.LogFile) THEN LogStart = CLOCK() ; SELF.WriteLog('SQL> ' & CLIP(pSql)).
  SELF.ProgLast = CLOCK()
  SELF.SetProgress(0,'Ejecutando consulta...')
  Res = SELF.Db.Query(pSql)
  SELF.ProgMsQuery = ABS(CLOCK() - SELF.ProgLast) * 10
  IF Res
    SELF.SetProgress(0,'Error en la consulta: ' & SELF.Db.LastError)
  ELSIF SELF.Db.HasResult()
    SELF.SetProgress(0,'Consulta lista: ' & SELF.Db.RowCount() & ' filas en ' & SELF.ProgMsQuery & ' ms')
  ELSE
    SELF.SetProgress(0,'Consulta lista en ' & SELF.ProgMsQuery & ' ms')
  END
  IF SELF.ShowProgress THEN DO ProgClose.
  IF LEN(SELF.LogFile) THEN SELF.WriteLog('    -> ' & CHOOSE(Res = Level:Benign,'OK','ERROR ' & SELF.Db.LastError) & '  (' & ABS(CLOCK() - LogStart) & ' cs)').
  IF Res
    IF NOT SELF.SilentMode
      STOP('Error en QueryClass (SQL Server). Metodo ' & CLIP(pMethod) & '()<13,10>' & SELF.Db.LastError & '<13,10>Query Enviado:' & CLIP(pSql))
    END
    SELF.Db.FreeResult()
    RETURN Level:Notify
  END
  SELF.TakeResult()
  RETURN Level:Benign

ProgOpen ROUTINE
  OPEN(ProgWin)
  IF LEN(SELF.ProgressTitle) THEN ?PgTitle{PROP:Text} = SELF.ProgressTitle.
  ?PgText{PROP:Text} = CHOOSE(LEN(SELF.ProgressText) > 0,SELF.ProgressText,'Esperando la respuesta del servidor...')
  SETCURSOR(CURSOR:WAIT)
  DISPLAY

ProgClose ROUTINE
  SETCURSOR()
  CLOSE(ProgWin)

! con un resultado, las columnas y sus nombres salen del servidor (no del parser)
SQLMsDirectClass.TakeResult PROCEDURE()
I       LONG,AUTO
  CODE
  IF NOT SELF.Db.HasResult() THEN RETURN.
  SELF.Cols = SELF.Db.Columns()
  FREE(SELF.Fields)
  LOOP I = 1 TO SELF.Cols
    SELF.Fields.QFieldName = SELF.Db.ColName(I)
    SELF.Fields.QFieldLabel = SELF.Fields.QFieldName
    SELF.Fields.QFieldNo = I
    ADD(SELF.Fields)
  END

!------------------------------------------------------------------------------
SQLMsDirectClass.Next PROCEDURE()
  CODE
  IF SELF.Db.Next()
    SELF.State = False
    RETURN Level:Notify
  END
  SELF.State = True
  SELF.Records_Done += 1
  RETURN SELF.TakeRecord()

SQLMsDirectClass.Col PROCEDURE(Short Column)
  CODE
  RETURN SELF.Db.Col(Column)

SQLMsDirectClass.ColByName PROCEDURE(String Nombre)
  CODE
  RETURN SELF.Db.Col(SELF.Db.ColIndex(Nombre))

SQLMsDirectClass.IsNull PROCEDURE(Short NroCol)
  CODE
  RETURN SELF.Db.IsNull(NroCol)

! Si hay un resultado leido, cuenta sus filas (exacto, tambien con GROUP BY / DISTINCT).
! Si no, igual que SQLClass6: SELECT COUNT(*) con el FROM y el WHERE de la ultima consulta.
SQLMsDirectClass.Records PROCEDURE()
Loc:SQL_Backup CSTRING(20480)
Loc:SQL        CSTRING(20480)
  CODE
  IF SELF.Db.HasResult()
    SELF.Records = SELF.Db.RowCount()
    RETURN SELF.Records
  END
  IF NOT LEN(CLIP(SELF.SQL_From)) THEN RETURN SELF.Records.
  Loc:SQL_Backup = SELF.Query
  Loc:SQL = 'SELECT COUNT(*) ' & Lower(CLIP(SELF.SQL_From))
  IF LEN(CLIP(SELF.SQL_Where)) THEN Loc:SQL = Loc:SQL & ' ' & CLIP(SELF.SQL_Where).
  IF SELF.Exec(Loc:SQL) = Level:Benign AND SELF.Next() = Level:Benign
    SELF.Records = SELF.Col(1)
  ELSE
    SELF.Records = 0
  END
  SELF.Query = Loc:SQL_Backup
  RETURN SELF.Records

SQLMsDirectClass.Fetch PROCEDURE(Short FieldNo,String Query)
  CODE
  SELF.Pk_Col = FieldNo
  IF NOT SELF.Exec(Query) = Level:Benign THEN RETURN Level:Notify.
  IF NOT SELF.Next() = Level:Benign THEN RETURN Level:Benign.
  RETURN SELF.Col(SELF.Pk_Col)

SQLMsDirectClass.Fetch PROCEDURE(Short FieldNo,String Query,*String Result)
  CODE
  SELF.Pk_Col = FieldNo
  IF SELF.Exec(Query) THEN RETURN Level:Notify.
  IF SELF.Next() THEN RETURN Level:Notify.
  Result = SELF.Col(SELF.Pk_Col)
  RETURN Level:Benign

SQLMsDirectClass.UpdateBuffer PROCEDURE()
  CODE
  SELF.Primary_Field = SELF.Col(SELF.Pk_Col)
  IF SELF.Primary_fm.Fetch(SELF.Primary_Key)
    RETURN True
  ELSE
    RETURN False
  END

! Igual que SQLClass6.LoadQueue: campo por campo con WHAT, DEFORMAT con Col_Format, MaxReads y ventana.
! La cola tiene que coincidir con las columnas de la consulta.
SQLMsDirectClass.LoadQueue PROCEDURE(*Queue MyQueue,Byte WithCount,Byte ShowProgress)
MyField      ANY
Title        STRING(100)
Percentage   BYTE
I            LONG
Total        LONG
T0           LONG
WProgress WINDOW('SQL Class : Avance del Query'),AT(,,211,37),CENTER,IMM,SYSTEM,GRAY,DOUBLE,AUTO
       STRING(@s100),AT(9,3,169,10),USE(Title),TRN
       PROGRESS,USE(Percentage),AT(8,16,172,8),RANGE(0,100)
       STRING(@s100),AT(8,25,169,10),USE(MyField),TRN
       BUTTON,AT(184,5,27,23),USE(?Cancel),FLAT,LEFT,ICON(ICON:Cross)
     END
  CODE
  SETCURSOR(CURSOR:WAIT)
  IF SELF.FreeQueue THEN FREE(MyQueue).
  IF WithCount THEN I = SELF.Records().
  SELF.Records_Done = 0
  IF ShowProgress THEN OPEN(WProgress).
  T0 = CLOCK()
  SELF.ProgLast = T0
  IF SELF.ProgressFeq OR SELF.ProgressTextFeq
    Total = CHOOSE(SELF.Db.HasResult() = True,SELF.Db.RowCount(),0)
    SELF.SetProgress(0,'Cargando ' & Total & ' filas...')
  END
  LOOP
    IF NOT SELF.Next() = Level:Benign THEN BREAK.
    SELF.Records_Done -= 1                              ! Next() ya lo sumo; se cuenta abajo como en SQLClass6
    LOOP I = 1 TO SELF.Cols
      MyField &= WHAT(MyQueue,I)
      IF MyField &= NULL THEN BREAK.
      SELF.Format.QFormatNo = I
      GET(SELF.Format,SELF.Format.QFormatNo)
      IF ERRORCODE()
        MyField = SELF.Col(I)
      ELSE
        MyField = DEFORMAT(SELF.Col(I),SELF.Format.QFormatPic)
      END
    END
    ADD(MyQueue)
    IF ERRORCODE() THEN STOP(ERROR());SETCURSOR();RETURN Level:Notify.
    SELF.Records_Done += 1
    IF SELF.Records THEN Percentage = SELF.Records_Done / SELF.Records * 100.
    IF SELF.MaxReads AND SELF.Records_Done > SELF.MaxReads
      MESSAGE('EL QUERY ES DEMASIADO LARGO. LOS PARAMETROS INDICAN QUE NO SE LEAN MAS DE ' & SELF.MaxReads & ' registros.','SQL Class',ICON:Exclamation)
      BREAK
    END
    IF ShowProgress
      DISPLAY
      YIELD()
    END
    IF (SELF.ProgressFeq OR SELF.ProgressTextFeq) AND ABS(CLOCK() - SELF.ProgLast) >= SELF.ProgressDelay
      SELF.ProgLast = CLOCK()
      IF Total
        SELF.SetProgress(SELF.Records_Done * 100 / Total,'Cargando ' & SELF.Records_Done & ' de ' & Total & ' filas (' & |
                         INT(SELF.Records_Done * 100 / Total) & '%)')
      ELSE
        SELF.SetProgress(-1,'Cargando ' & SELF.Records_Done & ' filas...')
      END
    END
  END
  IF ShowProgress THEN CLOSE(WProgress).
  IF SELF.ProgressFeq OR SELF.ProgressTextFeq
    SELF.SetProgress(100,SELF.Records_Done & ' filas  -  consulta ' & SELF.ProgMsQuery & ' ms + carga ' & ABS(CLOCK() - T0) * 10 & ' ms')
  END
  SELF.Records = RECORDS(MyQueue)
  SETCURSOR()
  FREE(SELF.Format)
  RETURN Level:Benign

!------------------------------------------------------------------------------ nuevos
! avance en la ventana: la barra (Porc = -1 no la toca) y el texto; repinta ya porque durante la consulta
! y la carga no corre el ACCEPT de la ventana
SQLMsDirectClass.SetProgress PROCEDURE(Long Porc,String Texto)
  CODE
  IF NOT SELF.ProgressFeq AND NOT SELF.ProgressTextFeq THEN RETURN.
  IF SELF.ProgressFeq AND Porc >= 0
    SELF.ProgressFeq{PROP:Progress} = Porc
    DISPLAY(SELF.ProgressFeq)
  END
  IF SELF.ProgressTextFeq
    SELF.ProgressTextFeq{PROP:Text} = Texto
    DISPLAY(SELF.ProgressTextFeq)
  END
  YIELD()
  tmsd_RedrawWindow(0{PROP:Handle},0,0,0180h)          ! RDW_ALLCHILDREN + RDW_UPDATENOW: pinta ya lo pendiente

! parametros '?': se agregan antes de Exec/ExecEx y la consulta los consume (valores como texto, sin comillas ni escape)
SQLMsDirectClass.AddParam PROCEDURE(String Valor)
  CODE
  SELF.Db.AddParam(Valor)

SQLMsDirectClass.AddNullParam PROCEDURE()
  CODE
  SELF.Db.AddNullParam()

! sentencias preparadas, lotes e INSERT por nombre de campo (el trabajo lo hace TCWMsSQL)
SQLMsDirectClass.Prepare PROCEDURE(String Query)
  CODE
  RETURN SELF.TakeDbResult(SELF.Db.Prepare(Query),'preparar la sentencia')

SQLMsDirectClass.ExecPrepared PROCEDURE()
  CODE
  RETURN SELF.TakeDbResult(SELF.Db.ExecPrepared(),'ejecutar la sentencia preparada')

SQLMsDirectClass.AddRow PROCEDURE()
  CODE
  RETURN SELF.TakeDbResult(SELF.Db.AddRow(),'agregar la fila al lote')

SQLMsDirectClass.Campo PROCEDURE(String Nombre,String Valor)
  CODE
  SELF.Db.Campo(Nombre,Valor)

SQLMsDirectClass.CampoNulo PROCEDURE(String Nombre)
  CODE
  SELF.Db.CampoNulo(Nombre)

SQLMsDirectClass.CampoFecha PROCEDURE(String Nombre,Long Fecha)
  CODE
  SELF.Db.CampoFecha(Nombre,Fecha)

SQLMsDirectClass.CampoFechaHora PROCEDURE(String Nombre,Long Fecha,Long Hora)
  CODE
  SELF.Db.CampoFechaHora(Nombre,Fecha,Hora)

SQLMsDirectClass.Insertar PROCEDURE(String Tabla)
  CODE
  RETURN SELF.TakeDbResult(SELF.Db.Insertar(Tabla),'insertar en ' & CLIP(Tabla))

SQLMsDirectClass.InsertarLote PROCEDURE(String Tabla)
  CODE
  RETURN SELF.TakeDbResult(SELF.Db.InsertarLote(Tabla),'insertar el lote en ' & CLIP(Tabla))

SQLMsDirectClass.EnviarLote PROCEDURE()
  CODE
  RETURN SELF.TakeDbResult(SELF.Db.EnviarLote(),'enviar el lote')

! como el resto de la SQLClass: con SilentMode apagado avisa el error
SQLMsDirectClass.TakeDbResult PROCEDURE(Byte Res,String Que)
  CODE
  IF Res AND NOT SELF.SilentMode THEN STOP('SQLClass (SQL Server): no se pudo ' & CLIP(Que) & '<13,10>' & SELF.Db.LastError).
  RETURN Res

! siguiente resultado del mismo lote o procedimiento; se lee igual (Next / Col / LoadQueue)
SQLMsDirectClass.NextResult PROCEDURE()
  CODE
  SELF.Records_Done = 0
  SELF.Records      = 0
  IF SELF.Db.NextResult() THEN RETURN Level:Notify.
  SELF.TakeResult()
  RETURN Level:Benign

SQLMsDirectClass.Escape PROCEDURE(String Texto)
  CODE
  RETURN SELF.Db.Escape(Texto)

SQLMsDirectClass.Quote PROCEDURE(String Texto)
  CODE
  RETURN SELF.Db.Quote(Texto)

SQLMsDirectClass.InsertId PROCEDURE()
  CODE
  RETURN SELF.Db.InsertId

SQLMsDirectClass.AffectedRows PROCEDURE()
  CODE
  RETURN SELF.Db.AffectedRows

SQLMsDirectClass.ErrorText PROCEDURE()
  CODE
  RETURN SELF.Db.LastError

SQLMsDirectClass.ErrorCode PROCEDURE()
  CODE
  RETURN SELF.Db.LastErrno

SQLMsDirectClass.ServerVersion PROCEDURE()
  CODE
  RETURN SELF.Db.ServerVersion()

SQLMsDirectClass.BeginTransaction PROCEDURE()
  CODE
  RETURN SELF.Db.BeginTransaction()

SQLMsDirectClass.Commit PROCEDURE()
  CODE
  RETURN SELF.Db.Commit()

SQLMsDirectClass.Rollback PROCEDURE()
  CODE
  RETURN SELF.Db.Rollback()

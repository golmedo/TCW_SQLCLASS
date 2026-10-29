  MEMBER
!==============================================================================
! TCWMsSQL - implementacion (ver TCWMsSQL.inc). El trabajo con ODBC lo hace tcwmss.c.
!==============================================================================
  PRAGMA('compile(tcwmss.c)')
  MAP
    MODULE('tcwmss.c')
      tms_connect(LONG pConn,LONG pTimeout,LONG pErr,LONG pErrLen,LONG pState),LONG,NAME('_tms_connect')
      tms_disconnect(LONG pDbc),NAME('_tms_disconnect')
      tms_autocommit(LONG pDbc,LONG pOn,LONG pErr,LONG pErrLen,LONG pState),LONG,NAME('_tms_autocommit')
      tms_endtran(LONG pDbc,LONG pCommit,LONG pErr,LONG pErrLen,LONG pState),LONG,NAME('_tms_endtran')
      tms_getinfo(LONG pDbc,LONG pWhat,LONG pOut,LONG pOutLen),LONG,PROC,NAME('_tms_getinfo')
      tms_query(LONG pDbc,LONG pSql,LONG pNParams,LONG pParams,LONG pErr,LONG pErrLen,LONG pState,LONG pNative),LONG,NAME('_tms_query')
      tms_nextresult(LONG pRes,LONG pErr,LONG pErrLen,LONG pState),LONG,NAME('_tms_nextresult')
      tms_prepare(LONG pDbc,LONG pSql,LONG pErr,LONG pErrLen,LONG pState,LONG pNative),LONG,NAME('_tms_prepare')
      tms_execute(LONG pRes,LONG pRows,LONG pNParams,LONG pParams,LONG pErr,LONG pErrLen,LONG pState,LONG pNative),LONG,NAME('_tms_execute')
      tms_free(LONG pRes),NAME('_tms_free')
      tms_cols(LONG pRes),LONG,NAME('_tms_cols')
      tms_rows(LONG pRes),LONG,NAME('_tms_rows')
      tms_affected(LONG pRes),LONG,NAME('_tms_affected')
      tms_next(LONG pRes),LONG,NAME('_tms_next')
      tms_collen(LONG pRes,LONG pCol),LONG,NAME('_tms_collen')
      tms_colptr(LONG pRes,LONG pCol),LONG,NAME('_tms_colptr')
      tms_colname(LONG pRes,LONG pCol,LONG pOut,LONG pOutLen),LONG,PROC,NAME('_tms_colname')
    END
    MODULE('kernel32')
      tms_MoveMemory(LONG,LONG,LONG),PASCAL,NAME('RtlMoveMemory')
    END
  END

  INCLUDE('aberror.inc'),ONCE
  INCLUDE('TCWMsSQL.inc'),ONCE

!------------------------------------------------------------------------------
TCWMsSQL.Construct PROCEDURE()
  CODE
  SELF.Params &= NEW TCWMsSQL_Params
  SELF.Campos &= NEW TCWMsSQL_Campos
  SELF.PrepSql &= NEW CSTRING(20480)
  SELF.BatchSize = 500
  SELF.ConnectTimeout = 15
  SELF.AutoReconnect = 1
  SELF.IdentityAfterInsert = 1

TCWMsSQL.Destruct PROCEDURE()
  CODE
  SELF.Disconnect()
  SELF.ClearParams()
  DISPOSE(SELF.Params)
  DISPOSE(SELF.Campos)
  DISPOSE(SELF.PrepSql)
  IF NOT SELF.Batch &= NULL THEN DISPOSE(SELF.Batch).
  IF NOT SELF.ValBuf &= NULL THEN DISPOSE(SELF.ValBuf).

!------------------------------------------------------------------------------
! Acepta tres formas:
!   'Server=PC\INST;Database=base;User=u;Password=p;Timeout=15;Encrypt=0'  (como TCWMariaDB; sin User = seguridad de Windows)
!   'Driver={ODBC Driver 17 for SQL Server};Server=...;Uid=...;Pwd=...'   (cadena ODBC: se usa tal cual)
!   'servidor,base,usuario,clave'                                           (el owner del driver MSSQL de Clarion)
TCWMsSQL.SetConnection PROCEDURE(STRING pConnection)
Txt     CSTRING(4096)
Part    CSTRING(1024)
Key     CSTRING(64)
Val     CSTRING(1024)
Port    CSTRING(16)
P       LONG,AUTO
E       LONG,AUTO
N       LONG,AUTO
  CODE
  SELF.OdbcConnection = ''
  SELF.Host = '' ; SELF.Database = '' ; SELF.User = '' ; SELF.Password = ''
  Txt = CLIP(LEFT(pConnection))
  IF INSTRING('DRIVER=',UPPER(Txt),1,1) OR INSTRING('DSN=',UPPER(Txt),1,1)
    SELF.OdbcConnection = Txt
    RETURN
  END
  IF NOT INSTRING('=',Txt,1,1)                          ! owner de Clarion: servidor,base,usuario,clave
    Txt = Txt & ','
    N = 0
    LOOP
      P = INSTRING(',',Txt,1,1)
      IF P = 0 THEN BREAK.
      Val = CLIP(LEFT(SUB(Txt,1,P-1)))
      Txt = SUB(Txt,P+1,LEN(Txt)-P)
      N += 1
      CASE N
      OF 1 ; SELF.Host = Val
      OF 2 ; SELF.Database = Val
      OF 3 ; SELF.User = Val
      OF 4 ; SELF.Password = Val
      END
    END
    RETURN
  END
  Txt = Txt & ';'
  LOOP
    P = INSTRING(';',Txt,1,1)
    IF P = 0 THEN BREAK.
    Part = SUB(Txt,1,P-1)
    Txt = SUB(Txt,P+1,LEN(Txt)-P)
    E = INSTRING('=',Part,1,1)
    IF E = 0 THEN CYCLE.
    Key = UPPER(CLIP(LEFT(SUB(Part,1,E-1))))
    Val = CLIP(LEFT(SUB(Part,E+1,LEN(Part)-E)))
    CASE Key
    OF 'SERVER' OROF 'HOST' OROF 'DATA SOURCE' OROF 'ADDRESS'
      SELF.Host = Val
    OF 'PORT'
      Port = Val
    OF 'DATABASE' OROF 'DB' OROF 'INITIAL CATALOG'
      SELF.Database = Val
    OF 'USER' OROF 'UID' OROF 'USER ID' OROF 'USERNAME'
      SELF.User = Val
    OF 'PASSWORD' OROF 'PWD'
      SELF.Password = Val
    OF 'TIMEOUT' OROF 'CONNECT TIMEOUT' OROF 'CONNECTION TIMEOUT'
      SELF.ConnectTimeout = Val
    OF 'ENCRYPT' OROF 'SSL'
      SELF.Encrypt = CHOOSE(INLIST(UPPER(Val),'1','TRUE','YES','MANDATORY','STRICT') > 0)
    OF 'TRUSTED_CONNECTION' OROF 'INTEGRATED SECURITY'
      IF INLIST(UPPER(Val),'1','TRUE','YES','SSPI') THEN SELF.User = ''.
    END
  END
  IF Port <> '' AND NOT INSTRING(',',SELF.Host,1,1) THEN SELF.Host = SELF.Host & ',' & Port.

! cadena ODBC para un driver; la clave va entre llaves (puede tener ';')
TCWMsSQL.BuildConnection PROCEDURE(STRING pDriver)
Pw      CSTRING(600)
I       LONG,AUTO
  CODE
  LOOP I = 1 TO LEN(SELF.Password)
    Pw = Pw & SELF.Password[I] & CHOOSE(SELF.Password[I] = '}','}','')
  END
  RETURN 'Driver={{' & CLIP(pDriver) & '};Server=' & SELF.Host & ';Database=' & SELF.Database & |
         CHOOSE(SELF.User <> '',';Uid=' & SELF.User & ';Pwd={{' & Pw & '}',';Trusted_Connection=yes') & |
         ';Encrypt=' & CHOOSE(SELF.Encrypt <> 0,'yes','no') & |
         CHOOSE(SELF.Encrypt <> 0 AND INSTRING('18',pDriver,1,1) > 0,';TrustServerCertificate=yes','') & ';APP=Clarion TCWMsSQL'

TCWMsSQL.Connect PROCEDURE(<STRING pConnection>)
Cs      CSTRING(2048)
Drv     CSTRING(80),DIM(3)
I       LONG,AUTO
  CODE
  SELF.Disconnect()
  IF NOT OMITTED(pConnection) THEN SELF.SetConnection(pConnection).
  IF SELF.OdbcConnection <> ''
    Cs = SELF.OdbcConnection
    SELF.hConn = tms_connect(ADDRESS(Cs),SELF.ConnectTimeout,ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf))
    SELF.DriverUsed = 'cadena ODBC'
  ELSE
    IF SELF.Host = '' THEN RETURN SELF.SetError('Falta el servidor (Server=PC\INSTANCIA)').
    Drv[1] = CHOOSE(SELF.Driver <> '',SELF.Driver,'ODBC Driver 17 for SQL Server')
    Drv[2] = CHOOSE(SELF.Driver <> '','','ODBC Driver 18 for SQL Server')
    Drv[3] = CHOOSE(SELF.Driver <> '','','SQL Server')
    LOOP I = 1 TO 3
      IF Drv[I] = '' THEN BREAK.
      Cs = SELF.BuildConnection(Drv[I])
      SELF.hConn = tms_connect(ADDRESS(Cs),SELF.ConnectTimeout,ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf))
      IF SELF.hConn THEN SELF.DriverUsed = Drv[I] ; BREAK.
      IF SELF.StateBuf <> 'IM002' THEN BREAK.         ! IM002 = ese driver no esta instalado: prueba el siguiente
    END
  END
  IF NOT SELF.hConn THEN RETURN SELF.TakeError('No se pudo conectar a ' & CHOOSE(SELF.Host <> '',SELF.Host,'la base')).
  SELF.InTransaction = False
  SELF.LastError = ''
  SELF.LastErrno = 0
  SELF.SqlState = ''
  RETURN Level:Benign

TCWMsSQL.Disconnect PROCEDURE()
  CODE
  SELF.FreeResult()
  IF SELF.hPrep
    tms_free(SELF.hPrep)
    SELF.hPrep = 0
  END
  SELF.PrepSql = ''
  SELF.ClearBatch()
  FREE(SELF.Campos)
  IF SELF.hConn
    tms_disconnect(SELF.hConn)
    SELF.hConn = 0
  END
  SELF.InTransaction = False

TCWMsSQL.Connected PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.hConn <> 0)

TCWMsSQL.Ping PROCEDURE()
  CODE
  RETURN SELF.Query('SELECT 1')

!------------------------------------------------------------------------------
! Ejecuta y lee el primer resultado entero. Con IdentityAfterInsert, a un INSERT le agrega
! '; SELECT SCOPE_IDENTITY()' en el mismo lote (en otro lote SCOPE_IDENTITY da NULL) y lo deja en InsertId.
TCWMsSQL.Query PROCEDURE(STRING pSql)
Sql         &CSTRING
ParBuf      &STRING
LenVar      LONG
Pos         LONG,AUTO
Total       LONG,AUTO
I           LONG,AUTO
NPar        LONG,AUTO
R           LONG,AUTO
ConId       BYTE
Up          CSTRING(20)
  CODE
  SELF.FreeResult()
  SELF.AffectedRows = 0
  SELF.InsertId = 0
  IF NOT SELF.hConn THEN SELF.ClearParams() ; RETURN SELF.SetError('No hay conexion con el servidor (llame a Connect)').
  Up = UPPER(SUB(LEFT(pSql),1,7))
  ConId = CHOOSE(SELF.IdentityAfterInsert AND SUB(Up,1,6) = 'INSERT' AND NOT INSTRING('OUTPUT',UPPER(pSql),1,1))
  Sql &= NEW CSTRING(LEN(CLIP(pSql)) + 64)
  Sql = CLIP(pSql)
  IF ConId THEN Sql = Sql & '; SELECT CAST(SCOPE_IDENTITY() AS varchar(40))'.
  ! parametros: por cada uno un LONG con el largo (-1 = NULL) y los bytes
  NPar = RECORDS(SELF.Params)
  IF NPar
    Total = 0
    LOOP I = 1 TO NPar
      GET(SELF.Params,I)
      Total += 4 + CHOOSE(SELF.Params.Len > 0,SELF.Params.Len,0)
    END
    ParBuf &= NEW STRING(Total)
    Pos = 0
    LOOP I = 1 TO NPar
      GET(SELF.Params,I)
      LenVar = SELF.Params.Len
      tms_MoveMemory(ADDRESS(ParBuf) + Pos,ADDRESS(LenVar),4)
      Pos += 4
      IF LenVar > 0
        tms_MoveMemory(ADDRESS(ParBuf) + Pos,ADDRESS(SELF.Params.Val),LenVar)
        Pos += LenVar
      END
    END
  END
  LOOP 2 TIMES
    R = tms_query(SELF.hConn,ADDRESS(Sql),NPar,CHOOSE(NPar > 0,ADDRESS(ParBuf),0), |
                  ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf),ADDRESS(SELF.Native))
    IF R OR NOT SELF.AutoReconnect OR SELF.InTransaction OR SUB(SELF.StateBuf,1,2) <> '08' THEN BREAK.
    IF SELF.Connect() <> Level:Benign THEN BREAK.     ! 08xxx = se cayo la conexion: reconecta y reintenta una vez
  END
  DISPOSE(Sql)
  IF NPar THEN DISPOSE(ParBuf).
  SELF.ClearParams()
  IF NOT R THEN RETURN SELF.TakeError('Error en la consulta').
  SELF.hRes = R
  SELF.AffectedRows = tms_affected(R)
  IF ConId AND tms_cols(R) = 1
    IF tms_next(R) THEN SELF.InsertId = SELF.Col(1).
    SELF.FreeResult()
  ELSIF tms_cols(R) = 0
    SELF.FreeResult()
  ELSE
    SELF.AffectedRows = tms_rows(R)
  END
  SELF.LastError = ''
  SELF.LastErrno = 0
  SELF.SqlState = ''
  RETURN Level:Benign

TCWMsSQL.AddParam PROCEDURE(STRING pValue)
L       LONG,AUTO
  CODE
  L = LEN(CLIP(pValue))
  SELF.Params.Val &= NEW STRING(CHOOSE(L > 0,L,1))
  IF L THEN SELF.Params.Val = pValue[1 : L].
  SELF.Params.Len = L
  ADD(SELF.Params)

TCWMsSQL.AddNullParam PROCEDURE()
  CODE
  SELF.Params.Val &= NEW STRING(1)
  SELF.Params.Len = -1
  ADD(SELF.Params)

TCWMsSQL.ClearParams PROCEDURE()
I       LONG,AUTO
  CODE
  LOOP I = 1 TO RECORDS(SELF.Params)
    GET(SELF.Params,I)
    DISPOSE(SELF.Params.Val)
  END
  FREE(SELF.Params)

TCWMsSQL.ParamCount PROCEDURE()
  CODE
  RETURN RECORDS(SELF.Params)

TCWMsSQL.NextResult PROCEDURE()
R       LONG,AUTO
  CODE
  IF NOT SELF.hRes THEN RETURN Level:Notify.
  R = tms_nextresult(SELF.hRes,ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf))
  IF R = 1 THEN RETURN Level:Benign.
  IF R < 0 THEN SELF.TakeError('Error en el resultado siguiente').
  SELF.FreeResult()
  RETURN Level:Notify

!------------------------------------------------------------------------------ sentencias preparadas
TCWMsSQL.Prepare PROCEDURE(STRING pSql)
Sql     &CSTRING
  CODE
  IF NOT SELF.hConn THEN RETURN SELF.SetError('No hay conexion con el servidor (llame a Connect)').
  SELF.FreeResult()                                     ! sin MARS hay una sola sentencia activa por conexion
  IF SELF.hPrep
    tms_free(SELF.hPrep)
    SELF.hPrep = 0
  END
  SELF.ClearBatch()
  Sql &= NEW CSTRING(LEN(CLIP(pSql)) + 1)
  Sql = CLIP(pSql)
  SELF.hPrep = tms_prepare(SELF.hConn,ADDRESS(Sql),ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf),ADDRESS(SELF.Native))
  DISPOSE(Sql)
  IF NOT SELF.hPrep
    SELF.PrepSql = ''
    RETURN SELF.TakeError('Error al preparar la sentencia')
  END
  SELF.PrepSql = CLIP(pSql)
  RETURN Level:Benign

TCWMsSQL.PrepareIfNew PROCEDURE(STRING pSql)
  CODE
  IF SELF.hPrep AND SELF.PrepSql = CLIP(pSql) THEN RETURN Level:Benign.
  IF SELF.BatchRows THEN SELF.EnviarLote().            ! las filas pendientes son de la sentencia anterior
  RETURN SELF.Prepare(pSql)

! con filas pendientes (AddRow) las manda todas en un viaje; si no, una fila con los AddParam actuales
TCWMsSQL.ExecPrepared PROCEDURE()
Ok      LONG,AUTO
  CODE
  IF NOT SELF.hPrep THEN SELF.ClearParams() ; RETURN SELF.SetError('No hay sentencia preparada (llame a Prepare)').
  SELF.FreeResult()                                     ! un resultado con mas resultados pendientes deja la conexion ocupada
  SELF.AffectedRows = 0
  IF SELF.BatchRows = 0
    SELF.PackParams()
    SELF.ClearParams()
    SELF.BatchRows = 1
  END
  Ok = tms_execute(SELF.hPrep,SELF.BatchRows,SELF.BatchParams,CHOOSE(SELF.BatchLen > 0,ADDRESS(SELF.Batch),0), |
                   ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf),ADDRESS(SELF.Native))
  SELF.ClearBatch()
  IF NOT Ok THEN RETURN SELF.TakeError('Error al ejecutar la sentencia preparada').
  SELF.AffectedRows = tms_affected(SELF.hPrep)
  SELF.LastError = ''
  SELF.LastErrno = 0
  SELF.SqlState = ''
  RETURN Level:Benign

TCWMsSQL.AddRow PROCEDURE()
  CODE
  IF SELF.BatchRows AND RECORDS(SELF.Params) <> SELF.BatchParams
    SELF.ClearParams()
    RETURN SELF.SetError('Cada fila del lote tiene que tener la misma cantidad de valores (' & SELF.BatchParams & ')')
  END
  SELF.PackParams()
  SELF.ClearParams()
  SELF.BatchRows += 1
  IF SELF.BatchSize AND SELF.BatchRows >= SELF.BatchSize THEN RETURN SELF.ExecPrepared().
  RETURN Level:Benign

TCWMsSQL.PendingRows PROCEDURE()
  CODE
  RETURN SELF.BatchRows

TCWMsSQL.EnviarLote PROCEDURE()
  CODE
  IF SELF.BatchRows = 0 THEN RETURN Level:Benign.
  RETURN SELF.ExecPrepared()

! agrega los AddParam actuales al lote: por cada valor un LONG con el largo (-1 = NULL) y los bytes
TCWMsSQL.PackParams PROCEDURE()
Need    LONG,AUTO
I       LONG,AUTO
LenVar  LONG
NewBuf  &STRING
  CODE
  Need = 0
  LOOP I = 1 TO RECORDS(SELF.Params)
    GET(SELF.Params,I)
    Need += 4 + CHOOSE(SELF.Params.Len > 0,SELF.Params.Len,0)
  END
  IF SELF.Batch &= NULL OR SELF.BatchLen + Need > SIZE(SELF.Batch)
    NewBuf &= NEW STRING(CHOOSE(SELF.BatchLen + Need > 65536,(SELF.BatchLen + Need) * 2,65536))
    IF SELF.BatchLen THEN tms_MoveMemory(ADDRESS(NewBuf),ADDRESS(SELF.Batch),SELF.BatchLen).
    IF NOT SELF.Batch &= NULL THEN DISPOSE(SELF.Batch).
    SELF.Batch &= NewBuf
  END
  LOOP I = 1 TO RECORDS(SELF.Params)
    GET(SELF.Params,I)
    LenVar = SELF.Params.Len
    tms_MoveMemory(ADDRESS(SELF.Batch) + SELF.BatchLen,ADDRESS(LenVar),4)
    SELF.BatchLen += 4
    IF LenVar > 0
      tms_MoveMemory(ADDRESS(SELF.Batch) + SELF.BatchLen,ADDRESS(SELF.Params.Val),LenVar)
      SELF.BatchLen += LenVar
    END
  END
  SELF.BatchParams = RECORDS(SELF.Params)

TCWMsSQL.ClearBatch PROCEDURE()
  CODE
  SELF.BatchLen = 0
  SELF.BatchRows = 0
  SELF.BatchParams = 0

!------------------------------------------------------------------------------ INSERT por nombre de campo
! el valor va como parametro: el servidor lo convierte al tipo de la columna (texto, numero, fecha 'aaaa-mm-dd')
TCWMsSQL.Campo PROCEDURE(STRING pNombre,STRING pValor)
  CODE
  SELF.Campos.Nombre = CLIP(pNombre)
  ADD(SELF.Campos)
  SELF.AddParam(pValor)

TCWMsSQL.CampoNulo PROCEDURE(STRING pNombre)
  CODE
  SELF.Campos.Nombre = CLIP(pNombre)
  ADD(SELF.Campos)
  SELF.AddNullParam()

TCWMsSQL.CampoFecha PROCEDURE(STRING pNombre,LONG pFecha)
  CODE
  IF pFecha = 0
    SELF.CampoNulo(pNombre)
  ELSE
    SELF.Campo(pNombre,FORMAT(pFecha,@d10-))
  END

TCWMsSQL.CampoFechaHora PROCEDURE(STRING pNombre,LONG pFecha,LONG pHora)
  CODE
  IF pFecha = 0
    SELF.CampoNulo(pNombre)
  ELSE
    SELF.Campo(pNombre,FORMAT(pFecha,@d10-) & ' ' & CHOOSE(pHora > 0,FORMAT(pHora,@t04),'00:00:00'))
  END

! 'INSERT INTO tabla (c1,c2,...) VALUES (?,?,...)' con los campos agregados (y los borra)
TCWMsSQL.InsertSql PROCEDURE(STRING pTabla)
Cols    CSTRING(20480)
Marks   CSTRING(4096)
I       LONG,AUTO
  CODE
  LOOP I = 1 TO RECORDS(SELF.Campos)
    GET(SELF.Campos,I)
    Cols = Cols & CHOOSE(I > 1,',','') & SELF.Campos.Nombre
    Marks = Marks & CHOOSE(I > 1,',?','?')
  END
  FREE(SELF.Campos)
  RETURN 'INSERT INTO ' & CLIP(pTabla) & ' (' & Cols & ') VALUES (' & Marks & ')'

TCWMsSQL.Insertar PROCEDURE(STRING pTabla)
Sql     CSTRING(25000)
  CODE
  Sql = SELF.InsertSql(pTabla)
  IF SELF.PrepareIfNew(Sql) THEN SELF.ClearParams() ; RETURN Level:Notify.
  RETURN SELF.ExecPrepared()

TCWMsSQL.InsertarLote PROCEDURE(STRING pTabla)
Sql     CSTRING(25000)
  CODE
  Sql = SELF.InsertSql(pTabla)
  IF SELF.PrepareIfNew(Sql) THEN SELF.ClearParams() ; RETURN Level:Notify.
  RETURN SELF.AddRow()

TCWMsSQL.FreeResult PROCEDURE()
  CODE
  IF SELF.hRes
    tms_free(SELF.hRes)
    SELF.hRes = 0
  END

TCWMsSQL.HasResult PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.hRes <> 0)

TCWMsSQL.Next PROCEDURE()
  CODE
  IF NOT SELF.hRes THEN RETURN Level:Notify.
  IF tms_next(SELF.hRes) THEN RETURN Level:Benign.
  RETURN Level:Notify

TCWMsSQL.Columns PROCEDURE()
  CODE
  RETURN tms_cols(SELF.hRes)

TCWMsSQL.RowCount PROCEDURE()
  CODE
  RETURN tms_rows(SELF.hRes)

TCWMsSQL.Col PROCEDURE(LONG pCol)
L       LONG,AUTO
  CODE
  L = tms_collen(SELF.hRes,pCol)
  IF L <= 0 THEN RETURN ''.
  RETURN SELF.PtrToString(tms_colptr(SELF.hRes,pCol),L)

TCWMsSQL.IsNull PROCEDURE(LONG pCol)
  CODE
  RETURN CHOOSE(tms_collen(SELF.hRes,pCol) = -1)

TCWMsSQL.ColName PROCEDURE(LONG pCol)
Nm      CSTRING(130)
  CODE
  tms_colname(SELF.hRes,pCol,ADDRESS(Nm),SIZE(Nm))
  RETURN Nm

TCWMsSQL.ColIndex PROCEDURE(STRING pName)
I       LONG,AUTO
  CODE
  LOOP I = 1 TO tms_cols(SELF.hRes)
    IF UPPER(SELF.ColName(I)) = UPPER(CLIP(pName)) THEN RETURN I.
  END
  RETURN 0

!------------------------------------------------------------------------------
! SQL Server solo necesita duplicar la comilla simple (la barra invertida no es especial)
TCWMsSQL.Escape PROCEDURE(STRING pText)
L       LONG,AUTO
N       LONG,AUTO
I       LONG,AUTO
Buf     &STRING
Res     ANY
  CODE
  L = LEN(CLIP(pText))
  IF L = 0 THEN RETURN ''.
  Buf &= NEW STRING(L * 2)
  N = 0
  LOOP I = 1 TO L
    IF pText[I] = '''' THEN N += 1; Buf[N] = ''''.
    N += 1; Buf[N] = pText[I]
  END
  Res = Buf[1 : N]
  DISPOSE(Buf)
  RETURN Res

TCWMsSQL.Quote PROCEDURE(STRING pText)
  CODE
  RETURN '''' & SELF.Escape(pText) & ''''

! transacciones con la API de ODBC (autocommit apagado hasta Commit / Rollback)
TCWMsSQL.BeginTransaction PROCEDURE()
  CODE
  IF NOT SELF.hConn THEN RETURN SELF.SetError('No hay conexion').
  IF NOT tms_autocommit(SELF.hConn,0,ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf)) THEN RETURN SELF.TakeError('BeginTransaction').
  SELF.InTransaction = True
  RETURN Level:Benign

TCWMsSQL.Commit PROCEDURE()
Ok      LONG,AUTO
  CODE
  IF NOT SELF.hConn THEN RETURN SELF.SetError('No hay conexion').
  SELF.FreeResult()
  Ok = tms_endtran(SELF.hConn,1,ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf))
  SELF.InTransaction = False
  IF NOT Ok THEN RETURN SELF.TakeError('Commit').
  RETURN Level:Benign

TCWMsSQL.Rollback PROCEDURE()
Ok      LONG,AUTO
  CODE
  IF NOT SELF.hConn THEN RETURN SELF.SetError('No hay conexion').
  SELF.FreeResult()
  Ok = tms_endtran(SELF.hConn,0,ADDRESS(SELF.ErrBuf),SIZE(SELF.ErrBuf),ADDRESS(SELF.StateBuf))
  SELF.InTransaction = False
  IF NOT Ok THEN RETURN SELF.TakeError('Rollback').
  RETURN Level:Benign

! version del servidor sin consulta (SQLGetInfo SQL_DBMS_VER: '16.00.1000'): no pisa el resultado abierto
TCWMsSQL.ServerVersion PROCEDURE()
Txt     CSTRING(80)
  CODE
  tms_getinfo(SELF.hConn,18,ADDRESS(Txt),SIZE(Txt))
  RETURN Txt

TCWMsSQL.ClientVersion PROCEDURE()
Nm      CSTRING(80)
Ver     CSTRING(40)
  CODE
  tms_getinfo(SELF.hConn,6,ADDRESS(Nm),SIZE(Nm))
  tms_getinfo(SELF.hConn,7,ADDRESS(Ver),SIZE(Ver))
  RETURN CLIP(SELF.DriverUsed) & ' (' & Nm & ' ' & Ver & ')'

!------------------------------------------------------------------------------ internos
TCWMsSQL.SetError PROCEDURE(STRING pText,LONG pErrno=0)
  CODE
  SELF.LastError = pText
  SELF.LastErrno = pErrno
  SELF.SqlState = ''
  RETURN Level:Notify

TCWMsSQL.TakeError PROCEDURE(STRING pWhat)
  CODE
  SELF.LastErrno = SELF.Native
  SELF.SqlState = SELF.StateBuf
  SELF.LastError = CLIP(pWhat) & ': ' & SELF.ErrBuf & CHOOSE(SELF.Native <> 0,' (' & SELF.Native & ')','')
  RETURN Level:Notify

TCWMsSQL.PtrToString PROCEDURE(LONG pPtr,LONG pLen)
  CODE
  IF pPtr = 0 OR pLen <= 0 THEN RETURN ''.
  IF SELF.ValBuf &= NULL OR SIZE(SELF.ValBuf) < pLen
    IF NOT SELF.ValBuf &= NULL THEN DISPOSE(SELF.ValBuf).
    SELF.ValBuf &= NEW STRING(CHOOSE(pLen < 4096,4096,pLen))
  END
  tms_MoveMemory(ADDRESS(SELF.ValBuf),pPtr,pLen)
  RETURN SELF.ValBuf[1 : pLen]

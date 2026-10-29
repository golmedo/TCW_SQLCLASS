!==============================================================================
! TCWMsSQL - acceso directo a SQL Server desde Clarion (Templates Clarion)
! Usa la API de ODBC (odbc32.dll, cargada en runtime) con el driver de Microsoft "ODBC Driver 17/18 for SQL Server":
! sin el driver MSSQL de Clarion, sin tabla de trabajo, sin limite de columnas ni de largo.
! El motor esta en tcwmss.c (lo compila Clarion dentro del exe). No hay DLL propia para distribuir.
! Convencion de retorno igual a SQLClass: Level:Benign (0) = bien, Level:Notify (1) = error (ver LastError).
!==============================================================================
 OMIT('_EndOfInclude_',_TCWMsSQLPresente_)
_TCWMsSQLPresente_ EQUATE(1)

TCWMsSQL_Params     QUEUE,TYPE
Val                   &STRING
Len                   LONG                  ! -1 = NULL
                    END

TCWMsSQL_Campos     QUEUE,TYPE
Nombre                CSTRING(129)
                    END

TCWMsSQL            CLASS,TYPE,MODULE('TCWMsSQL.clw'),LINK('TCWMsSQL.clw')
! conexion
Host                  CSTRING(256)          ! 'PC\INSTANCIA' o 'servidor,1433'
User                  CSTRING(128)          ! vacio = seguridad integrada de Windows
Password              CSTRING(256)
Database              CSTRING(128)
Driver                CSTRING(80)           ! vacio = prueba ODBC Driver 17, 18 y el viejo 'SQL Server'
Encrypt               BYTE                  ! 1 = conexion cifrada (con el Driver 18 ademas confia en el certificado)
ConnectTimeout        LONG                  ! segundos
AutoReconnect         BYTE                  ! 1 = si se cayo la conexion, reconecta y reintenta una vez
IdentityAfterInsert   BYTE                  ! 1 = un INSERT devuelve SCOPE_IDENTITY() en InsertId (mismo lote)
OdbcConnection        CSTRING(2048)         ! cadena ODBC completa: si tiene valor se usa tal cual
BatchSize             LONG                  ! filas por envio de InsertarLote / AddRow (por defecto 500; 0 = solo al llamar EnviarLote)
! estado
hConn                 LONG,PROTECTED
hRes                  LONG,PROTECTED
Params                &TCWMsSQL_Params,PROTECTED
Campos                &TCWMsSQL_Campos,PROTECTED
hPrep                 LONG,PROTECTED        ! sentencia preparada
PrepSql               &CSTRING,PROTECTED    ! su texto (para no prepararla de nuevo)
Batch                 &STRING,PROTECTED     ! filas pendientes: por cada valor un LONG con el largo y los bytes
BatchLen              LONG,PROTECTED
BatchRows             LONG,PROTECTED
BatchParams           LONG,PROTECTED
ValBuf                &STRING,PROTECTED
ErrBuf                CSTRING(2048),PROTECTED
StateBuf              CSTRING(6),PROTECTED
Native                LONG,PROTECTED
DriverUsed            CSTRING(80)
LastError             CSTRING(2048)
LastErrno             LONG                  ! numero de error de SQL Server (2627 = clave duplicada, 208 = objeto inexistente...)
SqlState              CSTRING(6)
AffectedRows          LONG
InsertId              LONG
InTransaction         BYTE
! metodos
Construct             PROCEDURE()
Destruct              PROCEDURE()
SetConnection         PROCEDURE(STRING pConnection)   ! 'Server=x;Database=y;User=u;Password=p', una cadena ODBC o 'servidor,base,usuario,clave'
Connect               PROCEDURE(<STRING pConnection>),BYTE,PROC
Disconnect            PROCEDURE()
Connected             PROCEDURE(),BYTE
Ping                  PROCEDURE(),BYTE,PROC
Query                 PROCEDURE(STRING pSql),BYTE,PROC                ! usa los parametros agregados con AddParam (y los borra)
AddParam              PROCEDURE(STRING pValue)                       ! valor para el proximo '?' (texto; el servidor lo convierte)
AddNullParam          PROCEDURE()
ClearParams           PROCEDURE()
ParamCount            PROCEDURE(),LONG
NextResult            PROCEDURE(),BYTE,PROC                          ! siguiente resultado del mismo lote / procedimiento; Notify = no hay mas
! sentencias preparadas: el servidor analiza el SQL una sola vez y despues solo recibe los valores
Prepare               PROCEDURE(STRING pSql),BYTE,PROC               ! 'INSERT INTO t (a,b) VALUES (?,?)'
ExecPrepared          PROCEDURE(),BYTE,PROC                          ! con los AddParam actuales, o manda las filas pendientes de AddRow
AddRow                PROCEDURE(),BYTE,PROC                          ! los AddParam actuales son una fila del lote (se manda solo al llegar a BatchSize)
PendingRows           PROCEDURE(),LONG
! INSERT por nombre de campo, sin comillas ni escape: Campo(...) por cada columna y despues Insertar o InsertarLote
Campo                 PROCEDURE(STRING pNombre,STRING pValor)
CampoNulo             PROCEDURE(STRING pNombre)
CampoFecha            PROCEDURE(STRING pNombre,LONG pFecha)          ! fecha de Clarion; 0 = NULL
CampoFechaHora        PROCEDURE(STRING pNombre,LONG pFecha,LONG pHora)
Insertar              PROCEDURE(STRING pTabla),BYTE,PROC             ! una fila ya (la sentencia se prepara una vez y se reutiliza)
InsertarLote          PROCEDURE(STRING pTabla),BYTE,PROC             ! junta la fila y manda de a BatchSize filas en un solo viaje
EnviarLote            PROCEDURE(),BYTE,PROC                          ! manda las filas que queden (llamar al terminar)
FreeResult            PROCEDURE()
HasResult             PROCEDURE(),BYTE
Next                  PROCEDURE(),BYTE,PROC
Columns               PROCEDURE(),LONG
RowCount              PROCEDURE(),LONG
Col                   PROCEDURE(LONG pCol),STRING
IsNull                PROCEDURE(LONG pCol),BYTE
ColName               PROCEDURE(LONG pCol),STRING
ColIndex              PROCEDURE(STRING pName),LONG
Escape                PROCEDURE(STRING pText),STRING
Quote                 PROCEDURE(STRING pText),STRING
BeginTransaction      PROCEDURE(),BYTE,PROC
Commit                PROCEDURE(),BYTE,PROC
Rollback              PROCEDURE(),BYTE,PROC
ServerVersion         PROCEDURE(),STRING
ClientVersion         PROCEDURE(),STRING
BuildConnection       PROCEDURE(STRING pDriver),STRING,PROTECTED
PackParams            PROCEDURE(),PROTECTED                         ! agrega los AddParam actuales al lote
ClearBatch            PROCEDURE(),PROTECTED
PrepareIfNew          PROCEDURE(STRING pSql),BYTE,PROTECTED
InsertSql             PROCEDURE(STRING pTabla),STRING,PROTECTED
SetError              PROCEDURE(STRING pText,LONG pErrno=0),BYTE,PROTECTED
TakeError             PROCEDURE(STRING pWhat),BYTE,PROC,PROTECTED
PtrToString           PROCEDURE(LONG pPtr,LONG pLen),STRING,PROTECTED
                    END

 _EndOfInclude_

!==============================================================================
! TCWMariaDB - acceso directo a MariaDB / MySQL desde Clarion (Templates Clarion)
! Llama a libmariadb.dll (MariaDB Connector/C, LGPL) por su API publica. Sin ODBC ni driver de archivos.
! Proyecto: link de libmariadb.lib; junto al .exe: libmariadb.dll.
! Convencion de retorno igual a SQLClass: Level:Benign (0) = bien, Level:Notify (1) = error (ver LastError).
!==============================================================================
 OMIT('_EndOfInclude_',_TCWMariaDBPresente_)
_TCWMariaDBPresente_ EQUATE(1)

TCWMariaDB_Params   QUEUE,TYPE
Val                   &STRING
Len                   LONG                  ! -1 = NULL
                    END

TCWMariaDB_Campos   QUEUE,TYPE
Nombre                CSTRING(129)
                    END

TCWMariaDB          CLASS,TYPE,MODULE('TCWMariaDB.clw'),LINK('TCWMariaDB.clw')
! conexion
Host                  CSTRING(256)
Port                  LONG
User                  CSTRING(128)
Password              CSTRING(256)
Database              CSTRING(128)
Charset               CSTRING(32)           ! 'latin1' (por defecto) = textos de Clarion sin conversion
ConnectTimeout        LONG                  ! segundos
AutoReconnect         BYTE                  ! 1 = si se cayo la conexion, reconecta y reintenta una vez
SSL                   BYTE                  ! 0 = usa TLS si el servidor lo ofrece, sin exigirlo (servidores viejos); 1 = exige TLS y verifica el certificado
BatchSize             LONG                  ! filas por envio de InsertarLote / AddRow (por defecto 500; 0 = solo al llamar EnviarLote)
MaxBatchBytes         LONG                  ! un INSERT de varias filas se manda antes de pasar este tamano (por defecto 512 KB; MySQL 5.0: max_allowed_packet 1 MB)
! estado
hConn                 LONG,PROTECTED
hRes                  LONG,PROTECTED
Row                   LONG,PROTECTED
Lengths               LONG,PROTECTED
NumFields             LONG,PROTECTED
ValBuf                &STRING,PROTECTED
Params                &TCWMariaDB_Params,PROTECTED
Campos                &TCWMariaDB_Campos,PROTECTED
PrepSql               &CSTRING,PROTECTED    ! sentencia de Prepare (los '?' se reemplazan del lado del cliente)
BatchHead             &CSTRING,PROTECTED    ! 'INSERT INTO t (a,b) VALUES' de la sentencia preparada
BatchTpl              &CSTRING,PROTECTED    ! ' (?,?)': la fila que se repite en el INSERT de varias filas
Batch                 &STRING,PROTECTED     ! INSERT de varias filas que se esta armando
BatchLen              LONG,PROTECTED
BatchRows             LONG,PROTECTED
LastError             CSTRING(1024)
LastErrno             LONG
AffectedRows          LONG
InsertId              LONG
! metodos
Construct             PROCEDURE()
Destruct              PROCEDURE()
SetConnection         PROCEDURE(STRING pConnection)   ! 'Server=x;Port=3306;Database=y;User=u;Password=p;Charset=latin1;Timeout=10'
Connect               PROCEDURE(<STRING pConnection>),BYTE,PROC
Disconnect            PROCEDURE()
Connected             PROCEDURE(),BYTE
Ping                  PROCEDURE(),BYTE,PROC
Query                 PROCEDURE(STRING pSql),BYTE,PROC                ! usa los parametros agregados con AddParam (y los borra)
AddParam              PROCEDURE(STRING pValue)                       ! valor para el proximo '?' (va escapado y entre comillas)
AddNullParam          PROCEDURE()
ClearParams           PROCEDURE()
ParamCount            PROCEDURE(),LONG
NextResult            PROCEDURE(),BYTE,PROC                          ! siguiente resultado (CALL o varias sentencias); Notify = no hay mas
! sentencias preparadas (del lado del cliente: MySQL 5.0 no tiene arreglos de parametros)
Prepare               PROCEDURE(STRING pSql),BYTE,PROC               ! 'INSERT INTO t (a,b) VALUES (?,?)'
ExecPrepared          PROCEDURE(),BYTE,PROC                          ! con los AddParam actuales, o manda las filas pendientes de AddRow
AddRow                PROCEDURE(),BYTE,PROC                          ! una fila del lote: con INSERT ... VALUES arma un INSERT de varias filas
PendingRows           PROCEDURE(),LONG
! INSERT por nombre de campo, sin comillas ni escape: Campo(...) por cada columna y despues Insertar o InsertarLote
Campo                 PROCEDURE(STRING pNombre,STRING pValor)
CampoNulo             PROCEDURE(STRING pNombre)
CampoFecha            PROCEDURE(STRING pNombre,LONG pFecha)          ! fecha de Clarion; 0 = NULL
CampoFechaHora        PROCEDURE(STRING pNombre,LONG pFecha,LONG pHora)
Insertar              PROCEDURE(STRING pTabla),BYTE,PROC             ! una fila ya
InsertarLote          PROCEDURE(STRING pTabla),BYTE,PROC             ! junta las filas en un INSERT de varias filas (de a BatchSize)
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
SendQuery             PROCEDURE(STRING pSql),BYTE,PROTECTED          ! manda el SQL tal cual (sin reemplazar parametros)
Interpolate           PROCEDURE(STRING pSql),STRING,PROTECTED        ! reemplaza cada '?' (fuera de comillas) por el parametro escapado
ClearBatch            PROCEDURE(),PROTECTED
AppendBatch           PROCEDURE(STRING pText),PROTECTED
PrepareIfNew          PROCEDURE(STRING pSql),BYTE,PROTECTED
InsertSql             PROCEDURE(STRING pTabla),STRING,PROTECTED
SetError              PROCEDURE(STRING pText,LONG pErrno=0),BYTE,PROTECTED
TakeError             PROCEDURE(STRING pWhat),BYTE,PROC,PROTECTED
PtrToString           PROCEDURE(LONG pPtr),STRING,PROTECTED
                    END

 _EndOfInclude_
